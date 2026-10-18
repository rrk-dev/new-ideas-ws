"""Extraction eval metrics (PRF-09, vv-benchmark-eval → "LLM extraction eval").

Dependency-free (stdlib only) so CI needs no pip installs:
- schema validity comes from the Dart validator (render_prompt.dart --generate);
- scalar fields: exact match after normalization, plus fuzzy (token-set ratio ≥ 0.8);
- list fields: precision / recall / F1 with fuzzy one-to-one greedy matching
  (token-set ratio ≥ 0.8 or Jaccard ≥ 0.6); sub-field accuracy on matched items
  (e.g. action-item owner);
- hallucination rate: extracted items with no supporting span in the transcript
  (< 50 % of their content words found, fuzzily, in the transcript).
"""
from __future__ import annotations

import difflib
import re

_NUM = {w: str(i) for i, w in enumerate(
    "zero one two three four five six seven eight nine ten eleven twelve thirteen fourteen "
    "fifteen sixteen seventeen eighteen nineteen twenty".split())}
_ORD = {w: str(i + 1) for i, w in enumerate(
    "first second third fourth fifth sixth seventh eighth ninth tenth eleventh twelfth "
    "thirteenth fourteenth fifteenth sixteenth seventeenth eighteenth nineteenth twentieth".split())}
_STOP = set("a an the and or of to for in on at by with is are be we i you it this that "
            "will should can do does our their its as from".split())

MATCH_TSR = 0.8
MATCH_JACCARD = 0.6
GROUNDED = 0.5


def norm(text) -> str:
    if text is None:
        return ""
    s = str(text).lower().replace("'s", "")
    s = re.sub(r"(\d),(\d{3})", r"\1\2", s)
    s = re.sub(r"[^a-z0-9]+", " ", s)
    words = []
    for w in s.split():
        w = re.sub(r"^(\d+)(st|nd|rd|th)$", r"\1", w)
        words.append(_NUM.get(w) or _ORD.get(w) or w)
    return " ".join(words)


def tokens(text) -> list[str]:
    return norm(text).split()


def _ratio(a: str, b: str) -> float:
    if not a and not b:
        return 1.0
    return difflib.SequenceMatcher(None, a, b).ratio()


def token_set_ratio(a, b) -> float:
    """fuzzywuzzy-style token-set ratio in [0, 1]."""
    ta, tb = set(tokens(a)), set(tokens(b))
    if not ta and not tb:
        return 1.0
    if not ta or not tb:
        return 0.0
    inter = " ".join(sorted(ta & tb))
    s2 = " ".join(filter(None, [inter, " ".join(sorted(ta - tb))]))
    s3 = " ".join(filter(None, [inter, " ".join(sorted(tb - ta))]))
    scores = [_ratio(s2, s3)]
    if inter:
        scores += [_ratio(inter, s2), _ratio(inter, s3)]
    return max(scores)


def jaccard(a, b) -> float:
    ta, tb = set(tokens(a)), set(tokens(b))
    if not ta and not tb:
        return 1.0
    return len(ta & tb) / len(ta | tb)


def similarity(a, b, kind: str = "text") -> float:
    """Match score in [0, 1]; ≥ threshold() counts as a match."""
    if kind == "name":
        na, nb = tokens(a), tokens(b)
        if not na or not nb:
            return 1.0 if na == nb else 0.0
        return 1.0 if na == nb or na[0] == nb[0] else 0.0
    if kind == "contact":
        da, db = re.sub(r"\D", "", str(a)), re.sub(r"\D", "", str(b))
        if len(da) >= 6 and da == db:
            return 1.0
        ca = re.sub(r"[^a-z0-9]", "", norm(a).replace(" at ", "").replace(" dot ", ""))
        cb = re.sub(r"[^a-z0-9]", "", norm(b).replace(" at ", "").replace(" dot ", ""))
        return 1.0 if ca == cb else _ratio(ca, cb)
    tsr = token_set_ratio(a, b)
    jac = jaccard(a, b)
    return tsr if tsr >= MATCH_TSR else (max(tsr, MATCH_TSR) if jac >= MATCH_JACCARD else tsr)


def is_match(a, b, kind: str = "text") -> bool:
    if a is None or b is None:
        return a is None and b is None
    return similarity(a, b, kind) >= MATCH_TSR


def item_text(item, key: str | None):
    if isinstance(item, dict):
        return item.get(key) if key else " ".join(str(v) for v in item.values() if isinstance(v, str))
    return item


