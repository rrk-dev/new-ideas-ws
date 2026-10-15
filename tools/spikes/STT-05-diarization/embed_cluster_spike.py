#!/usr/bin/env python3
"""STT-05 spike, option C: VAD + windowed speaker embeddings + our own AHC.

1. speech spans from the app's VAD (whisper.cpp Silero through the host
   bridge `vv_vad_segments`, exactly as the pipeline computes them),
2. speaker embeddings of fixed windows (``--win`` s, hop ``--hop`` s) inside
   the speech spans (sherpa-onnx SpeakerEmbeddingExtractor = the C API's
   embedding extractor + onnxruntime),
3. agglomerative clustering on cosine distance (average / centroid /
   complete linkage, threshold or a known number of speakers), then clusters
   holding < ``--min-cluster-s`` of speech are merged into their nearest
   large cluster (pyannote-style),
4. frame-level majority vote of overlapping windows -> speaker turns.

Embeddings are cached in ``--cache`` (scratch only, never the repo: they are
voiceprints of the AMI participants) so clustering variants can be swept.

    python embed_cluster_spike.py --items items.json --lib libvv_native.dylib \
        --vad ggml-silero-v6.2.0.bin --emb EMB.onnx --cache /tmp/x [options]

Throw-away spike code referenced by docs/adr/ADR-STT-05-diarization.md.
"""
from __future__ import annotations

import argparse
import ctypes as C
import json
import resource
import sys
import time
import wave
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / "bench" / "diarization"))
import der  # noqa: E402

RATE = 16000


class VadParams(C.Structure):
    _fields_ = [("struct_size", C.c_uint32), ("threshold", C.c_float),
                ("min_speech_ms", C.c_int32), ("min_silence_ms", C.c_int32),
                ("speech_pad_ms", C.c_int32), ("max_speech_s", C.c_float),
                ("n_threads", C.c_int32)]


class Range(C.Structure):
    _fields_ = [("path", C.c_char_p), ("start_ms", C.c_int64), ("end_ms", C.c_int64)]


def vad_segments(lib: Path, model: Path, wav: str) -> list[tuple[int, int]]:
    L = C.CDLL(str(lib))
    L.vv_vad_default_params.restype = VadParams
    L.vv_vad_create.argtypes = [C.c_char_p, C.POINTER(VadParams), C.POINTER(C.c_void_p)]
    L.vv_vad_segments.argtypes = [C.c_void_p, C.POINTER(Range), C.c_size_t, C.POINTER(C.c_void_p)]
    L.vv_free_string.argtypes = [C.c_void_p]
    L.vv_vad_destroy.argtypes = [C.c_void_p]
    p = L.vv_vad_default_params()
    h = C.c_void_p()
    assert L.vv_vad_create(str(model).encode(), C.byref(p), C.byref(h)) == 0
    r = (Range * 1)(Range(wav.encode(), 0, -1))
    out = C.c_void_p()
    assert L.vv_vad_segments(h, r, 1, C.byref(out)) == 0
    js = json.loads(C.cast(out, C.c_char_p).value.decode())
    L.vv_free_string(out)
    L.vv_vad_destroy(h)
    return [(s["start_ms"], s["end_ms"]) for s in js]


def read_wav(path: str) -> np.ndarray:
    with wave.open(path, "rb") as w:
        pcm = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2")
    return pcm.astype(np.float32) / 32768.0


def windows(speech: list[tuple[int, int]], win: float, hop: float, min_win: float) -> list[tuple[float, float]]:
    out = []
    for s, e in speech:
        s, e = s / 1000, e / 1000
        t = s
        while t < e:
            end = min(t + win, e)
            if end - t >= min_win or (t == s and end - t >= 0.25):
                out.append((t, end))
            if end >= e:
                break
            t += hop
    return out


def embed(extractor, x: np.ndarray, wins: list[tuple[float, float]]) -> np.ndarray:
    embs = []
    for s, e in wins:
        st = extractor.create_stream()
        st.accept_waveform(RATE, x[int(s * RATE):int(e * RATE)])
        st.input_finished()
        embs.append(np.array(extractor.compute(st), dtype=np.float32))
    m = np.stack(embs)
    return m / (np.linalg.norm(m, axis=1, keepdims=True) + 1e-9)


