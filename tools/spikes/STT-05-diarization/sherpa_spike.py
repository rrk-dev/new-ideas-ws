#!/usr/bin/env python3
"""STT-05 spike: sherpa-onnx offline speaker diarization on host.

Runs pyannote segmentation-3.0 + one speaker-embedding model + sherpa's
agglomerative clustering (the exact pipeline the bridge compiles in) over a
set of (wav, rttm[, uem]) items and scores DER with ../../bench/diarization/
der.py. Uses the `sherpa-onnx` Python wheel (same C++ core + onnxruntime as
the C API) in a throw-away venv:

    uv venv /tmp/vvd && uv pip install --python /tmp/vvd/bin/python sherpa-onnx numpy
    /tmp/vvd/bin/python sherpa_spike.py --items items.json --seg SEG.onnx \
        --emb EMB.onnx [--threshold 0.5] [--num-speakers N|oracle] [--threads 4] [--shift 0.1]

items.json: [{"id", "wav", "rttm", "uem"?}]. Prints one JSON line per item.
Throw-away spike code referenced by docs/adr/ADR-STT-05-diarization.md.
"""
from __future__ import annotations

import argparse
import json
import sys
import time
import wave
from pathlib import Path

import numpy as np
import sherpa_onnx

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / "bench" / "diarization"))
import der  # noqa: E402


def read_wav(path: str) -> np.ndarray:
    with wave.open(path, "rb") as w:
        assert w.getframerate() == 16000 and w.getnchannels() == 1 and w.getsampwidth() == 2, path
        pcm = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2")
    return pcm.astype(np.float32) / 32768.0


def build(seg: str, emb: str, threads: int, threshold: float, num: int, shift: float = 0.1) -> sherpa_onnx.OfflineSpeakerDiarization:
    cfg = sherpa_onnx.OfflineSpeakerDiarizationConfig(
        segmentation=sherpa_onnx.OfflineSpeakerSegmentationModelConfig(
            pyannote=sherpa_onnx.OfflineSpeakerSegmentationPyannoteModelConfig(model=seg, window_shift_ratio=shift),
            num_threads=threads,
        ),
        embedding=sherpa_onnx.SpeakerEmbeddingExtractorConfig(model=emb, num_threads=threads),
        clustering=sherpa_onnx.FastClusteringConfig(num_clusters=num, threshold=threshold),
        min_duration_on=0.3,
        min_duration_off=0.5,
    )
    if not cfg.validate():
        raise SystemExit("invalid config")
    return sherpa_onnx.OfflineSpeakerDiarization(cfg)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--items", required=True, type=Path)
    ap.add_argument("--seg", required=True)
    ap.add_argument("--emb", required=True)
    ap.add_argument("--threshold", type=float, default=0.5)
    ap.add_argument("--num-speakers", default="-1", help="N, -1 (auto) or 'oracle'")
    ap.add_argument("--threads", type=int, default=4)
    ap.add_argument("--shift", type=float, default=0.1, help="pyannote window_shift_ratio")
    ap.add_argument("--hyp-dir", type=Path)
    a = ap.parse_args()
    items = json.loads(a.items.read_text())
    for it in items:
        ref = der.read_rttm(Path(it["rttm"]))
        uem = der.read_uem(Path(it["uem"])) if it.get("uem") else None
        n_ref = len({t.speaker for t in ref})
        num = n_ref if a.num_speakers == "oracle" else int(a.num_speakers)
        x = read_wav(it["wav"])
        t0 = time.perf_counter()
        sd = build(a.seg, a.emb, a.threads, a.threshold, num, a.shift)
        t1 = time.perf_counter()
        res = sd.process(x).sort_by_start_time()
        t2 = time.perf_counter()
        hyp = [der.Turn(s.start, s.end, f"S{s.speaker}") for s in res]
        if a.hyp_dir:
            a.hyp_dir.mkdir(parents=True, exist_ok=True)
            der.write_rttm(a.hyp_dir / f"{it['id']}.rttm", it["id"], hyp)
        out = {"id": it["id"], "audio_s": round(len(x) / 16000, 1), "load_s": round(t1 - t0, 2),
               "process_s": round(t2 - t1, 2), "rtf": round((t2 - t1) / (len(x) / 16000), 4),
               "emb": Path(a.emb).name, "seg": Path(a.seg).name, "threshold": a.threshold,
               "num_speakers": num, "threads": a.threads, "shift": a.shift}
        for collar in (0.25, 0.0):
            s = der.score(ref, hyp, uem, collar=collar)
            s.pop("mapping")
            out[f"c{collar}"] = {k: (round(v, 4) if isinstance(v, float) else v) for k, v in s.items()}
        print(json.dumps(out), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
