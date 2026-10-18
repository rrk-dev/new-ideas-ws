#!/usr/bin/env python3
"""Auto-classification eval (TPL-04): accuracy and confusion matrix of `ProfileClassifier`.

Runs `app/tool/classify_eval.dart` (the app's keyword pre-filter + grammar-constrained LLM
call) over `tools/bench/eval/classify/cases.json`, scores the picks and writes a Markdown report
plus JSON to `tools/bench/results/`.

    # keyword stage only (no model, seconds): used while tuning classify.keywords on `dev`
    python3 tools/bench/eval/classify/run_classify.py --no-llm
    # full run, like the app (host llama.cpp build, CPU)
    nice -n 10 python3 tools/bench/eval/classify/run_classify.py --model <llama-3.2-1b-q4_k_m.gguf>
    # also write tools/bench/eval/baselines/classify.<model>.json
    ... --write-baseline

Exit code 1 when a target in scoring.json is missed and --gate is given.
"""
from __future__ import annotations

import argparse
import datetime
import json
import platform
import re
import shutil
import statistics
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
TARGETS = json.loads((HERE / "scoring.json").read_text())["targets"]


def dart_cmd() -> list[str]:
    return ["fvm", "dart"] if shutil.which("fvm") else ["dart"]


def run_tool(args, cases_path: Path, out: Path) -> tuple[float, int | None]:
    cmd = dart_cmd() + ["run", "tool/classify_eval.dart", "--cases", str(cases_path), "--out", str(out)]
    if args.no_llm or not args.model:
        cmd.append("--no-llm")
    else:
        cmd += ["--model", args.model, "--lib", args.lib, "--n-ctx", str(args.n_ctx)]
    timer = []
    if platform.system() == "Darwin" and Path("/usr/bin/time").exists():
        timer = ["/usr/bin/time", "-l"]
    t0 = time.monotonic()
    proc = subprocess.run(timer + cmd, cwd=ROOT / "app", capture_output=True, text=True)
    wall = time.monotonic() - t0
    if proc.returncode != 0:
        sys.stderr.write(proc.stderr[-4000:])
        raise SystemExit(f"classify_eval.dart failed ({proc.returncode})")
    m = re.search(r"(\d+)\s+maximum resident set size", proc.stderr)
    return wall, (int(m.group(1)) if m else None)


def score(cases: list[dict], results: dict[str, dict], profiles: list[str]):
    confusion = {e: {p: 0 for p in profiles + ["none"]} for e in profiles}
    rows = []
    for c in cases:
        r = results[c["id"]]
        picked = r["picked"] or "none"
        confusion[c["expected"]][picked] += 1
        rows.append({**c, **r, "picked": picked, "correct": picked == c["expected"]})

    def acc(sel):
        sel = list(sel)
        return sum(r["correct"] for r in sel) / len(sel) if sel else None

    recall, precision = {}, {}
    for p in profiles:
        n = sum(confusion[p].values())
        predicted = sum(confusion[e][p] for e in profiles)
        recall[p] = confusion[p][p] / n if n else None
        precision[p] = confusion[p][p] / predicted if predicted else None
    kw = [r for r in rows if r["method"] == "keyword"]
    wrong_confident = [r for r in rows if not r["correct"] and not r["needs_choice"]]
    latencies = [r["latency_ms"] for r in rows if r["method"] == "llm"]
    agg = {
        "cases": len(rows),
        "accuracy": acc(rows),
        "accuracy_dev": acc(r for r in rows if r["split"] == "dev"),
        "accuracy_holdout": acc(r for r in rows if r["split"] == "holdout"),
        "accuracy_clear": acc(r for r in rows if "clear" in r["tags"]),
        "accuracy_ambiguous": acc(r for r in rows if "ambiguous" in r["tags"]),
        "accuracy_injection": acc(r for r in rows if "injection" in r["tags"]),
        "recall_per_profile": recall,
        "precision_per_profile": precision,
        "confident_wrong_rate_max": len(wrong_confident) / len(rows),
        "keyword_decided": len(kw),
        "keyword_precision": acc(kw),
        "llm_decided": sum(r["method"] == "llm" for r in rows),
        "llm_accuracy": acc(r for r in rows if r["method"] == "llm"),
        "undecided": sum(r["method"] == "none" for r in rows),
        "ask_rate": sum(r["needs_choice"] for r in rows) / len(rows),
        "llm_latency_ms_median": statistics.median(latencies) if latencies else None,
        "llm_latency_ms_max": max(latencies) if latencies else None,
        "confusion": confusion,
    }
    return agg, rows


def pct(v) -> str:
    return "–" if v is None else f"{100 * v:.1f}%"


def check_targets(agg: dict):
    out = []
    for key, target in TARGETS.items():
        if key == "recall_per_profile":
            actual = min(v for v in agg[key].values() if v is not None)
            out.append((key, f"≥ {pct(target)} (min over profiles)", actual, actual >= target))
        elif key == "confident_wrong_rate_max":
            out.append((key, f"≤ {pct(target)}", agg[key], agg[key] <= target))
        else:
            actual = agg[key]
            out.append((key, f"≥ {pct(target)}", actual, actual is not None and actual >= target))
    return out


