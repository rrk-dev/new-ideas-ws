#!/usr/bin/env python3
"""Retrieval eval for ASK-02 (ADR-ASK-02): FTS5 BM25 over the app's `search_index`.

Re-runnable, stdlib only, offline, no model needed:
  python3 tools/bench/ask/retrieval_eval.py [--out tools/bench/results/2026-10-17-ask02-retrieval]

Builds an in-memory SQLite database with the exact `search_index` DDL read from
app/lib/core/db/tables/search.drift, indexes the fictional PRF-09 transcripts listed in
library.json (rows of kind title / transcript / extraction, like the app's triggers),
runs every question in questions.json through the deterministic query builder, and reports
the metrics pre-registered in docs/adr/ADR-ASK-02-retrieval.md. Options B/C (embeddings) and
LLM query rewriting are NOT measured here (they need a model this task may not add).
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import resource
import sqlite3
import statistics
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
EVAL = ROOT / "tools" / "bench" / "eval"
DRIFT = ROOT / "app" / "lib" / "core" / "db" / "tables" / "search.drift"

STOP = set(
    """a an the of in on at to for from by with about and or but if then than so as is are was were be been
being am do does did done have has had having i me my mine we our us you your he she it its his her their
they them this that these those there here what which who whom whose when where why how can could would
should will shall may might must say said says tell told any some all each every not no yes also just
very much many long came out up down over into again""".split()
)
DATE_WORDS = set(
    """yesterday today tomorrow last next this week weeks month months day days ago monday tuesday wednesday
