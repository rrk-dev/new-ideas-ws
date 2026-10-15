#!/usr/bin/env python3
"""QA-02 STT benchmark: WER / RTF / load time / peak RSS on the host bridge.

One command produces the full report (vv-benchmark-eval → STT):

  python3 tools/bench/stt_wer/run.py                     # all experiments
  python3 tools/bench/stt_wer/run.py --experiments models --models ggml-tiny.en.bin ggml-base.en-q5_1.bin

Experiments
  models  every corpus item (clean) × every --models file → WER per subset/tag,
          RTF (Σ process / Σ audio), cold load, peak RSS (one subprocess per model)
  agc     synthetic items under level/noise conditions, AUD-02 software AGC off vs on
          (platform AGC/NS can only be measured on devices — see the device rows)
  vad     synthetic items with 8 s room-tone pauses between turns: untrimmed vs
          trimmed to speech (oracle spans, and a simple energy VAD) via
          vv_stt_transcribe_ranges — the AUD-03 trimming path

Inputs: corpus audio from tools/bench/corpus/make_corpus.py ($VV_BENCH_CORPUS_DIR),
models from $VV_BENCH_MODELS_DIR (~/.cache/vaultvoice/bench) and
$VV_TEST_MODELS_DIR (~/.cache/vaultvoice/test-models), the host bridge
native/build/host/libvv_native.{dylib,so} (native/build.sh host).
Output: <out>.jsonl (raw per item) + <out>.md (tables), default
tools/bench/results/<date>-qa02-stt-wer.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import platform
import resource
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE))

DEFAULT_MODELS = ["ggml-tiny.en.bin", "ggml-base.en-q5_1.bin", "ggml-small.en-q5_1.bin"]
AGC_MODEL = "ggml-base.en-q5_1.bin"
AGC_CONDITIONS = [  # (name, level dB, noise kind, SNR dB)
    ("clean", 0, None, None),
    ("quiet-24dB", -24, None, None),
    ("babble-10dB", 0, "babble", 10),
    ("white-5dB", 0, "white", 5),
    ("quiet-24dB+babble-10dB", -24, "babble", 10),
]
VAD_GAP_S = 8.0
VAD_PAD_MS = 200


def corpus_dir() -> Path:
    env = os.environ.get("VV_BENCH_CORPUS_DIR")
    return Path(env) if env else Path.home() / ".cache/vaultvoice/bench/qa02-corpus"


def model_dirs() -> list[Path]:
    return [Path(os.environ.get("VV_BENCH_MODELS_DIR", Path.home() / ".cache/vaultvoice/bench")),
            Path(os.environ.get("VV_TEST_MODELS_DIR",
                                Path.home() / ".cache/vaultvoice/test-models"))]


def find_model(name: str) -> Path:
    p = Path(name)
    if p.is_file():
        return p
    for d in model_dirs():
        if (d / name).is_file():
            return d / name
    raise SystemExit(f"model {name} not found in {[str(d) for d in model_dirs()]}")


def bridge_lib() -> Path:
    for n in ("libvv_native.dylib", "libvv_native.so"):
        p = ROOT / "native/build/host" / n
        if p.exists():
            return p
    raise SystemExit("host bridge missing: run native/build.sh host")


def sha16(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()[:16]


def load_corpus(manifest: Path) -> list[dict]:
    return [json.loads(l) for l in manifest.read_text().splitlines() if l.strip()]


# ---------------------------------------------------------------- worker ----

def worker(job_file: Path) -> None:
    """Runs in its own process: one model, many items; prints JSON lines."""
    import time

    import bridge
    import wer
    job = json.loads(job_file.read_text())
    b = bridge.Bridge(Path(job["lib"]))
    t0 = time.perf_counter()
    m = b.open(Path(job["model"]), use_gpu=job["gpu"])
    load_ms = (time.perf_counter() - t0) * 1000
    print(json.dumps({"kind": "load", "load_ms": round(load_ms, 1),
                      "whisper": b.whisper_version}), flush=True)
    for it in job["items"]:
        r = m.transcribe(Path(it["wav"]), ranges=it.get("ranges"), threads=job["threads"])
        print(json.dumps({"kind": "item", "id": it["id"], "variant": it.get("variant", ""),
                          "tags": it.get("tags", []), "hyp": r["text"], "audio_ms": r["audio_ms"],
                          "process_ms": r["process_ms"], **wer.score(it["ref"], r["text"])}),
              flush=True)
    m.close()
    rss = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    rss_mb = rss / (1024 * 1024) if sys.platform == "darwin" else rss / 1024
    print(json.dumps({"kind": "rss", "peak_rss_mb": round(rss_mb, 1)}), flush=True)


def run_worker(model: Path, items: list[dict], gpu: bool, threads: int) -> dict:
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
        json.dump({"lib": str(bridge_lib()), "model": str(model), "gpu": gpu,
                   "threads": threads, "items": items}, f)
    try:
        out = subprocess.run([sys.executable, str(Path(__file__)), "--worker", f.name],
                             capture_output=True, text=True, check=False)
    finally:
        os.unlink(f.name)
    if out.returncode != 0:
        raise SystemExit(f"worker failed for {model.name}:\n{out.stderr[-2000:]}")
    res = {"items": []}
    for line in out.stdout.splitlines():
        e = json.loads(line)
        if e["kind"] == "item":
            res["items"].append(e)
        else:
            res.update({k: v for k, v in e.items() if k != "kind"})
    return res


# ----------------------------------------------------------- experiments ----

def summarize(items: list[dict]) -> dict:
    import wer
    audio = sum(i["audio_ms"] for i in items)
    proc = sum(i["process_ms"] for i in items)
    return {"wer": round(100 * wer.wer(items), 2), "words": sum(i["n"] for i in items),
            "ins": sum(i["ins"] for i in items), "audio_s": round(audio / 1000, 1),
            "process_s": round(proc / 1000, 2), "rtf": round(proc / audio, 4) if audio else 0}


def exp_models(corpus, cdir, models, gpu, threads, runs):
    items = [{"id": c["id"], "wav": str(cdir / c["audio"]), "ref": c["ref"], "tags": c["tags"]}
             for c in corpus]
    rows, raw = [], []
    for name in models:
        path = find_model(name)
        best, rtfs, loads = None, [], []
        for run in range(runs):
            r = run_worker(path, items, gpu, threads)
            raw += [{"experiment": "models", "model": name, "run": run, **i} for i in r["items"]]
            s = summarize(r["items"])
            rtfs.append(s["rtf"])
            loads.append(r["load_ms"])
            if best is None or s["rtf"] < best["rtf"]:
                best = {**s, "rss": r["peak_rss_mb"]}
        # WER is deterministic (greedy); timing: median + min/max of the runs.
        best.update(rtf_runs=rtfs, rtf=sorted(rtfs)[len(rtfs) // 2],
                    load_ms=sorted(loads)[len(loads) // 2])
        subsets = {}
        for tag in ("synthetic", "librispeech", "meeting", "accent", "numbers"):
            sub = [i for i in r["items"] if tag in i["tags"]]
            if sub:
                subsets[tag] = summarize(sub)["wer"]
        rows.append({"model": name, "sha": sha16(path), "mb": round(path.stat().st_size / 2**20, 1),
                     **best, "subsets": subsets, "whisper": r["whisper"]})
    return rows, raw


def exp_agc(corpus, cdir, gpu, threads):
    import audio
    synth = [c for c in corpus if "synthetic" in c["tags"]]
    derived = cdir / "derived" / "agc"
    items = []
    for name, level, kind, snr in AGC_CONDITIONS:
        for c in synth:
            x = audio.read_wav(cdir / c["audio"])
            x = audio.gain(x, level)
            if kind:
                x = audio.add_noise(x, snr, kind, seed=7)
            for agc in (False, True):
                wav = derived / f"{name}-{'agc' if agc else 'raw'}" / f"{c['id']}.wav"
                if not wav.exists():
                    audio.write_wav(wav, audio.software_agc(x) if agc else x)
                items.append({"id": c["id"], "wav": str(wav), "ref": c["ref"],
                              "variant": f"{name}|{'on' if agc else 'off'}", "tags": c["tags"],
                              "level_dbfs": round(audio.rms_db(x), 1)})
    r = run_worker(find_model(AGC_MODEL), items, gpu, threads)
    rows = []
    for name, *_ in AGC_CONDITIONS:
        row = {"condition": name}
        for state in ("off", "on"):
            sub = [i for i in r["items"] if i["variant"] == f"{name}|{state}"]
            row[state] = summarize(sub)["wer"]
        rows.append(row)
    return rows, [{"experiment": "agc", "model": AGC_MODEL, **i} for i in r["items"]]


def energy_vad(x, frame_ms=30, thresh_db=-45.0, hang_ms=300, min_ms=200):
    """Simple RMS-threshold VAD with hangover (host stand-in for AUD-03)."""
    import numpy as np

    import audio
    f = audio.RATE * frame_ms // 1000
    n = len(x) // f
    active = [audio.rms_db(x[i * f:(i + 1) * f]) > thresh_db for i in range(n)]
    segs, start, last = [], None, -10 ** 9
    for i, a in enumerate(active):
        t = i * frame_ms
        if a:
            if start is None:
                start = t
            last = t + frame_ms
        elif start is not None and t - last > hang_ms:
            if last - start >= min_ms:
                segs.append((start, last))
            start = None
    if start is not None:
        segs.append((start, last))
    _ = np
    return segs


def exp_vad(corpus, cdir, gpu, threads, model):
    import audio
    synth = [c for c in corpus if "synthetic" in c["tags"]]
    derived = cdir / "derived" / "vad"
    items = []
    for c in synth:
        x = audio.read_wav(cdir / c["audio"])
        segs = json.loads((cdir / c["audio"]).with_suffix(".segments.json").read_text())
        y, new = audio.pad_silence([tuple(s) for s in segs], x, VAD_GAP_S)
        wav = derived / f"{c['id']}.wav"
        if not wav.exists():
            audio.write_wav(wav, y)
        pad = lambda ss: [(max(0, s - VAD_PAD_MS), e + VAD_PAD_MS) for s, e in ss]  # noqa: E731
        base = {"id": c["id"], "wav": str(wav), "ref": c["ref"], "tags": c["tags"]}
        items += [{**base, "variant": "untrimmed"},
                  {**base, "variant": "oracle", "ranges": pad(new)},
                  {**base, "variant": "energy", "ranges": pad(energy_vad(y))}]
    r = run_worker(find_model(model), items, gpu, threads)
    rows = []
    for v in ("untrimmed", "oracle", "energy"):
        rows.append({"variant": v, **summarize([i for i in r["items"] if i["variant"] == v])})
    return rows, [{"experiment": "vad", "model": model, **i} for i in r["items"]]


# ---------------------------------------------------------------- report ----

def env_line(gpu: bool, threads: int) -> str:
    cpu = ""
    if sys.platform == "darwin":
        cpu = subprocess.run(["sysctl", "-n", "machdep.cpu.brand_string"], capture_output=True,
                             text=True).stdout.strip()
    head = subprocess.run(["git", "-C", str(ROOT), "rev-parse", "--short", "HEAD"],
                          capture_output=True, text=True).stdout.strip()
    return (f"{platform.system()} {platform.machine()} {cpu}; repo {head}; bridge "
            f"{bridge_lib().name}; backend {'GPU (Metal)' if gpu else 'CPU'}; threads "
            f"{threads or 'bridge default (perf cores ≤ 4)'}; app default vv_stt_params "
            "(greedy, temperature fallback 0.2, no_context, suppress_nst)")


def markdown(meta, models, agc, vad) -> str:
    out = [f"# QA-02 STT benchmark — {meta['date']}", "", f"Environment: {meta['env']}.",
           f"Corpus: {meta['corpus']}. WER normalizer: `tools/bench/stt_wer/wer.py`.", ""]
    if models:
        out += ["## Models (clean corpus)", "",
                "| Model | MB | sha256[:16] | WER all % | synthetic | LibriSpeech | meeting | accent "
                "| numbers | RTF (median) | RTF runs | cold load ms (median) | peak RSS MB |",
                "|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
        for r in models:
            s = r["subsets"]
            out.append(f"| `{r['model']}` | {r['mb']} | `{r['sha']}` | {r['wer']} | "
                       f"{s.get('synthetic', '')} | {s.get('librispeech', '')} | "
                       f"{s.get('meeting', '')} | {s.get('accent', '')} | {s.get('numbers', '')} | "
                       f"{r['rtf']} | {', '.join(map(str, r['rtf_runs']))} | {r['load_ms']} | "
                       f"{r['rss']} |")
        out += ["", f"whisper.cpp {models[0]['whisper']}; {models[0]['words']} reference words, "
                f"{models[0]['audio_s']} s of audio per model run.", ""]
    if agc:
        out += [f"## Software AGC (AUD-02) off vs on — `{AGC_MODEL}`, synthetic subset", "",
                "| Condition | WER AGC off % | WER AGC on % | Δ |", "|---|---|---|---|"]
        for r in agc:
            out.append(f"| {r['condition']} | {r['off']} | {r['on']} | "
                       f"{round(r['on'] - r['off'], 2):+} |")
        out.append("")
    if vad:
        out += [f"## VAD trimming (AUD-03) — {VAD_GAP_S:.0f} s pauses between turns, "
                f"`{meta['vad_model']}`", "",
                "| Variant | WER % | insertions | audio s transcribed | processing s | RTF vs "
                "full length |", "|---|---|---|---|---|---|"]
        full = next((r["audio_s"] for r in vad if r["variant"] == "untrimmed"), 0) or 1
        for r in vad:
            out.append(f"| {r['variant']} | {r['wer']} | {r['ins']} | {r['audio_s']} | "
                       f"{r['process_s']} | {round(r['process_s'] / full, 4)} |")
        out.append("")
    return "\n".join(out)


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--worker", type=Path)
    ap.add_argument("--experiments", nargs="+", default=["models", "agc", "vad"])
    ap.add_argument("--models", nargs="+", default=DEFAULT_MODELS)
    ap.add_argument("--vad-model", default=AGC_MODEL)
    ap.add_argument("--gpu", type=int, default=0)
    ap.add_argument("--threads", type=int, default=0)
    ap.add_argument("--runs", type=int, default=3, help="runs per model (RTF median, all runs)")
    ap.add_argument("--out", type=Path)
    ap.add_argument("--corpus", type=Path, default=ROOT / "tools/bench/corpus/corpus.jsonl",
                    help="manifest; a private one (consented recordings, kept outside the "
                         "repo) uses the same line format")
    a = ap.parse_args(argv)
    if a.worker:
        worker(a.worker)
        return 0
    cdir = corpus_dir()
    corpus = load_corpus(a.corpus)
    missing = [c["id"] for c in corpus if not (cdir / c["audio"]).exists()]
    if missing:
        raise SystemExit(f"{len(missing)} corpus files missing in {cdir} — run "
                         "tools/bench/corpus/make_corpus.py")
    date = dt.date.today().isoformat()
    out = a.out or ROOT / f"tools/bench/results/{date}-qa02-stt-wer"
    models, agc, vad, raw = [], [], [], []
    if "models" in a.experiments:
        models, r = exp_models(corpus, cdir, a.models, bool(a.gpu), a.threads, a.runs)
        raw += r
    if "agc" in a.experiments:
        agc, r = exp_agc(corpus, cdir, bool(a.gpu), a.threads)
        raw += r
    if "vad" in a.experiments:
        vad, r = exp_vad(corpus, cdir, bool(a.gpu), a.threads, a.vad_model)
        raw += r
    n_s = sum("synthetic" in c["tags"] for c in corpus)
    meta = {"date": date, "env": env_line(bool(a.gpu), a.threads), "vad_model": a.vad_model,
            "corpus": f"{len(corpus)} items ({n_s} synthetic, {len(corpus) - n_s} LibriSpeech "
                      "test-clean) from tools/bench/corpus/corpus.jsonl"}
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.with_suffix(".jsonl").open("w") as f:
        f.write(json.dumps({"meta": meta, "models": models, "agc": agc, "vad": vad}) + "\n")
        for r in raw:
            f.write(json.dumps(r) + "\n")
    out.with_suffix(".md").write_text(markdown(meta, models, agc, vad) + "\n")
    print(out.with_suffix(".md").read_text())
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
