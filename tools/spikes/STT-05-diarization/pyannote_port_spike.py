#!/usr/bin/env python3
"""STT-05 spike: sherpa-onnx's pyannote pipeline with pyannote-3.1 clustering.

sherpa-onnx's OfflineSpeakerDiarization (segmentation-3.0 sliding windows ->
per-(chunk, local speaker) embeddings of the non-overlapped samples ->
FastClustering = *complete-linkage* AHC -> top-k reconstruction) scored
46-66 % DER on AMI in this spike. pyannote/speaker-diarization-3.1 uses the
same segmentation model but clusters with **centroid-linkage AHC** on
L2-normalised embeddings (threshold 0.7045654963945799 euclidean),
reassigns clusters with < min_cluster_size members to the nearest large
cluster and finally assigns every embedding to its nearest centroid. This
port reproduces sherpa's segmentation / embedding / reconstruction step for
step (offline-speaker-diarization-pyannote-impl.h @ v1.13.8) and swaps the
clustering, to measure what the bridge should implement.

Segmentation runs through onnxruntime (python), embeddings through
sherpa-onnx's SpeakerEmbeddingExtractor. Per (item, shift, embedding model)
the segmentation labels and embeddings are cached in --cache (scratch only:
embeddings are voiceprints of the AMI participants; never commit them).

Throw-away spike code referenced by docs/adr/ADR-STT-05-diarization.md.
"""
from __future__ import annotations

import argparse
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
WIN = 160000          # model meta window_size
RF_SHIFT = 270        # receptive_field_shift
RF_SIZE = 991         # receptive_field_size
N_LOCAL = 3


def read_wav(path: str) -> np.ndarray:
    with wave.open(path, "rb") as w:
        pcm = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2")
    return pcm.astype(np.float32) / 32768.0


POWERSET = np.array([[0, 0, 0], [1, 0, 0], [0, 1, 0], [0, 0, 1], [1, 1, 0], [1, 0, 1], [0, 1, 1]], dtype=np.int32)


def cpu() -> float:
    r = resource.getrusage(resource.RUSAGE_SELF)
    return r.ru_utime + r.ru_stime


def segment(sess, x: np.ndarray, shift: int) -> list[np.ndarray]:
    """Per chunk: (frames, 3) 0/1 labels (sherpa RunSpeakerSegmentationModel +
    ToMultiLabel)."""
    n = len(x)
    chunks = []
    if n <= WIN:
        buf = np.zeros(WIN, np.float32)
        buf[:n] = x
        chunks.append(buf)
    else:
        num = (n - WIN) // shift + 1
        for i in range(num):
            chunks.append(x[i * shift:i * shift + WIN])
        if (n - WIN) % shift > 0:
            buf = np.zeros(WIN, np.float32)
            rest = x[num * shift:]
            buf[:len(rest)] = rest
            chunks.append(buf)
    out = []
    for c in chunks:
        y = sess.run(None, {"x": c.reshape(1, 1, WIN)})[0][0]
        out.append(POWERSET[np.argmax(y, axis=1)])
    return out


def chunk_speaker_samples(labels: list[np.ndarray], shift: int):
    """sherpa GetChunkSpeakerSampleIndexes: clean (non-overlapped) runs of
    each local speaker with >= 10 frames."""
    pairs, samples = [], []
    for ci, lab in enumerate(labels):
        clean = lab * (lab.sum(1, keepdims=True) < 2)
        nf = lab.shape[0]
        off = ci * shift
        for s in range(N_LOCAL):
            d = clean[:, s]
            if d.sum() < 10:
                continue
            runs, active, st = [], False, 0
            for k in range(nf):
                if d[k]:
                    if not active:
                        active, st = True, k
                elif active:
                    active = False
                    runs.append((int(st / nf * WIN) + off, int(k / nf * WIN) + off))
            if active:
                runs.append((int(st / nf * WIN) + off, int((nf - 1) / nf * WIN) + off))
            pairs.append((ci, s))
            samples.append(runs)
    return pairs, samples


def embed(extractor, x: np.ndarray, samples) -> np.ndarray:
    out = []
    for runs in samples:
        st = extractor.create_stream()
        for a, b in runs:
            b = min(b, len(x))
            if b > a:
                st.accept_waveform(RATE, x[a:b])
        st.input_finished()
        out.append(np.array(extractor.compute(st), np.float32))
    return np.stack(out) if out else np.zeros((0, 1), np.float32)


# ------------------------------------------------------------- clustering