def ahc(e: np.ndarray, linkage: str, threshold: float, k: int) -> np.ndarray:
    """Agglomerative clustering on cosine distance; stops at k clusters
    (k > 0) or when the closest pair is farther than threshold."""
    n = len(e)
    labels = np.arange(n)
    if n <= 1:
        return np.zeros(n, dtype=int)
    size = np.ones(n)
    cent = e.astype(np.float64).copy()
    d = 1.0 - cent @ cent.T
    np.fill_diagonal(d, np.inf)
    active = np.ones(n, dtype=bool)
    clusters = n
    while clusters > 1:
        idx = np.argmin(d)
        i, j = divmod(idx, n)
        if k > 0:
            if clusters <= k:
                break
        elif d[i, j] > threshold:
            break
        # merge j into i
        if linkage == "average":
            new = (d[i] * size[i] + d[j] * size[j]) / (size[i] + size[j])
        elif linkage == "complete":
            new = np.maximum(d[i], d[j])
        elif linkage == "single":
            new = np.minimum(d[i], d[j])
        else:  # centroid on normalised centroids (cosine)
            c = cent[i] * size[i] + cent[j] * size[j]
            c = c / (np.linalg.norm(c) + 1e-12)
            cent[i] = c
            new = 1.0 - cent @ c
        size[i] += size[j]
        active[j] = False
        new[~active] = np.inf
        new[i] = np.inf
        d[i, :] = new
        d[:, i] = new
        d[j, :] = np.inf
        d[:, j] = np.inf
        labels[labels == j] = i
        clusters -= 1
    _, labels = np.unique(labels, return_inverse=True)
    return labels


def reassign_small(e: np.ndarray, labels: np.ndarray, dur: np.ndarray, min_s: float, k: int) -> np.ndarray:
    """Merge clusters with < min_s seconds of speech into the nearest large
    cluster (by centroid cosine). Keeps at least one cluster."""
    ids = np.unique(labels)
    tot = np.array([dur[labels == c].sum() for c in ids])
    large = ids[tot >= min_s]
    if k > 0:
        large = ids[np.argsort(-tot)[:k]]
    if len(large) == 0:
        large = ids[[int(np.argmax(tot))]]
    cents = np.stack([e[labels == c].mean(0) for c in large])
    cents /= np.linalg.norm(cents, axis=1, keepdims=True) + 1e-12
    out = labels.copy()
    for c in ids:
        if c in large:
            continue
        m = labels == c
        # per member: nearest large centroid
        sims = e[m] @ cents.T
        out[m] = large[np.argmax(sims, axis=1)]
    _, out = np.unique(out, return_inverse=True)
    return out


