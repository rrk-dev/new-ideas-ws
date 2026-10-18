#!/usr/bin/env python3
"""Mind-map eval (MAP-01): compares options A (projection), B (LLM) and C (hybrid) of ADR-MAP-01.

Runs `app/tool/mindmap_eval_test.dart` (production extraction + `MindMapGenerator`, host llama.cpp,
CPU) over `tools/bench/eval/mindmap/cases.json` (synthetic transcripts), scores the trees and
writes a Markdown report + JSON to `tools/bench/results/`.

    nice -n 10 python3 tools/bench/eval/mindmap/run_mindmap.py --model <llama-3.2-1b-q4_k_m.gguf>
    ... --write-baseline   # also tools/bench/eval/baselines/mindmap.<model>.json
    ... --gate             # exit 1 when a target in scoring.json is missed by the chosen option

Option choice (fixed in the task file before the first run): highest concept_recall among options
meeting schema_valid and label_grounding; ties go to the cheaper option (A < C < B).
"""
from __future__ import annotations

import argparse
import datetime
import json
import os
import platform
import shutil
import statistics
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0, str(HERE.parent))
import scoring as sc  # noqa: E402

CFG = json.loads((HERE / "scoring.json").read_text())
TARGETS, LIMITS = CFG["targets"], CFG["limits"]
METHODS = ["projection", "llm", "hybrid"]
COST_ORDER = {"projection": 0, "hybrid": 1, "llm": 2}


def run_tool(args, out: Path) -> float:
    fvm = ["fvm"] if shutil.which("fvm") else []
    env = {**os.environ, "VV_MINDMAP_CASES": str(HERE / "cases.json"), "VV_MINDMAP_OUT": str(out),
           "VV_MINDMAP_MODEL": args.model, "VV_NATIVE_LIB": args.lib}
    if args.limit:
        env["VV_MINDMAP_LIMIT"] = str(args.limit)
    t0 = time.monotonic()
    proc = subprocess.run(fvm + ["flutter", "test", "tool/mindmap_eval_test.dart"], cwd=ROOT / "app",
                          env=env, capture_output=True, text=True)
    if proc.returncode != 0:
        sys.stderr.write((proc.stdout + proc.stderr)[-4000:])
        raise SystemExit(f"mindmap_eval_test.dart failed ({proc.returncode})")
    return time.monotonic() - t0


def walk(node, depth=1):
    yield node, depth
    for c in node.get("children", []):
        yield from walk(c, depth + 1)


def limits_ok(tree) -> bool:
    ids, count = set(), 0
    for node, depth in walk(tree):
        count += 1
        label = node.get("label")
        if depth > LIMITS["max_depth"] or not isinstance(label, str) or not label.strip():
            return False
        if len(label) > LIMITS["max_label"] or node.get("id") in ids:
            return False
        ids.add(node.get("id"))
    return count <= LIMITS["max_nodes"]


def score(cases, records):
    out = {}
    for m in METHODS:
        valid = rawn = groundn = 0
        concepts = matched = trees = compliant = rejected = nodes = 0
        a_labels = a_grounded = 0
        times, ours = [], []
        for c in cases:
            r = records[c["id"]]
            x = r[m]
            valid += bool(x["schema_valid"])
            rawn += x["raw_labels"]
            groundn += x["grounded_labels"]
            times.append(x["ms"] if m != "llm" else x["ms"])
            tree = x["tree"]
            concepts += len(c["concepts"])
            if tree is None:
                rejected += 1
                continue
            trees += 1
            compliant += limits_ok(tree)
            labels = [n["label"] for n, d in walk(tree) if d > 1]
            nodes += len(labels)
            matched += len({i for i, _ in sc.match_lists(c["concepts"], labels, None, "text")})
            if m == "projection":
                tt = set(sc.tokens(c["transcript"]))
                a_labels += len(labels)
                a_grounded += sum(sc.grounded(label, tt) for label in labels)
        if m == "projection":
            rawn, groundn = a_labels, a_grounded
        n = len(cases)
        out[m] = {
            "schema_valid": valid / n,
            "label_grounding": groundn / rawn if rawn else None,
            "concept_recall": matched / concepts if concepts else None,
            "limits_compliance": compliant / trees if trees else None,
            "rejected_rate": rejected / n,
            "avg_nodes": nodes / trees if trees else None,
            "ms_median": statistics.median(times),
            "ms_max": max(times),
        }
    return out


def meets(s, key) -> bool:
    v = s[key]
    return v is not None and v >= TARGETS[key]


def choose(agg):
    ok = [m for m in METHODS if meets(agg[m], "schema_valid") and meets(agg[m], "label_grounding")]
    if not ok:
        return None
    return max(ok, key=lambda m: ((agg[m]["concept_recall"] or 0), -COST_ORDER[m]))


def pct(v):
    return "–" if v is None else f"{100 * v:.1f}%"