def render(agg: dict, env: dict, targets, profiles: list[str], wrong: list[dict]) -> str:
    med, mx = agg["llm_latency_ms_median"], agg["llm_latency_ms_max"]
    latency = "–" if med is None else f"{med / 1000:.1f} s / {mx / 1000:.1f} s"
    dirty = " + uncommitted changes" if env["dirty"] else ""
    rss = f" · peak RSS: {env['rss_mib']} MiB" if env.get("rss_mib") else ""
    L = [f"# Auto-classification eval — `{env['model']}`", "",
         f"- Date: {env['date']} · host: {env['host']} · backend: cpu · stage: {env['stage']}",
         f"- Commit: `{env['commit']}`{dirty} · cases: {agg['cases']} "
         "(simulated transcripts, `tools/bench/eval/classify/`)",
         f"- Wall time: {env['wall_s']:.0f} s incl. model load + Dart compile{rss}", "",
         "## Summary", "", "| Metric | Value |", "|---|---|",
         f"| Accuracy (all) | {pct(agg['accuracy'])} |",
         f"| Accuracy dev / holdout | {pct(agg['accuracy_dev'])} / {pct(agg['accuracy_holdout'])} |",
         f"| Accuracy clear / ambiguous / injection | {pct(agg['accuracy_clear'])} / {pct(agg['accuracy_ambiguous'])}"
         f" / {pct(agg['accuracy_injection'])} |",
         f"| Keyword stage decided / precision | {agg['keyword_decided']} / {pct(agg['keyword_precision'])} |",
         f"| LLM stage decided / accuracy | {agg['llm_decided']} / {pct(agg['llm_accuracy'])} |",
         f"| Not decided (keyword-only run) | {agg['undecided']} |",
         f"| User asked (low confidence) | {pct(agg['ask_rate'])} |",
         f"| Wrong and not asked | {pct(agg['confident_wrong_rate_max'])} |",
         f"| LLM-stage latency median / max (host CPU) | {latency} |",
         "", "## Confusion matrix (rows = label, columns = picked)", ""]
    cols = profiles + ["none"]
    L += ["| label \\ picked | " + " | ".join(cols) + " | recall |", "|---|" + "---|" * (len(cols) + 1)]
    for e in profiles:
        row = agg["confusion"][e]
        L.append(f"| **{e}** | " + " | ".join(str(row[c]) for c in cols) + f" | {pct(agg['recall_per_profile'][e])} |")
    L.append("| precision | " + " | ".join(pct(agg["precision_per_profile"].get(c)) for c in profiles) + " | | |")
    L += ["", "## Targets", "", "| Target | Required | Actual | |", "|---|---|---|---|"]
    for key, req, actual, ok in targets:
        L.append(f"| {key} | {req} | {pct(actual)} | {'✅' if ok else '❌'} |")
    L += ["", f"## Misclassified cases ({len(wrong)})", "", "| Case | Label | Picked | Method | Confidence | Tags |",
          "|---|---|---|---|---|---|"]
    for r in wrong:
        L.append(f"| {r['id']} | {r['expected']} | {r['picked']} | {r['method']} | {r['confidence']:.2f} | "
                 f"{', '.join(r['tags'])} / {r['split']} |")
    return "\n".join(L) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--model", help="llama.cpp .gguf (default: keyword stage only)")
    ap.add_argument("--no-llm", action="store_true", help="keyword stage only")
    ap.add_argument("--lib", default=str(ROOT / "native/build/host" /
                                         ("libvv_native.dylib" if platform.system() == "Darwin" else "libvv_native.so")))
    ap.add_argument("--n-ctx", type=int, default=4096)
    ap.add_argument("--write-baseline", action="store_true")
    ap.add_argument("--gate", action="store_true")
    ap.add_argument("--out-dir", default=str(ROOT / "tools/bench/results"))
    args = ap.parse_args()

    spec = json.loads((HERE / "cases.json").read_text())
    cases, profiles = spec["cases"], spec["profiles"]
    llm = bool(args.model) and not args.no_llm
    out = HERE / ".results.jsonl"
    try:
        wall, rss = run_tool(args, HERE / "cases.json", out)
        results = {r["id"]: r for r in map(json.loads, (ln for ln in out.read_text().splitlines() if ln.strip()))}
    finally:
        out.unlink(missing_ok=True)
    agg, rows = score(cases, results, profiles)
    git = lambda *a: subprocess.run(["git", "-C", str(ROOT), *a], capture_output=True, text=True).stdout.strip()  # noqa: E731
    model = Path(args.model).stem.replace(".", "-").replace("_", "-") if llm else "keywords-only"
    env = {"model": Path(args.model).name if llm else "keyword stage only", "date": datetime.date.today().isoformat(),
           "host": f"{platform.system()} {platform.machine()}", "stage": "keywords + LLM" if llm else "keywords only",
           "commit": git("rev-parse", "--short", "HEAD"), "dirty": bool(git("status", "--porcelain", "--", "app", "tools")),
           "wall_s": wall, "rss_mib": rss // (1 << 20) if rss else None}
    targets = check_targets(agg)
    wrong = [r for r in rows if not r["correct"]]
    report = render(agg, env, targets, profiles, wrong)
    stem = f"{env['date']}-eval-classify-{model}"
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / f"{stem}.md").write_text(report)
    payload = {"env": env, "aggregate": agg,
               "cases": [{k: r[k] for k in ("id", "expected", "picked", "method", "confidence", "needs_choice", "split", "tags")}
                         for r in rows]}
    (out_dir / f"{stem}.json").write_text(json.dumps(payload, indent=1) + "\n")
    if args.write_baseline and llm:
        base = ROOT / "tools/bench/eval/baselines" / f"classify.{model}.json"
        base.write_text(json.dumps({"env": env, "aggregate": agg}, indent=1) + "\n")
        print(f"classify: baseline {base.relative_to(ROOT)}")
    print(report)
    print(f"classify: report {(out_dir / (stem + '.md')).relative_to(ROOT)}")
    missed = [t for t in targets if not t[3]]
    return 1 if (args.gate and missed) else 0


if __name__ == "__main__":
    sys.exit(main())