def to_turns(wins: list[tuple[float, float]], labels: np.ndarray, speech: list[tuple[int, int]]) -> list[der.Turn]:
    end = max(e for _, e in wins) if wins else 0
    nf = int(end / der.FRAME) + 2
    nl = int(labels.max()) + 1 if len(labels) else 1
    votes = np.zeros((nf, nl), dtype=np.float32)
    for (s, e), l in zip(wins, labels):
        a, b = int(s / der.FRAME), int(e / der.FRAME)
        # triangular weight: window centres are more reliable
        w = 1.0 - np.abs(np.linspace(-1, 1, max(1, b - a))) * 0.5
        votes[a:b, l] += w
    turns: list[der.Turn] = []
    for s, e in speech:
        a, b = int(s / 1000 / der.FRAME), min(nf, int(e / 1000 / der.FRAME))
        if b <= a:
            continue
        lab = votes[a:b].argmax(1)
        has = votes[a:b].max(1) > 0
        cur, start = None, a
        for f in range(a, b):
            l = int(lab[f - a]) if has[f - a] else cur
            if l != cur:
                if cur is not None:
                    turns.append(der.Turn(start * der.FRAME, f * der.FRAME, f"S{cur}"))
                cur, start = l, f
        if cur is not None:
            turns.append(der.Turn(start * der.FRAME, b * der.FRAME, f"S{cur}"))
    return turns


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--items", required=True, type=Path)
    ap.add_argument("--lib", required=True, type=Path)
    ap.add_argument("--vad", required=True, type=Path)
    ap.add_argument("--emb", required=True)
    ap.add_argument("--cache", required=True, type=Path)
    ap.add_argument("--win", type=float, default=1.5)
    ap.add_argument("--hop", type=float, default=0.75)
    ap.add_argument("--min-win", type=float, default=0.5)
    ap.add_argument("--threads", type=int, default=4)
    ap.add_argument("--linkage", default="average")
    ap.add_argument("--thresholds", default="0.5,0.6,0.7")
    ap.add_argument("--min-cluster-s", type=float, default=10.0)
    ap.add_argument("--oracle", action="store_true", help="also cluster with the true speaker count")
    a = ap.parse_args()
    import sherpa_onnx
    extractor = None
    for it in json.loads(a.items.read_text()):
        ref = der.read_rttm(Path(it["rttm"]))
        uem = der.read_uem(Path(it["uem"])) if it.get("uem") else None
        n_ref = len({t.speaker for t in ref})
        key = f"{it['id']}-{Path(a.emb).stem}-w{a.win}-h{a.hop}"
        cache = a.cache / f"{key}.npz"
        x = read_wav(it["wav"])
        timing = {}
        if cache.exists():
            z = np.load(cache)
            speech = [tuple(map(int, s)) for s in z["speech"]]
            wins = [tuple(w) for w in z["wins"]]
            e = z["emb"]
            timing = json.loads(str(z["timing"]))
        else:
            t0 = time.perf_counter()
            c0 = resource.getrusage(resource.RUSAGE_SELF)
            speech = vad_segments(a.lib, a.vad, it["wav"])
            t1 = time.perf_counter()
            c1 = resource.getrusage(resource.RUSAGE_SELF)
            if extractor is None:
                extractor = sherpa_onnx.SpeakerEmbeddingExtractor(
                    sherpa_onnx.SpeakerEmbeddingExtractorConfig(model=a.emb, num_threads=a.threads))
            wins = windows(speech, a.win, a.hop, a.min_win)
            e = embed(extractor, x, wins)
            t2 = time.perf_counter()
            c2 = resource.getrusage(resource.RUSAGE_SELF)
            timing = {"vad_s": round(t1 - t0, 2), "embed_s": round(t2 - t1, 2),
                      "vad_cpu_s": round(c1.ru_utime + c1.ru_stime - c0.ru_utime - c0.ru_stime, 2),
                      "embed_cpu_s": round(c2.ru_utime + c2.ru_stime - c1.ru_utime - c1.ru_stime, 2)}
            a.cache.mkdir(parents=True, exist_ok=True)
            np.savez(cache, speech=np.array(speech), wins=np.array(wins), emb=e, timing=json.dumps(timing))
        dur = np.array([w[1] - w[0] for w in wins]) * (a.hop / a.win)
        configs = [("thr", float(t), -1) for t in a.thresholds.split(",") if t]
        if a.oracle:
            configs.append(("oracle", 0.0, n_ref))
        for kind, thr, k in configs:
            t0 = time.perf_counter()
            labels = ahc(e, a.linkage, thr, k)
            labels = reassign_small(e, labels, dur, a.min_cluster_s, k)
            hyp = to_turns(wins, labels, speech)
            t1 = time.perf_counter()
            out = {"id": it["id"], "audio_s": round(len(x) / RATE, 1), "emb": Path(a.emb).name,
                   "win": a.win, "hop": a.hop, "linkage": a.linkage, "kind": kind, "threshold": thr,
                   "k": k, "min_cluster_s": a.min_cluster_s, "n_windows": len(wins),
                   "cluster_s": round(t1 - t0, 2), **timing}
            for collar in (0.25, 0.0):
                s = der.score(ref, hyp, uem, collar=collar)
                s.pop("mapping")
                out[f"c{collar}"] = {kk: (round(v, 4) if isinstance(v, float) else v) for kk, v in s.items()}
            print(json.dumps(out), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
