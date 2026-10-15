#!/usr/bin/env python3
"""Dependency-free diarization error rate (DER), NIST md-eval conventions.

    der.py REF.rttm HYP.rttm [--uem FILE.uem] [--collar 0.25] [--skip-overlap]

* Scored region: the UEM (or the extent of the reference when absent), minus
  a no-score zone of +/- ``collar`` seconds around every reference segment
  boundary (md-eval ``-c 0.25`` = 0.25 s on each side; note pyannote.metrics'
  ``collar`` is the *total* width, i.e. ``collar=0.5`` there).
* Overlapped speech is scored unless ``--skip-overlap``.
* Speakers are mapped one-to-one (reference -> hypothesis) to maximise the
  matched time (Hungarian algorithm), then on a 10 ms frame grid:
  ``miss = max(0, |R| - |H|)``, ``false alarm = max(0, |H| - |R|)``,
  ``confusion = min(|R|, |H|) - correct``; DER = (miss + FA + conf) / sum |R|.

Dev tooling for STT-05 (vv-benchmark-eval); never shipped in the app.
"""
from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from pathlib import Path

FRAME = 0.01  # s


@dataclass(frozen=True)
class Turn:
    start: float
    end: float
    speaker: str


def read_rttm(path: Path, file_id: str | None = None) -> list[Turn]:
    """``SPEAKER <file> <chan> <start> <dur> <NA> <NA> <spk> ...`` lines."""
    turns = []
    for line in Path(path).read_text().splitlines():
        parts = line.split()
        if len(parts) < 8 or parts[0] != "SPEAKER":
            continue
        if file_id is not None and parts[1] != file_id:
            continue
        start, dur = float(parts[3]), float(parts[4])
        if dur > 0:
            turns.append(Turn(start, start + dur, parts[7]))
    return turns


def read_uem(path: Path) -> list[tuple[float, float]]:
    """``<file> <chan> <start> <end>`` lines."""
    out = []
    for line in Path(path).read_text().splitlines():
        parts = line.split()
        if len(parts) >= 4:
            out.append((float(parts[2]), float(parts[3])))
    return out


def write_rttm(path: Path, file_id: str, turns: list[Turn]) -> None:
    lines = [
        f"SPEAKER {file_id} 1 {t.start:.3f} {t.end - t.start:.3f} <NA> <NA> {t.speaker} <NA> <NA>"
        for t in turns
        if t.end > t.start
    ]
    Path(path).write_text("\n".join(lines) + ("\n" if lines else ""))


def hungarian_max(weight: list[list[float]]) -> list[tuple[int, int]]:
    """Maximum-weight one-to-one assignment of rows to columns.

    Square-pads the matrix and runs the O(n^3) Kuhn-Munkres algorithm on the
    negated costs. Returns (row, col) pairs of real (non-padding) cells.
    """
    rows = len(weight)
    cols = len(weight[0]) if rows else 0
    n = max(rows, cols)
    if n == 0:
        return []
    big = max((w for r in weight for w in r), default=0.0)
    cost = [[(big - weight[i][j]) if i < rows and j < cols else big for j in range(n)] for i in range(n)]
    inf = float("inf")
    u = [0.0] * (n + 1)
    v = [0.0] * (n + 1)
    p = [0] * (n + 1)
    way = [0] * (n + 1)
    for i in range(1, n + 1):
        p[0] = i
        j0 = 0
        minv = [inf] * (n + 1)
        used = [False] * (n + 1)
        while True:
            used[j0] = True
            i0, delta, j1 = p[j0], inf, 0
            for j in range(1, n + 1):
                if not used[j]:
                    cur = cost[i0 - 1][j - 1] - u[i0] - v[j]
                    if cur < minv[j]:
                        minv[j], way[j] = cur, j0
                    if minv[j] < delta:
                        delta, j1 = minv[j], j
            for j in range(n + 1):
                if used[j]:
                    u[p[j]] += delta
                    v[j] -= delta
                else:
                    minv[j] -= delta
            j0 = j1
            if p[j0] == 0:
                break
        while True:
            j1 = way[j0]
            p[j0] = p[j1]
            j0 = j1
            if j0 == 0:
                break
    pairs = []
    for j in range(1, n + 1):
        i = p[j] - 1
        if i < rows and j - 1 < cols:
            pairs.append((i, j - 1))
    return pairs