def render(agg, env, pick, extraction):
    L = [f"# Mind-map eval — `{env['model']}`", "",
         f"- Date: {env['date']} · host: {env['host']} · backend: cpu · commit: `{env['commit']}`"
         f"{' + uncommitted changes' if env['dirty'] else ''}",
         f"- Cases: {env['cases']} (simulated transcripts, `tools/bench/eval/mindmap/`); wall time "
         f"{env['wall_s']:.0f} s incl. model load",
         f"- Extraction (shared by A and C): valid {pct(extraction['valid'])}, median "
         f"{extraction['ms_median'] / 1000:.1f} s per case",
         f"- Limits: depth ≤ {LIMITS['max_depth']}, nodes ≤ {LIMITS['max_nodes']}, label ≤ {LIMITS['max_label']}", "",
         "## Options", "",
         "| Option | schema_valid | label_grounding | concept_recall | limits_compliance | rejected | "
         "avg nodes | latency median / max |", "|---|---|---|---|---|---|---|---|"]
    for m in METHODS:
        s = agg[m]
        nodes = "–" if s["avg_nodes"] is None else f"{s['avg_nodes']:.1f}"
        L.append(f"| {m} | {pct(s['schema_valid'])} | {pct(s['label_grounding'])} | {pct(s['concept_recall'])} | "
                 f"{pct(s['limits_compliance'])} | {pct(s['rejected_rate'])} | {nodes} | "
                 f"{s['ms_median'] / 1000:.2f} s / {s['ms_max'] / 1000:.2f} s |")
    L += ["", "Latency is the generation step only (the extraction it reuses is reported above); "
          "`llm` and `hybrid` share one LLM call, whose wall time is "
          f"{extraction['llm_ms_median'] / 1000:.1f} s median.", "",
          f"## Chosen option: `{pick or 'none meets validity and grounding'}`", "",
          "## Targets (chosen option)", "", "| Target | Required | Actual | |", "|---|---|---|---|"]
    if pick:
        for k, t in TARGETS.items():
            v = agg[pick][k]
            L.append(f"| {k} | ≥ {pct(t)} | {pct(v)} | {'✅' if v is not None and v >= t else '❌'} |")
    return "\n".join(L) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--model", required=True)
    ap.add_argument("--lib", default=str(ROOT / "native/build/host" /
                                         ("libvv_native.dylib" if platform.system() == "Darwin" else "libvv_native.so")))
    ap.add_argument("--limit", type=int)
    ap.add_argument("--write-baseline", action="store_true")
    ap.add_argument("--gate", action="store_true")
    ap.add_argument("--out-dir", default=str(ROOT / "tools/bench/results"))
    args = ap.parse_args()

    cases = json.loads((HERE / "cases.json").read_text())["cases"]
    if args.limit:
        cases = cases[: args.limit]
    out = HERE / ".results.jsonl"
    try:
        wall = run_tool(args, out)
        records = {r["id"]: r for r in map(json.loads, (ln for ln in out.read_text().splitlines() if ln.strip()))}
    finally:
        out.unlink(missing_ok=True)
    agg = score(cases, records)
    pick = choose(agg)
    recs = [records[c["id"]] for c in cases]
    extraction = {"valid": sum(r["extraction_valid"] for r in recs) / len(recs),
                  "ms_median": statistics.median(r["extraction_ms"] for r in recs),
                  "llm_ms_median": statistics.median(r["llm_ms"] for r in recs)}
    git = lambda *a: subprocess.run(["git", "-C", str(ROOT), *a], capture_output=True, text=True).stdout.strip()  # noqa: E731
    model = Path(args.model).stem.replace(".", "-").replace("_", "-")
    env = {"model": Path(args.model).name, "date": datetime.date.today().isoformat(),
           "host": f"{platform.system()} {platform.machine()}", "commit": git("rev-parse", "--short", "HEAD"),
           "dirty": bool(git("status", "--porcelain", "--", "app", "tools")), "wall_s": wall, "cases": len(cases)}
    report = render(agg, env, pick, extraction)
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    stem = f"{env['date']}-eval-mindmap-{model}"
    (out_dir / f"{stem}.md").write_text(report)
    payload = {"env": env, "targets": TARGETS, "limits": LIMITS, "chosen": pick, "extraction": extraction,
               "options": agg}
    (out_dir / f"{stem}.json").write_text(json.dumps(payload, indent=1) + "\n")
    if args.write_baseline:
        base = ROOT / "tools/bench/eval/baselines" / f"mindmap.{model}.json"
        base.write_text(json.dumps(payload, indent=1) + "\n")
        print(f"mindmap: baseline {base.relative_to(ROOT)}")
    print(report)
    missed = pick is None or any(not meets(agg[pick], k) for k in TARGETS)
    return 1 if (args.gate and missed) else 0


if __name__ == "__main__":
    sys.exit(main())
