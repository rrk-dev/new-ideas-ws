#!/usr/bin/env python3
"""[LLM-01] Run the llama.cpp spike matrix on the host and write a results table.

Usage:
  python3 -I tools/spikes/LLM-01-runtime/run.py --model-dir DIR [--runs 3]
      [--models a.gguf,b.gguf] [--out tools/bench/results/<date>-llm01-host]

Each config runs `llm_spike` --runs times in a fresh process (cold load each
time; the OS page cache is warm after the first run, which the table states).
Reports median and min/max (vv-benchmark-eval -> Reporting rules). Writes
<out>.json (raw) and <out>.md (table). Models are never copied into the repo.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import platform
import statistics
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[2]
BIN = ROOT / "native/build/spike-llm01/llm_spike"
GRAMMAR = HERE / "meeting.gbnf"

# name, extra args. prompt 2048 / gen 256 / ctx 4096 per vv-benchmark-eval.
CONFIGS = [
    ("metal-f16", ["--ngl", "99", "--kv", "f16", "--fa", "auto"]),
    ("metal-q8kv", ["--ngl", "99", "--kv", "q8_0", "--fa", "auto"]),
    ("metal-q8kv-grammar", ["--ngl", "99", "--kv", "q8_0", "--fa", "auto", "--grammar", str(GRAMMAR)]),
    ("cpu4-q8kv", ["--ngl", "0", "--kv", "q8_0", "--fa", "auto", "--threads", "4"]),
]
COMMON = ["--ctx", "4096", "--prompt", "2048", "--gen", "256"]
METRICS = ["load_ms", "ctx_init_ms", "prefill_tps", "decode_tps", "peak_footprint_bytes"]


def sha256(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def summarize(values: list[float]) -> dict:
    return {"median": statistics.median(values), "min": min(values), "max": max(values)}


def run_one(model: pathlib.Path, args: list[str]) -> dict:
    out = subprocess.run([str(BIN), "-m", str(model), *COMMON, *args],
                         check=True, capture_output=True, text=True)
    return json.loads(out.stdout.strip().splitlines()[-1])


def fmt(s: dict, scale: float = 1.0, digits: int = 1) -> str:
    return (f"{s['median'] / scale:.{digits}f} "
            f"({s['min'] / scale:.{digits}f}–{s['max'] / scale:.{digits}f})")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--model-dir", required=True, type=pathlib.Path)
    ap.add_argument("--models", default="")
    ap.add_argument("--runs", type=int, default=3)
    ap.add_argument("--configs", default="")
    ap.add_argument("--out", required=True, type=pathlib.Path)
    a = ap.parse_args()
    if not BIN.exists():
        print(f"missing {BIN}: run tools/spikes/LLM-01-runtime/build.sh", file=sys.stderr)
        return 2
    models = ([a.model_dir / m for m in a.models.split(",") if m]
              or sorted(a.model_dir.glob("*.gguf")))
    configs = [c for c in CONFIGS if not a.configs or c[0] in a.configs.split(",")]
    results = []
    for model in models:
        digest = sha256(model)
        for name, args in configs:
            runs = [run_one(model, args) for _ in range(a.runs)]
            hashes = {r["output_hash"] for r in runs}
            row = {
                "model": model.name, "sha256": digest, "config": name,
                "file_bytes": model.stat().st_size, "runs": runs,
                "deterministic": len(hashes) == 1,
                "prompt_tokens": runs[0]["prompt_tokens"],
                "gen_tokens": [r["gen_tokens"] for r in runs],
                **{m: summarize([r[m] for r in runs]) for m in METRICS},
            }
            results.append(row)
            print(f"{model.name:40s} {name:20s} decode {fmt(row['decode_tps'])} tok/s", flush=True)

    env = {
        "host": platform.platform(), "machine": platform.machine(),
        "cpu": subprocess.run(["sysctl", "-n", "machdep.cpu.brand_string"],
                              capture_output=True, text=True).stdout.strip(),
        "llama_cpp": subprocess.run(["git", "-C", str(ROOT / "native/llama.cpp"), "describe", "--tags", "--always"],
                                    capture_output=True, text=True).stdout.strip(),
        "runs": a.runs, "common_args": COMMON,
    }
    a.out.parent.mkdir(parents=True, exist_ok=True)
    a.out.with_suffix(".json").write_text(json.dumps({"env": env, "results": results}, indent=1) + "\n")
    lines = [
        "| Model | Config | Prefill tok/s | Decode tok/s | Cold load ms | Ctx init ms | Peak footprint MiB | Deterministic |",
        "|---|---|---|---|---|---|---|---|",
    ]
    for r in results:
        lines.append(
            f"| {r['model']} | {r['config']} | {fmt(r['prefill_tps'])} | {fmt(r['decode_tps'])} | "
            f"{fmt(r['load_ms'], digits=0)} | {fmt(r['ctx_init_ms'], digits=0)} | "
            f"{fmt(r['peak_footprint_bytes'], 1 << 20, 0)} | {'yes' if r['deterministic'] else 'NO'} |")
    a.out.with_suffix(".md").write_text(
        "# LLM-01 host benchmark (HOST, not a target device)\n\n"
        f"Environment: `{json.dumps(env)}`\n\n"
        "Median (min–max) of n runs, each a fresh process. Prompt = chat-templated synthetic "
        "meeting transcript, greedy decode, EOG banned (unconstrained) / grammar `meeting.gbnf`.\n\n"
        + "\n".join(lines) + "\n\nModels (sha256):\n\n"
        + "\n".join(sorted({f"- `{r['model']}` `{r['sha256']}` ({r['file_bytes']} B)" for r in results}))
        + "\n")
    print(a.out.with_suffix(".md"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