def match_lists(expected: list, predicted: list, key: str | None, kind: str):
    """Greedy one-to-one matching by score; returns [(i_expected, j_predicted)]."""
    pairs = []
    for i, e in enumerate(expected):
        for j, p in enumerate(predicted):
            s = similarity(item_text(e, key) or "", item_text(p, key) or "", kind)
            if s >= MATCH_TSR:
                pairs.append((s, i, j))
    pairs.sort(key=lambda t: (-t[0], t[1], t[2]))
    used_e, used_p, out = set(), set(), []
    for _, i, j in pairs:
        if i not in used_e and j not in used_p:
            used_e.add(i)
            used_p.add(j)
            out.append((i, j))
    return out


def grounded(text, transcript_tokens: set[str]) -> bool:
    content = [t for t in tokens(text) if t not in _STOP and (len(t) > 2 or t.isdigit())]
    if not content:
        return True
    pool = list(transcript_tokens)
    hits = 0
    for t in content:
        if t in transcript_tokens or difflib.get_close_matches(t, pool, n=1, cutoff=0.8):
            hits += 1
    return hits / len(content) >= GROUNDED


def scalar_equal(e, p, kind: str) -> tuple[bool, bool]:
    """(exact, fuzzy) equality of a scalar field. Empty strings count as null
    (the app's render-context normalizer does the same)."""
    e = None if isinstance(e, str) and not e.strip() else e
    p = None if isinstance(p, str) and not p.strip() else p
    if e is None or p is None:
        both = e is None and p is None
        return both, both
    if kind == "serial":
        x = re.sub(r"[^A-Z0-9]", "", str(e).upper())
        y = re.sub(r"[^A-Z0-9]", "", str(p).upper())
        return x == y, x == y
    if kind == "period":
        if not isinstance(e, dict) or not isinstance(p, dict):
            return False, False
        ok = e.get("value") == p.get("value") and str(e.get("unit", "")).rstrip("s") == str(
            p.get("unit", "")).rstrip("s")
        return ok, ok
    exact = norm(e) == norm(p)
    return exact, exact or token_set_ratio(e, p) >= MATCH_TSR


def quote_norm(text) -> str:
    """Quote normalisation of the app's `verbatim_quotes` post-processor
    (post_processing.dart `normalizeForQuote`): lower case, typographic
    apostrophes folded, runs of non-letters/digits collapsed, space-wrapped."""
    s = str(text or "").lower().replace("\u2018", "'").replace("\u2019", "'").replace("\u02bc", "'")
    words = re.findall(r"[^\W_]+(?:'[^\W_]+)*", s)
    return f" {' '.join(words)} " if words else ""


def quote_stats(pred, transcript: str, cfg: dict) -> dict:
    """{field: (verbatim, total)} for the quote lists named in cfg["verbatim"]."""
    hay = quote_norm(re.sub(r"(?m)^\[\d{2}:\d{2}:\d{2}\]\s*", "", transcript))
    out = {}
    for field, text_key in (cfg.get("verbatim") or {}).items():
        items = pred.get(field) if isinstance(pred, dict) and isinstance(pred.get(field), list) else []
        texts = [i.get(text_key) for i in items if isinstance(i, dict) and isinstance(i.get(text_key), str)]
        ok = sum(1 for t in texts if (q := quote_norm(t)) and q in hay)
        out[field] = (ok, len(texts))
    return out


def score_case(expected: dict, predicted: dict | None, transcript: str, cfg: dict) -> dict:
    """Per-case metrics; `predicted` None = no valid output (counts as all-miss)."""
    pred = predicted if isinstance(predicted, dict) else {}
    ttoks = set(tokens(transcript))
    out = {"scalars": {}, "lists": {}, "prose": {}, "extracted": 0, "ungrounded": 0}
    for field, kind in cfg.get("scalars", {}).items():
        exact, fuzzy = scalar_equal(expected.get(field), pred.get(field), kind)
        out["scalars"][field] = {"exact": exact, "fuzzy": fuzzy}
        v = pred.get(field)
        if isinstance(v, str) and v.strip():
            out["extracted"] += 1
            if not grounded(v, ttoks):
                out["ungrounded"] += 1
    for field, spec in cfg.get("lists", {}).items():
        key, kind = spec.get("key"), spec.get("match", "text")
        exp = expected.get(field) or []
        got = pred.get(field) if isinstance(pred.get(field), list) else []
        pairs = match_lists(exp, got, key, kind)
        sub = {}
        for sf, sk in (spec.get("fields") or {}).items():
            ok = sum(1 for (i, j) in pairs
                     if scalar_equal(exp[i].get(sf), got[j].get(sf), "text")[1]
                     or (sk == "name" and is_match(exp[i].get(sf), got[j].get(sf), "name")))
            sub[sf] = {"correct": ok, "matched": len(pairs)}
        out["lists"][field] = {"tp": len(pairs), "expected": len(exp), "predicted": len(got), "fields": sub}
        for item in got:
            text = item_text(item, key)
            if isinstance(text, str) and text.strip():
                out["extracted"] += 1
                if not grounded(text, ttoks):
                    out["ungrounded"] += 1
    for field in cfg.get("prose", []):
        e, p = expected.get(field), pred.get(field)
        out["prose"][field] = token_set_ratio(e, p) if (e or p) else 1.0
    return out


