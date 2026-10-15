"""WER with a fixed English normalizer (QA-02). Identical for every run.

Normalization (applied to reference and hypothesis alike):
  NFKC, lowercase, curly quotes → ', "$649" → "649 dollars", "%" → " percent",
  ordinals/cardinals in digits → words ("15th" → "fifteenth", "649" → "six
  hundred forty nine", "7:15" → "seven fifteen"), hyphens/punctuation →
  space, "and" between number words dropped, a few spelling variants
  unified (ok → okay, colour → color …). A lightweight stand-in for Whisper's
  EnglishTextNormalizer; dependency-free so it runs anywhere.
"""
from __future__ import annotations

import re
import unicodedata

_ONES = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
         "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen",
         "eighteen", "nineteen"]
_TENS = ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]
_ORD = {"one": "first", "two": "second", "three": "third", "five": "fifth", "eight": "eighth",
        "nine": "ninth", "twelve": "twelfth"}
_NUMBER_WORDS = set(_ONES) | set(_TENS[2:]) | {"hundred", "thousand", "million"}
_VARIANTS = {"ok": "okay", "colour": "color", "centre": "center", "litre": "liter",
             "litres": "liters", "metre": "meter", "organise": "organize", "favourite": "favorite",
             "programme": "program", "mr": "mister", "mrs": "missus", "dr": "doctor"}


def _words(n: int) -> str:
    if n < 20:
        return _ONES[n]
    if n < 100:
        return _TENS[n // 10] + ("" if n % 10 == 0 else " " + _ONES[n % 10])
    if n < 1000:
        return _ONES[n // 100] + " hundred" + ("" if n % 100 == 0 else " " + _words(n % 100))
    for size, name in ((10 ** 6, "million"), (1000, "thousand")):
        if n >= size:
            rest = n % size
            return _words(n // size) + f" {name}" + ("" if rest == 0 else " " + _words(rest))
    return str(n)


def _ordinal(n: int) -> str:
    w = _words(n).split()
    last = w[-1]
    w[-1] = _ORD.get(last, last[:-1] + "ieth" if last.endswith("y") else last + "th")
    return " ".join(w)


def _digits(m: re.Match) -> str:
    s = m.group(0)
    if re.fullmatch(r"\d+(st|nd|rd|th)", s):
        return _ordinal(int(re.sub(r"\D", "", s)))
    if ":" in s:
        h, mi = s.split(":")
        return _words(int(h)) + ("" if int(mi) == 0 else " " + _words(int(mi)))
    if re.fullmatch(r"(0?[1-9]|1[0-2])\.[0-5]\d", s):
        # "7.15" is a clock time in British/Australian Whisper output.
        h, mi = s.split(".")
        return _words(int(h)) + ("" if int(mi) == 0 else " " + _words(int(mi)))
    if "." in s:
        a, b = s.split(".", 1)
        return _words(int(a)) + " point " + " ".join(_ONES[int(c)] for c in b)
    n = int(s.replace(",", ""))
    return _words(n) if n < 10 ** 9 else s


def normalize(text: str) -> list[str]:
    t = unicodedata.normalize("NFKC", text).lower()
    t = t.replace("’", "'").replace("‘", "'")
    t = re.sub(r"\$\s?(\d[\d,]*(?:\.\d+)?)", r"\1 dollars", t)
    t = t.replace("%", " percent")
    t = re.sub(r"\d[\d,]*(?::\d+|\.\d+|st|nd|rd|th)?", _digits, t)
    t = re.sub(r"(?<!\w)'|'(?!\w)", " ", t)
    t = re.sub(r"[^\w\s']|_", " ", t)
    words = [_VARIANTS.get(w, w) for w in t.split()]
    out = []
    for i, w in enumerate(words):
        if (w == "and" and 0 < i < len(words) - 1 and words[i - 1] in _NUMBER_WORDS
                and words[i + 1] in _NUMBER_WORDS):
            continue
        out.append(w)
    return out


def edit_counts(ref: list[str], hyp: list[str]) -> tuple[int, int, int]:
    """(substitutions, deletions, insertions) of a minimal Levenshtein alignment."""
    n, m = len(ref), len(hyp)
    prev = [(j, 0, 0, j) for j in range(m + 1)]
    for i in range(1, n + 1):
        cur = [(i, 0, i, 0)] + [None] * m
        for j in range(1, m + 1):
            if ref[i - 1] == hyp[j - 1]:
                cur[j] = prev[j - 1]
                continue
            s, d, ins = prev[j - 1], prev[j], cur[j - 1]
            cur[j] = min((s[0] + 1, s[1] + 1, s[2], s[3]),
                         (d[0] + 1, d[1], d[2] + 1, d[3]),
                         (ins[0] + 1, ins[1], ins[2], ins[3] + 1))
        prev = cur
    _, s, d, ins = prev[m]
    return s, d, ins


def score(ref: str, hyp: str) -> dict:
    r, h = normalize(ref), normalize(hyp)
    s, d, i = edit_counts(r, h)
    return {"n": len(r), "sub": s, "del": d, "ins": i}


def wer(counts: list[dict]) -> float:
    n = sum(c["n"] for c in counts)
    e = sum(c["sub"] + c["del"] + c["ins"] for c in counts)
    return e / n if n else 0.0