thursday friday saturday sunday january february march april may june july august september october
november december""".split()
)
MONTHS = {m: i + 1 for i, m in enumerate(
    "january february march april may june july august september october november december".split())}
WEEKDAYS = {d: i for i, d in enumerate(
    "monday tuesday wednesday thursday friday saturday sunday".split())}
K_MAX = 10
SUPPORT_TERM_FRACTION = 0.5


def stem(tok: str) -> str:
    for suf in ("ing", "ed", "es", "s"):
        if tok.endswith(suf) and len(tok) - len(suf) >= 3:
            return tok[: -len(suf)]
    return tok


def tokens(text: str) -> list[str]:
    return re.findall(r"[a-z0-9]+", text.lower().replace("'s", ""))


def content_stems(question: str) -> list[str]:
    seen: list[str] = []
    for t in tokens(question):
        if len(t) < 2 or t in STOP or t in DATE_WORDS:
            continue
        s = stem(t)
        if s not in seen:
            seen.append(s)
    return seen


def date_range(question: str, today: dt.date):
    """Deterministic date filter (inclusive). Mirrors what ASK-03 parses in Dart."""
    q = question.lower().replace("'s", "")
    if "yesterday" in q:
        d = today - dt.timedelta(days=1)
        return d, d
    monday = today - dt.timedelta(days=today.weekday())
    if "last week" in q:
        return monday - dt.timedelta(days=7), monday - dt.timedelta(days=1)
    if "this week" in q:
        return monday, today
    m = re.search(r"\b(?:last|on) (monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b", q)
    if m:
        delta = (today.weekday() - WEEKDAYS[m.group(1)]) % 7 or 7
        d = today - dt.timedelta(days=delta)
        return d, d
    m = re.search(r"\bin (" + "|".join(MONTHS) + r")\b", q)
    if m:
        mo = MONTHS[m.group(1)]
        start = dt.date(today.year, mo, 1)
        end = (dt.date(today.year + (mo == 12), mo % 12 + 1, 1)) - dt.timedelta(days=1)
        return start, end
    return None


def load_ddl() -> str:
    m = re.search(r"CREATE VIRTUAL TABLE search_index USING fts5\(.*?\);", DRIFT.read_text(), re.S)
    if not m:
        sys.exit("search_index DDL not found in search.drift")
    return m.group(0)


def strings_of(node) -> list[str]:
    if isinstance(node, str):
        return [node]
    if isinstance(node, dict):
        return [s for v in node.values() for s in strings_of(v)]
    if isinstance(node, list):
        return [s for v in node for s in strings_of(v)]
    return []


def read_recording(rec: dict) -> dict:
    d = EVAL / rec["profile"] / rec["id"]
    segs = []
    for line in (d / "transcript.txt").read_text().splitlines():
        m = re.match(r"\[(\d\d:\d\d:\d\d)\]\s*(.*)", line)
        if m:
            segs.append((m.group(1), m.group(2)))
    expected = json.loads((d / "expected.json").read_text())
    title = expected.get("title") or " ".join(
        str(expected.get(k, "")) for k in ("brand", "product", "model")).strip()
    return {"segs": segs, "title": title, "extraction": " ".join(strings_of(expected))}


def build_db(library: dict, copies: int = 1):
    db = sqlite3.connect(":memory:")
    db.execute(load_ddl())
    db.execute("CREATE TABLE recordings (id TEXT PRIMARY KEY, date TEXT)")
    base = [(r, read_recording(r)) for r in library["recordings"]]
    seg_id = 0
    rows, recs = [], []
    for c in range(copies):
        for r, data in base:
            rid = r["id"] if c == 0 else f"{r['id']}~{c}"
            recs.append((rid, r["date"]))
            rows.append((rid, "title", data["title"], None))
            for t, text in data["segs"]:
                seg_id += 1
                rows.append((rid, "transcript", text, -seg_id))
            rows.append((rid, "extraction", data["extraction"], None))
    db.executemany("INSERT INTO recordings VALUES (?,?)", recs)
    for rid, kind, body, rowid in rows:
        if rowid is None:
            db.execute("INSERT INTO search_index (recording_id, kind, body) VALUES (?,?,?)", (rid, kind, body))
        else:
            db.execute("INSERT INTO search_index (rowid, recording_id, kind, body) VALUES (?,?,?,?)",
                       (rowid, rid, kind, body))
    db.commit()
    return db


def segment_time(base: dict, rid: str, body: str):
    """Timestamp of a transcript passage (body is unique enough within a recording)."""
    for t, text in base[rid.split("~")[0]]["segs"]:
        if text == body:
            return t
    return None


def search(db, stems: list[str], rng, k: int = K_MAX):
    if not stems:
        return []
    match = " OR ".join(f'"{s}"*' for s in stems)
    sql = ("SELECT s.recording_id, s.kind, s.body FROM search_index AS s "
           "JOIN recordings AS r ON r.id = s.recording_id WHERE search_index MATCH ?")
    args = [match]
    if rng:
        sql += " AND r.date BETWEEN ? AND ?"
        args += [rng[0].isoformat(), rng[1].isoformat()]
    sql += " ORDER BY bm25(search_index) LIMIT ?"
    args.append(k)
    return db.execute(sql, args).fetchall()


def support_fraction(stems, passages) -> float:
    if not stems:
        return 0.0
    best = 0.0
    for _, _, body in passages[:5]:
        toks = tokens(body)
        hit = sum(1 for s in stems if any(t.startswith(s) for t in toks))
        best = max(best, hit / len(stems))
    return best


def evaluate(db, library, questions, base):
    today = dt.date.fromisoformat(library["today"])
    per = []
    for q in questions:
        stems = content_stems(q["q"])
        rng = date_range(q["q"], today)
        hits = search(db, stems, rng)
        passages = [(rid, kind, body, segment_time(base, rid, body) if kind == "transcript" else None)
                    for rid, kind, body in hits]
        sup = support_fraction(stems, hits)
        answers = sup >= SUPPORT_TERM_FRACTION
        rec = {"id": q["id"], "type": q["type"], "q": q["q"], "stems": stems,
               "date_range": [d.isoformat() for d in rng] if rng else None,
               "support_fraction": round(sup, 3), "answers": answers, "top": [
                   {"rec": p[0], "kind": p[1], "t": p[3]} for p in passages[:5]]}
        if q["gold"]:
            def got(k, item):
                return any(p[0] == item["rec"] and p[1] == "transcript" and p[3] in item["t"]
                           for p in passages[:k])

            def got_rec(k, item):
                return any(p[0] == item["rec"] for p in passages[:k])
            for k in (1, 3, 5, 10):
                rec[f"seg_recall@{k}"] = sum(got(k, g) for g in q["gold"]) / len(q["gold"])
            rec["rec_recall@5"] = sum(got_rec(5, g) for g in q["gold"]) / len(q["gold"])
            rr = 0.0
            for rank, p in enumerate(passages, 1):
                if any(p[0] == g["rec"] and p[1] == "transcript" and p[3] in g["t"] for g in q["gold"]):
                    rr = 1 / rank
                    break
            rec["rr"] = rr
            rec["supported"] = rec["seg_recall@5"] == 1.0 and answers
            rec["abstained_wrongly"] = not answers
        else:
            rec["correct_abstention"] = not answers
        per.append(rec)
    return per


def mean(xs):
    return sum(xs) / len(xs) if xs else float("nan")


def summarize(per):
    ans = [p for p in per if p["type"] != "unanswerable"]
    un = [p for p in per if p["type"] == "unanswerable"]

    def agg(rows):
        return {
            "n": len(rows),
            "seg_recall@1": mean([r["seg_recall@1"] for r in rows]),
            "seg_recall@3": mean([r["seg_recall@3"] for r in rows]),
            "seg_recall@5": mean([r["seg_recall@5"] for r in rows]),
            "seg_recall@10": mean([r["seg_recall@10"] for r in rows]),
            "rec_recall@5": mean([r["rec_recall@5"] for r in rows]),
            "mrr": mean([r["rr"] for r in rows]),
            "answer_support_rate": mean([1.0 if r["supported"] else 0.0 for r in rows]),
            "wrongly_abstained": mean([1.0 if r["abstained_wrongly"] else 0.0 for r in rows]),
        }
    out = {"overall": agg(ans), "by_type": {}}
    for t in ("exact", "paraphrase", "multi", "date"):
        out["by_type"][t] = agg([p for p in ans if p["type"] == t])
    out["unanswerable"] = {
        "n": len(un),
        "correct_abstention_rate": mean([1.0 if p["correct_abstention"] else 0.0 for p in un]),
        "false_answer_rate": mean([0.0 if p["correct_abstention"] else 1.0 for p in un]),
        "false_answers": [p["id"] for p in un if not p["correct_abstention"]],
    }
    return out


def latency_and_size(library, questions, copies):
    t0 = time.perf_counter()
    db = build_db(library, copies)
    build_s = time.perf_counter() - t0
    base = {r["id"]: read_recording(r) for r in library["recordings"]}
    today = dt.date.fromisoformat(library["today"])
    qs = [(content_stems(q["q"]), date_range(q["q"], today)) for q in questions]
    times = []
    for _ in range(3):
        for stems, rng in qs:
            t = time.perf_counter()
            search(db, stems, rng, 5)
            times.append((time.perf_counter() - t) * 1000)
    times.sort()
    pages = db.execute("PRAGMA page_count").fetchone()[0] * db.execute("PRAGMA page_size").fetchone()[0]
    rows = db.execute("SELECT count(*) FROM search_index").fetchone()[0]
    nrec = db.execute("SELECT count(*) FROM recordings").fetchone()[0]
    rss = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    rss_mib = rss / (1024 * 1024) if sys.platform == "darwin" else rss / 1024
    db.close()
    return {"recordings": nrec, "index_rows": rows, "db_mib": round(pages / 1048576, 2),
            "build_s": round(build_s, 2), "median_ms": round(statistics.median(times), 2),
            "p95_ms": round(times[int(0.95 * (len(times) - 1))], 2), "max_rss_mib_process": round(rss_mib, 1)}


# Context budget arithmetic (ADR-ASK-02). Constants marked ASSUMPTION are planning values; exact
# counts come from vv_llm_count_tokens in ASK-03.
BUDGET = {
    "answer_reserve": 512, "prompt_overhead": 450,  # ASSUMPTION: system + answer contract + schema
    "question": 64, "safety": 64,  # safety = TokenBudgetPlanner.safetyTokens
    "tokens_per_word": 1.4, "passage_header": 24,  # ASSUMPTION: "[rec · date · hh:mm:ss] " + id
    "kv_kib_per_token": {"3B": 112, "1B": 32},  # vv-llm-inference: f16 KV
    "rss_3b_at_4096_mib": 3718, "prefill_tok_s": (102, 145), "decode_tok_s": (21, 33),  # ASK-01 host CPU
}
TIERS = [("3B", "High (chosen)", 6144), ("3B", "High (max)", 8192),
         ("1B", "Low/Mid fallback", 4096), ("1B", "High", 8192)]


def budget_table(mean_words: float):
    b = BUDGET
    rows = []
    for words_label, words in (("eval mean", mean_words), ("30 s Whisper segment (assumed 75 words)", 75.0)):
        seg_tok = words * b["tokens_per_word"] + b["passage_header"]
        win_tok = 3 * words * b["tokens_per_word"] + b["passage_header"]  # segment ±1 neighbour
        for model, tier, n_ctx in TIERS:
            avail = n_ctx - b["answer_reserve"] - b["prompt_overhead"] - b["question"] - b["safety"]
            kv_extra = (n_ctx - 4096) * b["kv_kib_per_token"][model] / 1024
            rss = round(b["rss_3b_at_4096_mib"] + kv_extra) if model == "3B" else None
            rows.append({"passage": words_label, "model": model, "tier": tier, "n_ctx": n_ctx,
                         "passage_budget_tokens": avail,
                         "single_segments_fit": int(avail // seg_tok),
                         "neighbour_windows_fit": int(avail // win_tok),
                         "kv_extra_mib_vs_4096": round(kv_extra), "rss_3b_est_mib": rss,
                         "prefill_s_full_budget": [round(avail / b["prefill_tok_s"][1]),
                                                   round(avail / b["prefill_tok_s"][0])] if model == "3B" else None,
                         "tok_per_segment": round(seg_tok), "tok_per_window": round(win_tok)})
    return rows


def pct(x):
    return f"{100 * x:.1f}%"


def render(res) -> str:
    s = res["summary"]
    o = s["overall"]
    L = []
    L.append("# ASK-02 retrieval eval — option A (FTS5 BM25 over `search_index`)\n")
    L.append(f"Date: {res['date']} · host: {res['host']} · SQLite {sqlite3.sqlite_version} · "
             f"commit `{res['commit']}` · library {res['library_recordings']} recordings, "
             f"{res['questions']} questions · reproduce: `python3 tools/bench/ask/retrieval_eval.py`\n")
    L.append("Threshold (pre-registered in ADR-ASK-02): segment recall@5 ≥ 80%. "
             f"**Achieved: {pct(o['seg_recall@5'])} → {'PASS' if o['seg_recall@5'] >= 0.8 else 'FAIL'}.**\n")
    L.append("## Option A, all answerable questions\n")
    L.append("| Metric | Value |\n|---|---|")
    for k in ("seg_recall@1", "seg_recall@3", "seg_recall@5", "seg_recall@10", "rec_recall@5", "mrr",
              "answer_support_rate", "wrongly_abstained"):
        L.append(f"| {k} | {o[k]:.3f} |" if k == "mrr" else f"| {k} | {pct(o[k])} |")
    u = s["unanswerable"]
    L.append(f"| correct abstention (unanswerable, n={u['n']}) | {pct(u['correct_abstention_rate'])} |")
    L.append(f"| false-answer rate (unanswerable) | {pct(u['false_answer_rate'])} ({', '.join(u['false_answers']) or 'none'}) |\n")
    L.append("## By question type\n")
    L.append("| Type | n | seg@1 | seg@3 | seg@5 | seg@10 | rec@5 | MRR | support | wrongly abstained |\n|---|---|---|---|---|---|---|---|---|---|")
    for t, a in s["by_type"].items():
        L.append(f"| {t} | {a['n']} | {pct(a['seg_recall@1'])} | {pct(a['seg_recall@3'])} | {pct(a['seg_recall@5'])} | "
                 f"{pct(a['seg_recall@10'])} | {pct(a['rec_recall@5'])} | {a['mrr']:.2f} | "
                 f"{pct(a['answer_support_rate'])} | {pct(a['wrongly_abstained'])} |")
    L.append("\n## Questions that missed gold segments at k=5\n")
    L.append("| id | type | stems | seg@5 | support | abstains |\n|---|---|---|---|---|---|")
    for p in res["per_question"]:
        if p["type"] != "unanswerable" and (p["seg_recall@5"] < 1.0 or not p["answers"]):
            L.append(f"| {p['id']} | {p['type']} | {' '.join(p['stems'])} | {pct(p['seg_recall@5'])} | "
                     f"{p['support_fraction']:.2f} | {'yes' if not p['answers'] else 'no'} |")
    L.append("\n## Latency and index size (host, in-memory SQLite; not device figures)\n")
    L.append("| Recordings | Index rows | DB MiB | Build s | Query median ms | Query p95 ms | Process max RSS MiB |\n|---|---|---|---|---|---|---|")
    for r in res["scale"]:
        L.append(f"| {r['recordings']} | {r['index_rows']} | {r['db_mib']} | {r['build_s']} | {r['median_ms']} | "
                 f"{r['p95_ms']} | {r['max_rss_mib_process']} |")
    L.append("\nScaled rows replicate the 33 recordings under new ids (identical text), so they measure "
             "index size and BM25 cost, not relevance. RSS is the whole Python process high-water mark.\n")
    L.append("## Options B and C\n")
    L.append("**Unmeasured.** Both need an embedding model and a vector store, which this task may not add "
             "(no dependency, no catalog model). No recall, latency or RAM number is claimed for them. "
             "LLM query rewriting for option A is also **Unmeasured** (no local 3B runner here).\n")
    L.append("## Context budget arithmetic (planning; see ADR-ASK-02)\n")
    b = BUDGET
    L.append(f"Passage budget = n_ctx − answer reserve {b['answer_reserve']} − prompt overhead {b['prompt_overhead']} "
             f"(assumed) − question {b['question']} − safety {b['safety']}. Tokens per word {b['tokens_per_word']} and "
             f"{b['passage_header']} header tokens per passage are assumptions; mean words per eval segment "
             f"= {res['mean_words_per_segment']:.1f}. RSS estimate = measured 3718 MiB at n_ctx 4096 (ASK-01) + extra f16 KV "
             "(112 KiB/token for the 3B).\n")
    L.append("| Passage size | Model | Tier | n_ctx | Passage budget (tok) | Single segments fit | ±1-neighbour windows fit | Extra KV MiB | 3B RSS est. MiB | Prefill s for a full budget (3B host CPU) |\n|---|---|---|---|---|---|---|---|---|---|")
    for r in res["budget"]:
        pf = f"{r['prefill_s_full_budget'][0]}–{r['prefill_s_full_budget'][1]}" if r["prefill_s_full_budget"] else "n/a"
        rss = r["rss_3b_est_mib"] if r["rss_3b_est_mib"] else "n/a"
        L.append(f"| {r['passage']} ({r['tok_per_segment']} / {r['tok_per_window']} tok) | {r['model']} | {r['tier']} | {r['n_ctx']} | "
                 f"{r['passage_budget_tokens']} | {r['single_segments_fit']} | {r['neighbour_windows_fit']} | "
                 f"{r['kv_extra_mib_vs_4096']} | {rss} | {pf} |")
    return "\n".join(L) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(ROOT / "tools/bench/results/2026-10-17-ask02-retrieval"))
    ap.add_argument("--scales", default="1,31,303", help="library replication factors for latency")
    args = ap.parse_args()
    library = json.loads((HERE / "library.json").read_text())
    questions = json.loads((HERE / "questions.json").read_text())["questions"]
    base = {r["id"]: read_recording(r) for r in library["recordings"]}
    db = build_db(library)
    per = evaluate(db, library, questions, base)
    seg_words = [len(t.split()) for d in base.values() for _, t in d["segs"]]
    import platform
    import subprocess
    commit = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, capture_output=True, text=True).stdout.strip()
    res = {"date": "2026-10-17", "host": f"{platform.system()} {platform.machine()}, Python {platform.python_version()}",
           "commit": commit, "library_recordings": len(library["recordings"]), "questions": len(questions),
           "summary": summarize(per), "per_question": per,
           "mean_words_per_segment": mean(seg_words),
           "scale": [latency_and_size(library, questions, int(c)) for c in args.scales.split(",")],
           "budget": budget_table(mean(seg_words))}
    out = Path(args.out)
    out.with_suffix(".json").write_text(json.dumps(res, indent=1) + "\n")
    out.with_suffix(".md").write_text(render(res))
    print(render(res))


if __name__ == "__main__":
    main()