def _frames(turns: list[Turn], n: int) -> list[set[str]]:
    out: list[set[str]] = [set() for _ in range(n)]
    for t in turns:
        a = max(0, int(round(t.start / FRAME)))
        b = min(n, int(round(t.end / FRAME)))
        for k in range(a, b):
            out[k].add(t.speaker)
    return out


def score(
    ref: list[Turn],
    hyp: list[Turn],
    uem: list[tuple[float, float]] | None = None,
    collar: float = 0.25,
    skip_overlap: bool = False,
) -> dict:
    """DER components in seconds plus ``der`` (fraction) and the mapping."""
    if uem is None:
        uem = [(min((t.start for t in ref), default=0.0), max((t.end for t in ref), default=0.0))]
    end = max([e for _, e in uem] + [t.end for t in ref] + [t.end for t in hyp] + [0.0])
    n = int(round(end / FRAME)) + 1
    scored = [False] * n
    for s, e in uem:
        for k in range(max(0, int(round(s / FRAME))), min(n, int(round(e / FRAME)))):
            scored[k] = True
    if collar > 0:
        c = int(round(collar / FRAME))
        for t in ref:
            for edge in (t.start, t.end):
                k = int(round(edge / FRAME))
                for j in range(max(0, k - c), min(n, k + c)):
                    scored[j] = False
    rf, hf = _frames(ref, n), _frames(hyp, n)
    if skip_overlap:
        for k in range(n):
            if len(rf[k]) > 1:
                scored[k] = False
    ref_ids = sorted({t.speaker for t in ref})
    hyp_ids = sorted({t.speaker for t in hyp})
    ri = {s: i for i, s in enumerate(ref_ids)}
    hi = {s: i for i, s in enumerate(hyp_ids)}
    co = [[0.0] * len(hyp_ids) for _ in ref_ids]
    for k in range(n):
        if scored[k]:
            for r in rf[k]:
                for h in hf[k]:
                    co[ri[r]][hi[h]] += FRAME
    mapping = {ref_ids[i]: hyp_ids[j] for i, j in hungarian_max(co) if co[i][j] > 0} if co and co[0] else {}
    total = miss = fa = conf = 0.0
    for k in range(n):
        if not scored[k]:
            continue
        r, h = rf[k], hf[k]
        nr, nh = len(r), len(h)
        correct = sum(1 for s in r if mapping.get(s) in h)
        total += nr * FRAME
        miss += max(0, nr - nh) * FRAME
        fa += max(0, nh - nr) * FRAME
        conf += (min(nr, nh) - correct) * FRAME
    der = (miss + fa + conf) / total if total > 0 else 0.0
    return {
        "der": der,
        "scored_speech_s": round(total, 2),
        "miss_s": round(miss, 2),
        "false_alarm_s": round(fa, 2),
        "confusion_s": round(conf, 2),
        "ref_speakers": len(ref_ids),
        "hyp_speakers": len(hyp_ids),
        "mapping": mapping,
    }


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("ref", type=Path)
    ap.add_argument("hyp", type=Path)
    ap.add_argument("--uem", type=Path)
    ap.add_argument("--collar", type=float, default=0.25)
    ap.add_argument("--skip-overlap", action="store_true")
    a = ap.parse_args(argv)
    res = score(
        read_rttm(a.ref),
        read_rttm(a.hyp),
        read_uem(a.uem) if a.uem else None,
        collar=a.collar,
        skip_overlap=a.skip_overlap,
    )
    print(json.dumps(res, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