def _centroid_ahc(e: np.ndarray):
    """Centroid-linkage AHC (euclidean on unit vectors). Returns the merge
    list [(a, b, dist, new_id)] like scipy's linkage (O(n^2) memory)."""
    n = len(e)
    size = {i: 1 for i in range(n)}
    X = e.astype(np.float64)
    sq = (X * X).sum(1)
    D = np.sqrt(np.maximum(0, sq[:, None] + sq[None, :] - 2 * X @ X.T))
    np.fill_diagonal(D, np.inf)
    alive = np.ones(n, bool)
    row_id = list(range(n))  # matrix row -> cluster id
    merges = []
    next_id = n
    C = X.copy()
    for _ in range(n - 1):
        idx = np.argmin(D)
        i, j = divmod(idx, n)
        dist = D[i, j]
        if not np.isfinite(dist):
            break
        si, sj = size[row_id[i]], size[row_id[j]]
        c = (C[i] * si + C[j] * sj) / (si + sj)
        merges.append((row_id[i], row_id[j], dist, next_id))
        size[next_id] = si + sj
        row_id[i] = next_id
        next_id += 1
        C[i] = c
        alive[j] = False
        D[j, :] = np.inf
        D[:, j] = np.inf
        newd = np.sqrt(np.maximum(0, ((C - c) ** 2).sum(1)))
        newd[~alive] = np.inf
        newd[i] = np.inf
        D[i, :] = newd
        D[:, i] = newd
    return merges


def _cut(merges, n, threshold=None, k=None):
    parent = list(range(n + len(merges)))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    clusters = n
    for a, b, dist, new in merges:
        if threshold is not None and dist > threshold:
            break
        if k is not None and clusters <= k:
            break
        parent[find(a)] = new
        parent[find(b)] = new
        clusters -= 1
    roots = [find(i) for i in range(n)]
    _, lab = np.unique(roots, return_inverse=True)
    return lab


def pyannote_cluster(e: np.ndarray, threshold: float, min_cluster_size: int, k: int = -1,
                     method: str = "centroid") -> np.ndarray:
    n = len(e)
    if n <= 1:
        return np.zeros(n, int)
    en = e / (np.linalg.norm(e, axis=1, keepdims=True) + 1e-12)
    mcs = min(min_cluster_size, max(1, round(0.1 * n)))
    merges = _centroid_ahc(en)
    lab = _cut(merges, n, threshold=threshold)
    if k > 0:
        # pyannote: pick the cut with exactly k large clusters (search down the dendrogram)
        best = None
        for kk in range(k, min(n, k + 40) + 1):
            l2 = _cut(merges, n, k=kk)
            u, cnt = np.unique(l2, return_counts=True)
            if (cnt >= mcs).sum() >= k:
                best = l2
                break
        lab = best if best is not None else _cut(merges, n, k=k)
    u, cnt = np.unique(lab, return_counts=True)
    large = u[cnt >= mcs]
    if k > 0 and len(large) > k:
        large = u[np.argsort(-cnt)[:k]]
    if len(large) == 0:
        return np.zeros(n, int)
    # final assignment of every embedding to the nearest large centroid (cosine)
    cents = np.stack([en[lab == c].mean(0) for c in large])
    cents /= np.linalg.norm(cents, axis=1, keepdims=True) + 1e-12
    out = np.argmax(en @ cents.T, axis=1)
    return out


# ------------------------------------------------------- reconstruction

