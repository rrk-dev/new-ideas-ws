#!/usr/bin/env python3
"""Extraction quality eval runner (PRF-09).

Renders every case of a profile with the app's prompt builder and runs it
through the host llama.cpp build in one process (`app/tool/render_prompt.dart
--generate`: same PromptBuilder, GGUF chat template, exact token budget, GBNF
from the profile schema, extraction sampling preset, Dart schema validator),
then scores the outputs (scoring.py) and writes a report.

  tools/bench/eval/run.py --profile meeting --model <model.gguf>
      [--lib native/build/host/libvv_native.dylib] [--n-ctx 4096] [--max-tokens 1024]
      [--gpu] [--limit N] [--case ID ...] [--baseline FILE | --no-baseline]
      [--write-baseline] [--gate] [--out-dir tools/bench/results]

Output: tools/bench/results/<date>-eval-<profile>-<model>.{md,json}; with a
baseline (default tools/bench/eval/baselines/<profile>.<model>.json) the
report shows the diff and --gate exits 1 on a regression (F1/accuracy drop
> 2 points, schema validity < 99 % or below the baseline).
On-device numbers: run the same cases through the app's integration test
(follow-up); this runner is the fast desktop loop.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import platform
import re
import shutil
import statistics
import subprocess
import sys
import tempfile
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import scoring  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
EVAL = Path(__file__).resolve().parent


def load_cases(profile: str, only: list[str] | None, limit: int | None) -> list[dict]:
    cases = []
    for d in sorted((EVAL / profile).iterdir()):
        if not (d / "expected.json").exists():
            continue
        if only and d.name not in only:
            continue
        transcript = d / "transcript.txt"
        if not transcript.exists():
            raise SystemExit(f"{d}: transcript.txt missing — run tools/bench/eval/synth.py")
        meta = json.loads((d / "meta.json").read_text())
        cases.append({
            "id": d.name,
            "dir": d,
            "meta": meta,
            "transcript": transcript.read_text(encoding="utf-8"),
            "expected": json.loads((d / "expected.json").read_text()),
        })
    return cases[:limit] if limit else cases


def case_json(c: dict) -> dict:
    meta = c["meta"]
    speakers = []
    if meta.get("diarization", True):
        # transcript.txt carries display names as speaker labels.
        speakers = [{"label": s["name"], "name": s["name"]} for s in meta.get("speakers", [])]
    return {
        "id": c["id"],
        "metadata": {"date": meta["date"], "duration_s": meta.get("duration_s"),
                     "speakers": speakers, "markers": meta.get("markers", [])},
        "transcript": c["transcript"],
    }


def dart_cmd() -> list[str]:
    if os.environ.get("VV_DART"):
        return os.environ["VV_DART"].split()
    return ["fvm", "dart"] if shutil.which("fvm") else ["dart"]


def default_lib() -> str:
    ext = "dylib" if platform.system() == "Darwin" else "so"
    return str(ROOT / f"native/build/host/libvv_native.{ext}")


def sha256(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def run_model(cases: list[dict], args) -> tuple[list[dict], float, int | None]:
    with tempfile.TemporaryDirectory() as tmp:
        cin, cout = Path(tmp) / "cases.jsonl", Path(tmp) / "out.jsonl"
        cin.write_text("".join(json.dumps(case_json(c)) + "\n" for c in cases))
        cmd = dart_cmd() + ["run", "tool/render_prompt.dart", "--profile", args.profile,
                            "--cases", str(cin), "--out", str(cout), "--generate",
                            "--model", args.model, "--lib", args.lib,
                            "--n-ctx", str(args.n_ctx), "--max-tokens", str(args.max_tokens)]
        if args.gpu:
            cmd.append("--gpu")
        if args.threads:
            cmd += ["--threads", str(args.threads)]
        timer = []
        if platform.system() == "Darwin" and Path("/usr/bin/time").exists():
            timer = ["/usr/bin/time", "-l"]
        elif Path("/usr/bin/time").exists():
            timer = ["/usr/bin/time", "-v"]
        t0 = time.monotonic()
        proc = subprocess.run(timer + cmd, cwd=ROOT / "app", capture_output=True, text=True)
        wall = time.monotonic() - t0
        if proc.returncode != 0:
            sys.stderr.write(proc.stderr[-4000:])
            raise SystemExit(f"render_prompt.dart failed ({proc.returncode})")
        rss = None
        m = re.search(r"(\d+)\s+maximum resident set size", proc.stderr)  # macOS: bytes
        if m:
            rss = int(m.group(1))
        m = re.search(r"Maximum resident set size \(kbytes\): (\d+)", proc.stderr)  # GNU: KiB
        if m:
            rss = int(m.group(1)) * 1024
        records = [json.loads(line) for line in cout.read_text().splitlines() if line.strip()]
    return records, wall, rss


def pct(v) -> str:
    return "–" if v is None else f"{100 * v:.1f}%"


def render_report(profile, model, agg, perf, env, cases, diff, problems, targets) -> str:
    rss_text = "–" if perf["peak_rss"] is None else f"{perf['peak_rss'] / 2**20:.0f} MiB"
    lines = [f"# Extraction eval — `{profile}` × `{Path(model).name}`", "",
             f"- Date: {env['date']} · host: {env['host']} · backend: {env['backend']}",
             f"- Model sha256: `{env['model_sha256'][:16]}` · n_ctx {env['n_ctx']} · max_tokens "
             f"{env['max_tokens']} · sampling: extraction preset (grammar, temp 0.2, seed 42)",
             f"- Commit: `{env['commit']}` · llama.cpp `{env['llama']}` · profile version {env['profile_version']}",
             f"- Cases: {agg['cases']} (synthetic TTS → whisper transcripts, `tools/bench/eval/{profile}/`)",
             f"- Wall time: {perf['wall_s']:.0f} s incl. model load + Dart compile · peak RSS: "
             f"{rss_text}",
             "", "## Summary", "",
             "| Metric | Value |", "|---|---|",
             f"| Schema-valid (first pass, grammar-constrained) | {pct(agg['schema_valid'])} |",
             "| Repair used | n/a (harness scores the first pass) |",
             f"| Hallucination rate (ungrounded items) | {pct(agg['hallucination_rate'])} |",
             f"| Prefill tok/s (median) | {perf['prefill_tps']:.0f} |",
             f"| Decode tok/s (median) | {perf['decode_tps']:.1f} |",
             f"| Latency per case (median / max) | {perf['latency_med_s']:.1f} s / {perf['latency_max_s']:.1f} s |",
             f"| Prompt tokens (median / max) | {perf['prompt_tokens_med']} / {perf['prompt_tokens_max']} |"]
    if agg["lists"]:
        lines += ["", "## List fields (micro-averaged, fuzzy one-to-one)", "",
                  "| Field | Precision | Recall | F1 | Expected | Predicted | Sub-fields |", "|---|---|---|---|---|---|---|"]
        for f, v in agg["lists"].items():
            subs = ", ".join(f"{k[:-9]} {pct(x)}" for k, x in v.items() if k.endswith("_accuracy"))
            lines.append(f"| {f} | {pct(v['precision'])} | {pct(v['recall'])} | {pct(v['f1'])} | "
                         f"{v['expected']} | {v['predicted']} | {subs or '–'} |")
    scal = {k: v for k, v in agg["scalars"].items() if isinstance(v, dict)}
    if scal:
        lines += ["", "## Scalar fields", "", "| Field | Exact | Fuzzy |", "|---|---|---|"]
        for f, v in scal.items():
            lines.append(f"| {f} | {pct(v['exact'])} | {pct(v['fuzzy'])} |")
        lines.append(f"| **all (field accuracy)** | {pct(agg['scalars']['exact_accuracy'])} | "
                     f"{pct(agg['scalars']['accuracy'])} |")
    if agg["prose"]:
        lines += ["", "Prose fields (token-set similarity to the reference, informational): " +
                  ", ".join(f"{k} {pct(v)}" for k, v in agg["prose"].items())]
    lines += ["", "## Targets", "", "| Target | Required | Actual | |", "|---|---|---|---|"]
    for k, req in targets.items():
        v = scoring.lookup(agg, k)
        ok = v is not None and v + 1e-9 >= req
        lines.append(f"| {k} | ≥ {pct(req)} | {pct(v)} | {'✅' if ok else '❌'} |")
    if diff:
        lines += ["", "## Diff vs baseline", "", "| Metric | Baseline | Now | Δ |", "|---|---|---|---|"]
        for k, (b, n) in diff.items():
            lines.append(f"| {k} | {pct(b)} | {pct(n)} | {100 * (n - b):+.1f} pt |")
        lines += ["", "Gate: " + ("**FAIL** — " + "; ".join(problems) if problems else "pass")]
    lines += ["", "## Per case", "", "| Case | Valid | Prompt tok | Latency s | Notes |", "|---|---|---|---|---|"]
    for c in cases:
        notes = ", ".join(f"{f} {s['tp']}/{s['expected']}/{s['predicted']}" for f, s in c["score"]["lists"].items()
                          if s["tp"] != s["expected"] or s["tp"] != s["predicted"])
        lines.append(f"| {c['id']} | {'✅' if c['valid'] else '❌'} | {c.get('prompt_tokens', '–')} | "
                     f"{c.get('latency_ms', 0) / 1000:.1f} | {notes or 'all lists exact'} |")
    lines += ["", "List notes are `tp/expected/predicted`. Regenerate: `make eval PROFILE=" + profile +
              " MODEL=" + Path(model).name + "`.", ""]
    return "\n".join(lines)


def main() -> int:
    p = argparse.ArgumentParser(description="PRF-09 extraction eval")
    p.add_argument("--profile", required=True)
    p.add_argument("--model", required=True)
    p.add_argument("--lib", default=os.environ.get("VV_NATIVE_LIB", default_lib()))
    p.add_argument("--n-ctx", type=int, default=4096)
    p.add_argument("--max-tokens", type=int, default=1024)
    p.add_argument("--threads", type=int, default=0)
    p.add_argument("--gpu", action="store_true")
    p.add_argument("--limit", type=int)
    p.add_argument("--case", action="append")
    p.add_argument("--baseline")
    p.add_argument("--no-baseline", action="store_true")
    p.add_argument("--write-baseline", action="store_true")
    p.add_argument("--gate", action="store_true")
    p.add_argument("--out-dir", default=str(ROOT / "tools/bench/results"))
    p.add_argument("--from-results", help="score an existing results JSONL instead of running the model")
    args = p.parse_args()

    cfg = json.loads((EVAL / args.profile / "scoring.json").read_text())
    needed = [(args.model, "model")]
    if not args.from_results:
        needed.append((args.lib, "host library (native/build.sh host)"))
    for f, what in needed:
        if not Path(f).exists():
            print(f"eval: missing {what}: {f}", file=sys.stderr)
            return 2
    cases = load_cases(args.profile, args.case, args.limit)
    if args.from_results:
        # Score outputs produced elsewhere (e.g. an on-device run) in the
        # render_prompt.dart --generate JSONL format.
        records = [json.loads(line) for line in Path(args.from_results).read_text().splitlines() if line.strip()]
        wall, rss = sum((r.get("latency_ms") or 0) for r in records) / 1000, None
        known = {r["id"] for r in records}
        cases = [c for c in cases if c["id"] in known]
    else:
        records, wall, rss = run_model(cases, args)
    by_id = {r["id"]: r for r in records}
    for c in cases:
        r = by_id[c["id"]]
        c.update({k: r.get(k) for k in ("valid", "prompt_tokens", "latency_ms", "n_prompt", "n_gen",
                                        "prefill_ms", "decode_ms", "plan", "issues")})
        c["valid"] = bool(r.get("valid"))
        try:
            pred = json.loads(r.get("output") or "")
        except ValueError:
            pred = None
        c["output"] = pred
        c["score"] = scoring.score_case(c["expected"], pred if c["valid"] else None, c["transcript"], cfg)
    agg = scoring.aggregate(cases, cfg)

    def med(xs):
        xs = [x for x in xs if x is not None]
        return statistics.median(xs) if xs else 0

    gen = [c for c in cases if c.get("n_gen")]
    perf = {
        "wall_s": wall, "peak_rss": rss,
        "prefill_tps": med([c["n_prompt"] * 1000 / c["prefill_ms"] for c in gen if c["prefill_ms"]]),
        "decode_tps": med([c["n_gen"] * 1000 / c["decode_ms"] for c in gen if c["decode_ms"]]),
        "latency_med_s": med([c["latency_ms"] for c in cases]) / 1000,
        "latency_max_s": max([c["latency_ms"] or 0 for c in cases] or [0]) / 1000,
        "prompt_tokens_med": int(med([c["prompt_tokens"] for c in cases])),
        "prompt_tokens_max": max([c["prompt_tokens"] or 0 for c in cases] or [0]),
    }
    git = lambda *a: subprocess.run(["git", "-C", str(ROOT), *a], capture_output=True, text=True).stdout.strip()  # noqa: E731
    profile_version = re.search(r"^version:\s*(\d+)", (ROOT / f"app/assets/profiles/{args.profile}.yaml").read_text(), re.M)
    env = {
        "date": dt.date.today().isoformat(), "host": f"{platform.system()} {platform.machine()}",
        "backend": "gpu" if args.gpu else "cpu", "model": Path(args.model).name, "model_sha256": sha256(args.model),
        "n_ctx": args.n_ctx, "max_tokens": args.max_tokens, "commit": git("rev-parse", "--short", "HEAD"),
        "llama": subprocess.run(["git", "-C", str(ROOT / "native/llama.cpp"), "rev-parse", "--short", "HEAD"],
                                capture_output=True, text=True).stdout.strip(),
        "profile_version": int(profile_version.group(1)) if profile_version else None,
    }
    model_slug = re.sub(r"[^A-Za-z0-9.-]+", "-", Path(args.model).stem)
    baseline_path = Path(args.baseline) if args.baseline else EVAL / "baselines" / f"{args.profile}.{model_slug}.json"
    diff, problems = {}, []
    if not args.no_baseline and baseline_path.exists() and not args.write_baseline:
        base = json.loads(baseline_path.read_text())["aggregate"]
        now_m, base_m = scoring.gate_metrics(agg), scoring.gate_metrics(base)
        diff = {k: (base_m[k], now_m[k]) for k in base_m if k in now_m}
        problems = scoring.regressions(agg, base)
    report = render_report(args.profile, args.model, agg, perf, env, cases, diff, problems, cfg.get("targets", {}))
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    stem = out_dir / f"{env['date']}-eval-{args.profile}-{model_slug}"
    stem.with_suffix(".md").write_text(report, encoding="utf-8")
    raw = {"env": env, "perf": perf, "aggregate": agg,
           "cases": [{k: c[k] for k in ("id", "valid", "prompt_tokens", "latency_ms", "n_prompt", "n_gen",
                                        "prefill_ms", "decode_ms", "output", "score", "issues")} for c in cases]}
    stem.with_suffix(".json").write_text(json.dumps(raw, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    if args.write_baseline:
        baseline_path.parent.mkdir(parents=True, exist_ok=True)
        baseline_path.write_text(json.dumps({"env": env, "perf": perf, "aggregate": agg}, indent=1) + "\n")
        print(f"eval: baseline written to {baseline_path.relative_to(ROOT)}")
    print(report.split("## Per case")[0])
    md = stem.with_suffix(".md")
    print(f"eval: report {md.relative_to(ROOT) if md.is_relative_to(ROOT) else md}")
    if problems and args.gate:
        print("eval: REGRESSION — " + "; ".join(problems), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
