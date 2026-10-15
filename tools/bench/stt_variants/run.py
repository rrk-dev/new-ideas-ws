#!/usr/bin/env python3
"""STT-07 model-variant matrix on the host build (vv-benchmark-eval).

For every model file: WER per corpus clip (English clips for every model, non-English clips
for multilingual models with the clip's language selected), RTF on a 60 s tiled clip for the
GPU (Metal) and CPU paths (median/min/max of --runs), load time and process peak RSS.

  tools/bench/stt_variants/make_corpus.sh               # once (macOS say/afconvert)
  cmake --build native/build/host --target stt_backends # or tools/bench/stt_host_bench.sh
  python3 -I tools/bench/stt_variants/run.py --out tools/bench/results/<date>-stt07-variants

Models are read from $VV_BENCH_MODELS_DIR (default ~/.cache/vaultvoice/bench) — never commit
models or audio. Writes <out>.json (raw) and <out>.md (table).
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
import pathlib
import platform
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[3]
BENCH = pathlib.Path(os.environ.get("VV_BENCH_MODELS_DIR", pathlib.Path.home() / ".cache/vaultvoice/bench"))
DEFAULT_MODELS = [
    "ggml-tiny.en.bin", "ggml-tiny.en-q5_1.bin", "ggml-base.en.bin", "ggml-base.en-q5_1.bin",
    "ggml-base.en-q8_0.bin", "ggml-small.en-q5_1.bin", "ggml-small.en-q8_0.bin",
    "ggml-base-q5_1.bin", "ggml-small-q5_1.bin", "ggml-large-v3-turbo-q5_0.bin",
    "ggml-large-v3-turbo-q8_0.bin",
]


def _wer_module():
    spec = importlib.util.spec_from_file_location(
        "vv_wer", ROOT / ".agents/skills/vv-benchmark-eval/scripts/wer.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)  # type: ignore[union-attr]
    return mod


def sha256(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def bench(binary: pathlib.Path, model: pathlib.Path, wav: pathlib.Path, *, seconds: int, runs: int,
          gpu: int, lang: str, threads: int, hyp: pathlib.Path | None = None) -> dict:
    cmd = [str(binary), "bench", "--model", str(model), "--wav", str(wav), "--seconds", str(seconds),
           "--runs", str(runs), "--gpu", str(gpu), "--lang", lang, "--threads", str(threads),
           "--label", f"{'gpu' if gpu else 'cpu'}"]
    if hyp is not None:
        cmd += ["--hyp-out", str(hyp)]
    out = subprocess.run(cmd, check=True, capture_output=True, text=True).stdout
    return json.loads(out.strip().splitlines()[-1])


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--bin", default=str(ROOT / "native/build/host/stt_backends"))
    ap.add_argument("--models", nargs="*", default=DEFAULT_MODELS)
    ap.add_argument("--runs", type=int, default=3)
    ap.add_argument("--threads", type=int, default=4)
    ap.add_argument("--speed-clip", default="en-meeting-1")
    ap.add_argument("--out", required=True, help="path prefix for .json and .md")
    a = ap.parse_args()
    wer = _wer_module()
    corpus = BENCH / "corpus"
    clips = [json.loads(l) for l in open(ROOT / "tools/bench/stt_variants/passages.jsonl", encoding="utf-8")
             if l.strip()]
    binary = pathlib.Path(a.bin)
    rows = []
    for name in a.models:
        model = BENCH / name
        if not model.exists():
            model = pathlib.Path(os.environ.get("VV_TEST_MODELS_DIR", BENCH.parent / "test-models")) / name
        if not model.exists():
            print(f"skip {name}: not downloaded", file=sys.stderr)
            continue
        multilingual = ".en" not in name
        row = {"model": name, "size": model.stat().st_size, "sha256": sha256(model),
               "multilingual": multilingual, "wer": {}, "speed": {}}
        print(f"== {name}", file=sys.stderr)
        with tempfile.TemporaryDirectory() as td:
            totals = {"en": [0, 0], "xx": [0, 0]}
            for c in clips:
                if c["lang"] != "en" and not multilingual:
                    continue
                hyp = pathlib.Path(td) / f"{c['id']}.txt"
                bench(binary, model, corpus / f"{c['id']}.wav", seconds=0, runs=1, gpu=1,
                      lang=c["lang"], threads=a.threads, hyp=hyp)
                ref_w = wer.normalize(c["text"])
                s, d, i = wer.edit_counts(ref_w, wer.normalize(hyp.read_text(encoding="utf-8")))
                row["wer"][c["id"]] = round((s + d + i) / len(ref_w), 4)
                k = "en" if c["lang"] == "en" else "xx"
                totals[k][0] += s + d + i
                totals[k][1] += len(ref_w)
            row["wer_en"] = round(totals["en"][0] / totals["en"][1], 4)
            row["wer_multi"] = round(totals["xx"][0] / totals["xx"][1], 4) if totals["xx"][1] else None
        for gpu in (1, 0):
            r = bench(binary, model, corpus / f"{a.speed_clip}.wav", seconds=60, runs=a.runs, gpu=gpu,
                      lang="en", threads=a.threads)
            row["speed"]["gpu" if gpu else "cpu"] = r
        rows.append(row)
        print(json.dumps(row), file=sys.stderr)

    whisper_rev = subprocess.run(["git", "-C", str(ROOT / "native/whisper.cpp"), "describe", "--tags", "--always"],
                                 capture_output=True, text=True).stdout.strip()
    meta = {
        "host": f"{platform.system()} {platform.machine()} "
                + subprocess.run(["sysctl", "-n", "machdep.cpu.brand_string"], capture_output=True,
                                 text=True).stdout.strip(),
        "whisper_cpp": whisper_rev, "threads": a.threads, "runs": a.runs,
        "decode": "greedy, no_context, suppress_nst, temperature fallback default",
        "corpus": "tools/bench/stt_variants/passages.jsonl rendered by make_corpus.sh (macOS TTS)",
    }
    pathlib.Path(a.out + ".json").write_text(json.dumps({"meta": meta, "rows": rows}, indent=1) + "\n")
    lines = [f"# STT-07 model variants — host bench", "",
             f"- Host: {meta['host']}; whisper.cpp {meta['whisper_cpp']}; threads {a.threads}; "
             f"speed runs {a.runs} (median, min–max); WER runs 1 (greedy is deterministic per backend).",
             f"- Corpus: {meta['corpus']}. English WER over {sum(1 for c in clips if c['lang']=='en')} clips; "
             f"multilingual WER over de/fr/es clips with the language selected.",
             "- RTF = decode wall time / audio duration (excl. load) on a 60 s tiled clip; "
             "peak RSS = process max RSS of the CPU run (Metal buffers on unified memory are not fully "
             "counted in the GPU run).", "",
             "| Model | Size MB | sha256 (16) | WER en | WER de/fr/es | RTF Metal | RTF CPU (min–max) | Load ms | Peak RSS MB (CPU) |",
             "|---|---:|---|---:|---:|---:|---:|---:|---:|"]
    for r in rows:
        g, c = r["speed"]["gpu"], r["speed"]["cpu"]
        lines.append(
            f"| {r['model']} | {r['size'] / 1e6:.1f} | `{r['sha256'][:16]}` | {r['wer_en'] * 100:.1f}% | "
            + (f"{r['wer_multi'] * 100:.1f}%" if r["wer_multi"] is not None else "—")
            + f" | {g['rtf']:.3f} | {c['rtf']:.3f} ({c['full_ms_min'] / 60000:.3f}–{c['full_ms_max'] / 60000:.3f})"
            f" | {c['load_ms_median']:.0f} | {c['peak_rss_mb']:.0f} |")
    pathlib.Path(a.out + ".md").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