def reconstruct(labels: list[np.ndarray], pairs, clusters: np.ndarray, shift: int, n_samples: int,
                min_on: float = 0.3, min_off: float = 0.5) -> list[der.Turn]:
    num_chunks = len(labels)
    nf_chunk = labels[0].shape[0]
    num_frames = (WIN + (num_chunks - 1) * shift) // RF_SHIFT + 1
    k = int(clusters.max()) + 1 if len(clusters) else 1
    # speakers per frame (avg of local counts, rounded)
    count = np.zeros(num_frames + nf_chunk)
    weight = np.zeros(num_frames + nf_chunk)
    cl = np.zeros((num_frames + nf_chunk, k))
    m = {p: c for p, c in zip(pairs, clusters)}
    for ci, lab in enumerate(labels):
        st = int(ci * shift / RF_SHIFT + 0.5)
        count[st:st + nf_chunk] += lab.sum(1)
        weight[st:st + nf_chunk] += 1
        tmp = np.zeros((nf_chunk, k))
        for s in range(N_LOCAL):
            c = m.get((ci, s))
            if c is not None:
                tmp[:, c] = np.maximum(tmp[:, c], lab[:, s])
        cl[st:st + nf_chunk] += tmp
    spf = ((count / (weight + 1e-12)) + 0.5).astype(int)[:num_frames]
    cl = cl[:num_frames]
    has_last = ((n_samples - WIN) % shift) > 0 if n_samples > WIN else False
    if has_last:
        last = min(n_samples // RF_SHIFT, num_frames - 1)
        cl = cl[:last + 1]
        spf = spf[:last + 1]
    final = np.zeros_like(cl, dtype=int)
    for i in range(len(cl)):
        kk = min(spf[i], k)
        if kk > 0:
            top = np.argsort(-cl[i], kind="stable")[:kk]
            final[i, top] = 1
    scale, off = RF_SHIFT / RATE, 0.5 * RF_SIZE / RATE
    turns = []
    for s in range(k):
        segs, active, st = [], bool(final[0, s]), 0
        for f in range(1, len(final)):
            if active and not final[f, s]:
                segs.append([st * scale + off, f * scale + off])
                active = False
            elif not active and final[f, s]:
                active, st = True, f
        if active:
            segs.append([st * scale + off, (len(final) - 1) * scale + off])
        merged = []
        for a, b in segs:
            if merged and a - merged[-1][1] < min_off:
                merged[-1][1] = b
            else:
                merged.append([a, b])
        turns += [der.Turn(a, b, f"S{s}") for a, b in merged if b - a > min_on]
    return turns


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--items", required=True, type=Path)
    ap.add_argument("--seg", required=True)
    ap.add_argument("--emb", required=True)
    ap.add_argument("--cache", required=True, type=Path)
    ap.add_argument("--shift", type=float, default=0.1)
    ap.add_argument("--threads", type=int, default=4)
    ap.add_argument("--thresholds", default="0.7045654963945799")
    ap.add_argument("--min-cluster-size", type=int, default=12)
    ap.add_argument("--oracle", action="store_true")
    a = ap.parse_args()
    import onnxruntime as ort
    import sherpa_onnx
    so = ort.SessionOptions()
    so.intra_op_num_threads = a.threads
    so.inter_op_num_threads = 1
    sess = extractor = None
    shift = int(a.shift * WIN)
    for it in json.loads(a.items.read_text()):
        ref = der.read_rttm(Path(it["rttm"]))
        uem = der.read_uem(Path(it["uem"])) if it.get("uem") else None
        n_ref = len({t.speaker for t in ref})
        x = read_wav(it["wav"])
        cache = a.cache / f"py-{it['id']}-{Path(a.emb).stem}-s{a.shift}.npz"
        if cache.exists():
            z = np.load(cache, allow_pickle=True)
            labels = list(z["labels"])
            pairs = [tuple(p) for p in z["pairs"]]
            e = z["emb"]
            timing = json.loads(str(z["timing"]))
        else:
            if sess is None:
                sess = ort.InferenceSession(a.seg, so)
                extractor = sherpa_onnx.SpeakerEmbeddingExtractor(
                    sherpa_onnx.SpeakerEmbeddingExtractorConfig(model=a.emb, num_threads=a.threads))
            t0, c0 = time.perf_counter(), cpu()
            labels = segment(sess, x, shift)
            t1, c1 = time.perf_counter(), cpu()
            pairs, samples = chunk_speaker_samples(labels, shift)
            e = embed(extractor, x, samples)
            t2, c2 = time.perf_counter(), cpu()
            timing = {"seg_s": round(t1 - t0, 2), "emb_s": round(t2 - t1, 2),
                      "seg_cpu_s": round(c1 - c0, 2), "emb_cpu_s": round(c2 - c1, 2),
                      "chunks": len(labels), "embeddings": len(pairs)}
            a.cache.mkdir(parents=True, exist_ok=True)
            np.savez(cache, labels=np.stack(labels), pairs=np.array(pairs), emb=e, timing=json.dumps(timing))
        configs = [(float(t), -1) for t in a.thresholds.split(",") if t]
        if a.oracle:
            configs.append((float(a.thresholds.split(",")[0]), n_ref))
        for thr, k in configs:
            t0 = time.perf_counter()
            clusters = pyannote_cluster(e, thr, a.min_cluster_size, k)
            hyp = reconstruct(labels, pairs, clusters, shift, len(x))
            t1 = time.perf_counter()
            out = {"id": it["id"], "audio_s": round(len(x) / RATE, 1), "emb": Path(a.emb).name,
                   "shift": a.shift, "threshold": thr, "k": k, "mcs": a.min_cluster_size,
                   "cluster_s": round(t1 - t0, 2), **timing}
            for collar in (0.25, 0.0):
                s = der.score(ref, hyp, uem, collar=collar)
                s.pop("mapping")
                out[f"c{collar}"] = {kk: (round(v, 4) if isinstance(v, float) else v) for kk, v in s.items()}
            print(json.dumps(out), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
