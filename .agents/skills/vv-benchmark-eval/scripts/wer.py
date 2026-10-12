#!/usr/bin/env python3
"""Dependency-free word error rate for quick STT checks.

Usage:
  wer.py REF.txt HYP.txt            # one utterance per file
  wer.py --pairs pairs.tsv          # lines: <ref>\t<hyp>   (aggregate WER)

Normalization: lowercase, unicode NFKC, remove punctuation except intra-word apostrophes,
collapse whitespace. Keep identical across runs; it is not Whisper's full English normalizer.
"""
from __future__ import annotations

import argparse
import re
import sys
import unicodedata


def normalize(text: str) -> list[str]:
    text = unicodedata.normalize("NFKC", text).lower()
    text = text.replace("\u2019", "'").replace("\u2018", "'").replace("\u02bc", "'")
    text = re.sub(r"(?<!\w)'|'(?!\w)", " ", text)
    text = re.sub(r"[^\w\s']|_", " ", text)
    return text.split()


def edit_counts(ref: list[str], hyp: list[str]) -> tuple[int, int, int]:
    """Return (substitutions, deletions, insertions) via Levenshtein alignment."""
    n, m = len(ref), len(hyp)
    # dp[j] = (cost, S, D, I) for ref[:i], hyp[:j]
    prev = [(j, 0, 0, j) for j in range(m + 1)]
    for i in range(1, n + 1):
        cur = [(i, 0, i, 0)] + [None] * m
        for j in range(1, m + 1):
            if ref[i - 1] == hyp[j - 1]:
                cur[j] = prev[j - 1]
                continue
            sub = prev[j - 1]
            dele = prev[j]
            ins = cur[j - 1]
            best = min(
                (sub[0] + 1, sub[1] + 1, sub[2], sub[3]),
                (dele[0] + 1, dele[1], dele[2] + 1, dele[3]),
                (ins[0] + 1, ins[1], ins[2], ins[3] + 1),
            )
            cur[j] = best
        prev = cur
    _, s, d, ins = prev[m]
    return s, d, ins


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("ref", nargs="?")
    ap.add_argument("hyp", nargs="?")
    ap.add_argument("--pairs")
    a = ap.parse_args()
    pairs: list[tuple[str, str]] = []
    if a.pairs:
        with open(a.pairs, encoding="utf-8") as f:
            for line in f:
                if line.strip():
                    r, _, h = line.rstrip("\n").partition("\t")
                    pairs.append((r, h))
    elif a.ref and a.hyp:
        with open(a.ref, encoding="utf-8") as fr, open(a.hyp, encoding="utf-8") as fh:
            pairs.append((fr.read(), fh.read()))
    else:
        ap.error("give REF HYP or --pairs")
    S = D = I = N = 0
    for r, h in pairs:
        rw, hw = normalize(r), normalize(h)
        s, d, i = edit_counts(rw, hw)
        S, D, I, N = S + s, D + d, I + i, N + len(rw)
    wer = (S + D + I) / N if N else (float("inf") if (S + D + I) else 0.0)
    print(f"WER={wer:.4f} N={N} S={S} D={D} I={I} utterances={len(pairs)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
