#!/usr/bin/env python3
"""Builds the MAP-01 mind-map eval set (tools/bench/eval/mindmap/cases.json).

36 cases = 6 per built-in profile, reused from the PRF-09/TPL synthetic sets (every fifth case
of each profile directory, sorted by id, so short and long ones are mixed; cases whose
`expected.json` has no reference concept at all are skipped). Each case carries the
transcript exactly as the pipeline sees it (`[hh:mm:ss] Speaker: text` lines) and its *reference
concept list*, derived from the hand-written `expected.json` of that case (never from a model):

    meeting      topics, decisions, action_items.task, open_questions
    warranty     product, brand, retailer
    engineering  concepts, tradeoffs.option, decisions, todos.task, open_questions
    lecture      key_concepts.term, outline.heading, assignments.task, questions
    sales_call   needs, objections.objection, commitments.what, next_steps.task
    interview    topics, qa_highlights.question, follow_ups.task

Deterministic, stdlib only. Run from the repo root:

    python3 tools/bench/eval/mindmap/gen_cases.py
"""
from __future__ import annotations

import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
EVAL = HERE.parent
PER_PROFILE = 6
STEP = 5

# field -> sub-key (None = list of strings, "" = scalar string)
CONCEPTS = {
    "meeting": {"topics": None, "decisions": None, "action_items": "task", "open_questions": None},
    "warranty": {"product": "", "brand": "", "retailer": ""},
    "engineering": {"concepts": None, "tradeoffs": "option", "decisions": None, "todos": "task",
                    "open_questions": None},
    "lecture": {"key_concepts": "term", "outline": "heading", "assignments": "task", "questions": None},
    "sales_call": {"needs": None, "objections": "objection", "commitments": "what", "next_steps": "task"},
    "interview": {"topics": None, "qa_highlights": "question", "follow_ups": "task"},
}


def concepts(profile: str, expected: dict) -> list[str]:
    out: list[str] = []
    for field, sub in CONCEPTS[profile].items():
        value = expected.get(field)
        if sub == "":
            if isinstance(value, str) and value.strip():
                out.append(value.strip())
            continue
        for item in value or []:
            text = item.get(sub) if isinstance(item, dict) else item
            if isinstance(text, str) and text.strip():
                out.append(text.strip())
    seen, uniq = set(), []
    for c in out:
        if c.lower() not in seen:
            seen.add(c.lower())
            uniq.append(c)
    return uniq


def main() -> None:
    cases = []
    for profile in CONCEPTS:
        dirs = sorted(d for d in (EVAL / profile).iterdir() if (d / "expected.json").exists())
        # Every fifth case first; a case without any reference concept is skipped
        # for the next unused one.
        order = dirs[::STEP] + [d for d in dirs if d not in dirs[::STEP]]
        picked = 0
        for d in order:
            if picked == PER_PROFILE:
                break
            expected = json.loads((d / "expected.json").read_text())
            if not concepts(profile, expected):
                continue
            picked += 1
            cases.append({
                "id": d.name,
                "profile": profile,
                "title": expected.get("title") or expected.get("product") or d.name,
                "transcript": (d / "transcript.txt").read_text(encoding="utf-8"),
                "concepts": concepts(profile, expected),
            })
    assert len(cases) == PER_PROFILE * len(CONCEPTS)
    spec = {
        "_doc": "MAP-01 mind-map eval set; regenerate with gen_cases.py. Concepts come from the "
                "hand-written expected.json of each PRF-09/TPL case.",
        "cases": cases,
    }
    (HERE / "cases.json").write_text(json.dumps(spec, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"mindmap: {len(cases)} cases, {sum(len(c['concepts']) for c in cases)} reference concepts")


if __name__ == "__main__":
    main()