def prf(tp: int, n_exp: int, n_pred: int) -> dict:
    p = tp / n_pred if n_pred else (1.0 if n_exp == 0 else 0.0)
    r = tp / n_exp if n_exp else (1.0 if n_pred == 0 else 0.0)
    f = 2 * p * r / (p + r) if p + r else 0.0
    return {"precision": p, "recall": r, "f1": f}


def aggregate(cases: list[dict], cfg: dict) -> dict:
    n = len(cases) or 1
    agg: dict = {"cases": len(cases), "schema_valid": sum(c["valid"] for c in cases) / n,
                 "scalars": {}, "lists": {}, "prose": {}}
    exact_all = fuzzy_all = total = 0
    for field in cfg.get("scalars", {}):
        ex = sum(c["score"]["scalars"][field]["exact"] for c in cases)
        fz = sum(c["score"]["scalars"][field]["fuzzy"] for c in cases)
        agg["scalars"][field] = {"exact": ex / n, "fuzzy": fz / n}
        exact_all += ex
        fuzzy_all += fz
        total += len(cases)
    if total:
        agg["scalars"]["accuracy"] = fuzzy_all / total
        agg["scalars"]["exact_accuracy"] = exact_all / total
    for field, spec in cfg.get("lists", {}).items():
        tp = sum(c["score"]["lists"][field]["tp"] for c in cases)
        ne = sum(c["score"]["lists"][field]["expected"] for c in cases)
        npred = sum(c["score"]["lists"][field]["predicted"] for c in cases)
        entry = prf(tp, ne, npred) | {"tp": tp, "expected": ne, "predicted": npred}
        for sf in (spec.get("fields") or {}):
            ok = sum(c["score"]["lists"][field]["fields"][sf]["correct"] for c in cases)
            entry[f"{sf}_accuracy"] = ok / tp if tp else None
        agg["lists"][field] = entry
    for field in cfg.get("prose", []):
        agg["prose"][field] = sum(c["score"]["prose"][field] for c in cases) / n
    extracted = sum(c["score"]["extracted"] for c in cases)
    agg["hallucination_rate"] = (sum(c["score"]["ungrounded"] for c in cases) / extracted) if extracted else 0.0
    return agg


def lookup(agg: dict, dotted: str):
    cur = agg
    for part in dotted.split("."):
        if not isinstance(cur, dict) or part not in cur:
            return None
        cur = cur[part]
    return cur


def gate_metrics(agg: dict) -> dict[str, float]:
    """Metrics compared against the baseline (higher is better)."""
    out = {"schema_valid": agg["schema_valid"]}
    for f, v in agg["lists"].items():
        out[f"lists.{f}.f1"] = v["f1"]
    if "accuracy" in agg["scalars"]:
        out["scalars.accuracy"] = agg["scalars"]["accuracy"]
    return out


def regressions(agg: dict, baseline: dict, max_drop: float = 0.02, min_valid: float = 0.99) -> list[str]:
    """A prompt/profile change must not reduce any F1/accuracy by > 2 points or
    schema validity below 99 % (or below the baseline when it is already lower)."""
    problems = []
    now, base = gate_metrics(agg), gate_metrics(baseline)
    for k, b in base.items():
        v = now.get(k)
        if v is None:
            continue
        if k == "schema_valid":
            floor = min(min_valid, b)
            if v + 1e-9 < floor:
                problems.append(f"{k} {v:.3f} < {floor:.3f}")
        elif v + 1e-9 < b - max_drop:
            problems.append(f"{k} {v:.3f} dropped > {max_drop:.2f} from baseline {b:.3f}")
    return problems
