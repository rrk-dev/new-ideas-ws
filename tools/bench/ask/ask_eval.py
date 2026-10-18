#!/usr/bin/env python3
"""End-to-end eval for ASK-03: scores the Ask engine's answers against ground truth.

Re-runnable, stdlib only, local only. Targets were pre-registered in
tasks/14-product-phase2/ASK-03-ask-engine.md before the first run.

  # run the engine over the 44 questions with the real 3B (host build), then score:
  python3 tools/bench/ask/ask_eval.py run --model <3b.gguf> [--lib <libvv_native>] \
      [--arms base,rewrite,verify] --out tools/bench/results/2026-10-17-ask03-eval

  # score existing raw results only:
  python3 tools/bench/ask/ask_eval.py score --raw base=a.jsonl [rewrite=b.jsonl] --out <prefix>

`run` starts `flutter test test/eval/ask_eval_host_test.dart` once per arm (one job at a time,
under `nice`), which drives the app's AskService (FTS5 retrieval, grounded prompt, grammar
constrained answer, citation validation). Everything is synthetic; nothing leaves the machine.
"""
from __future__ import annotations

import argparse
import json
import os
import statistics
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
APP = ROOT / "app"

TARGETS = {
    "answer_correctness": (0.70, "target"),
    "citation_precision": (0.90, "gate"),
    "unanswerable_refused": (0.90, "gate"),
    "hallucination_rate": (0.15, "target"),
    "seg_recall@10": (0.80, "gate"),
}
LOWER_IS_BETTER = {"hallucination_rate"}


def load_questions() -> tuple[dict, dict]:
    questions, expect = {}, {}
    for q_file, a_file in (("questions.json", "answers.json"), ("questions_ask05.json", "answers_ask05.json")):
        if (HERE / q_file).exists():
            questions.update({q["id"]: q for q in json.loads((HERE / q_file).read_text())["questions"]})
            expect.update(json.loads((HERE / a_file).read_text())["expect"])
    return questions, expect


def load(path: Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]


def keywords_met(answer: str, groups: list[list[str]]) -> bool:
    low = answer.lower()
    return all(any(alt.lower() in low for alt in g) for g in groups)


def score_arm(rows: list[dict], questions: dict, expect: dict) -> dict:
    ans = [r for r in rows if questions[r["id"]]["gold"]]
    un = [r for r in rows if not questions[r["id"]]["gold"]]
    per = []
    n_cit = n_cit_ok = 0
    for r in ans:
        q = questions[r["id"]]
        gold_recs = {g["rec"] for g in q["gold"]}
        seen = {(p["rec"], p["t"]) for p in r.get("passages", []) if p["kind"] == "transcript"}
        recall = sum(any((g["rec"], t) in seen for t in g["t"]) for g in q["gold"]) / len(q["gold"])
        answered = r.get("outcome") == "answered"
        correct = answered and keywords_met(r["answer"], expect[r["id"]])
        cits = r.get("citations", [])
        n_cit += len(cits)
        n_cit_ok += sum(c["rec"] in gold_recs for c in cits)
        per.append({
            "id": r["id"], "type": q["type"], "outcome": r.get("outcome"), "recall": recall,
            "correct": correct, "hallucinated": answered and bool(cits) and not correct,
            "citations": len(cits), "citations_ok": sum(c["rec"] in gold_recs for c in cits),
            "ms": r["ms"],
        })
    refused = [r for r in un if r.get("outcome") == "notFound"]
    lat = sorted(r["ms"] for r in rows)
    by_type = {}
    for t in ("exact", "paraphrase", "multi", "date"):
        sub = [p for p in per if p["type"] == t]
        by_type[t] = {
            "n": len(sub),
            "answer_correctness": mean([p["correct"] for p in sub]),
            "seg_recall@10": mean([p["recall"] for p in sub]),
        }
    m = {
        "answer_correctness": mean([p["correct"] for p in per]),
        "citation_precision": (n_cit_ok / n_cit) if n_cit else float("nan"),
        "unanswerable_refused": len(refused) / len(un) if un else float("nan"),
        "hallucination_rate": mean([p["hallucinated"] for p in per]),
        "seg_recall@10": mean([p["recall"] for p in per]),
    }
    return {
        "n_answerable": len(ans), "n_unanswerable": len(un), "metrics": m, "by_type": by_type,
        "citations_returned": n_cit, "citations_on_gold_recording": n_cit_ok,
        "outcomes": {o: sum(r.get("outcome") == o for r in rows)
                     for o in sorted({r.get("outcome") for r in rows}, key=str)},
        "not_answered_answerable": [p["id"] for p in per if p["outcome"] != "answered"],
        "wrongly_answered_unanswerable": [r["id"] for r in un if r.get("outcome") != "notFound"],
        "latency_ms": {"median": statistics.median(lat), "p95": lat[min(len(lat) - 1, int(0.95 * len(lat)))],
                       "max": lat[-1]},
        "per_question": per,
    }


def mean(xs):
    xs = list(xs)
    return sum(1.0 if x is True else 0.0 if x is False else x for x in xs) / len(xs) if xs else float("nan")


def pct(x):
    return "n/a" if x != x else f"{100 * x:.1f}%"


def verdict(name, value):
    target, kind = TARGETS[name]
    ok = value <= target if name in LOWER_IS_BETTER else value >= target
    return ("MET" if ok else "MISSED"), kind, target


def render(res: dict) -> str:
    arms = res["arms"]
    first = next(iter(arms.values()))
    out = [
        "# ASK-03 end-to-end Ask eval (3B, host)", "",
        f"Model `{res['model_note']}`, n_ctx {res['n_ctx']}, greedy, grammar-constrained, host "
        f"(Apple Silicon, `libvv_native` host build). {first['n_answerable'] + first['n_unanswerable']} questions "
        f"({first['n_answerable']} answerable, {first['n_unanswerable']} unanswerable) "
        "over the 33-recording synthetic library of ASK-02. Targets pre-registered in "
        "`tasks/14-product-phase2/ASK-03-ask-engine.md` (ASK-03) and "
        "`tasks/14-product-phase2/ASK-05-ask-answer-quality.md` (ASK-05) before the first run.", "",
        "Segment recall@10 here is measured on the passages given to the model: the 10 FTS5 "
        "candidates, the top three expanded by their ±1 neighbour segments, trimmed to the prompt "
        "budget; a gold item counts when one of its accepted timestamps is among them.", "",
    ]
    for name, a in arms.items():
        out += [f"## Arm `{name}`", "", "| Metric | Measured | Target | Kind | Verdict |", "|---|---|---|---|---|"]
        for k, v in a["metrics"].items():
            verdict_, kind, target = verdict(k, v)
            sign = "≤" if k in LOWER_IS_BETTER else "≥"
            out.append(f"| {k} | {pct(v)} | {sign} {pct(target)} | {kind} | {verdict_} |")
        lat = a["latency_ms"]
        out += ["", f"Outcomes: {a['outcomes']}. Citations returned {a['citations_returned']}, "
                f"on a gold recording {a['citations_on_gold_recording']}. Latency per question "
                f"(retrieval + generation, model already loaded after the first): median "
                f"{lat['median'] / 1000:.1f} s, p95 {lat['p95'] / 1000:.1f} s, max {lat['max'] / 1000:.1f} s.",
                "", "| Type | n | Answer correctness | Segment recall@10 |", "|---|---|---|---|"]
        for t, b in a["by_type"].items():
            out.append(f"| {t} | {b['n']} | {pct(b['answer_correctness'])} | {pct(b['seg_recall@10'])} |")
        out += ["", f"Answerable questions not answered: {', '.join(a['not_answered_answerable']) or 'none'}.",
                f"Unanswerable questions answered anyway: "
                f"{', '.join(a['wrongly_answered_unanswerable']) or 'none'}.", ""]
    if "rewrite" in arms and "base" in arms:
        b, r = arms["base"]["metrics"], arms["rewrite"]["metrics"]
        lifts = r["seg_recall@10"] > b["seg_recall@10"]
        gates_ok = (r["citation_precision"] >= b["citation_precision"]
                    and r["unanswerable_refused"] >= b["unanswerable_refused"])
        out += ["## Query rewrite decision (pre-registered rule)", "",
                "Adopt the LLM query rewrite only if it raises segment recall@10 without lowering "
                "the citation-precision or refusal gates.", "",
                f"recall@10 {pct(b['seg_recall@10'])} → {pct(r['seg_recall@10'])}; citation precision "
                f"{pct(b['citation_precision'])} → {pct(r['citation_precision'])}; refusal "
                f"{pct(b['unanswerable_refused'])} → {pct(r['unanswerable_refused'])}. "
                f"**{'ADOPT' if lifts and gates_ok else 'DO NOT ADOPT'}**", ""]
    out += ["Re-run: `python3 tools/bench/ask/ask_eval.py run --model <3b.gguf> --out <prefix>`."]
    return "\n".join(out) + "\n"


def run_arm(arm: str, model: Path, lib: str | None, raw: Path, n_ctx: int) -> None:
    env = dict(os.environ, ASK_EVAL_MODEL=str(model), ASK_EVAL_OUT=str(raw), ASK_EVAL_NCTX=str(n_ctx),
               ASK_EVAL_REWRITE="1" if arm == "rewrite" else "0",
               ASK_EVAL_VERIFY="1" if arm == "verify" else "0")
    if lib:
        env["ASK_EVAL_LIB"] = lib
    cmd = ["nice", "-n", "10", "fvm", "flutter", "test", "test/eval/ask_eval_host_test.dart"]
    print(f"[ask_eval] arm {arm}: {' '.join(cmd)}", file=sys.stderr)
    subprocess.run(cmd, cwd=APP, env=env, check=True, stdout=subprocess.DEVNULL)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("run")
    r.add_argument("--model", required=True, type=Path)
    r.add_argument("--lib")
    r.add_argument("--arms", default="base")
    r.add_argument("--n-ctx", type=int, default=6144)
    r.add_argument("--out", required=True)
    s = sub.add_parser("score")
    s.add_argument("--raw", nargs="+", required=True, help="arm=path.jsonl")
    s.add_argument("--n-ctx", type=int, default=6144)
    s.add_argument("--out", required=True)
    args = ap.parse_args()

    raws: dict[str, Path] = {}
    if args.cmd == "run":
        for arm in args.arms.split(","):
            raw = Path(f"{args.out}.{arm}.raw.jsonl").resolve()
            run_arm(arm, args.model, args.lib, raw, args.n_ctx)
            raws[arm] = raw
        model_note = args.model.name
    else:
        raws = {kv.split("=", 1)[0]: Path(kv.split("=", 1)[1]) for kv in args.raw}
        model_note = "Llama-3.2-3B-Instruct-Q4_K_M.gguf"

    questions, expect = load_questions()
    arms = {name: score_arm(load(p), questions, expect) for name, p in raws.items()}
    res = {"model_note": model_note, "n_ctx": args.n_ctx, "arms": arms}
    out = Path(args.out)
    out.with_suffix(".json").write_text(json.dumps(res, indent=1) + "\n")
    out.with_suffix(".md").write_text(render(res))
    print(render(res))


if __name__ == "__main__":
    main()
