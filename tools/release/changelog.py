#!/usr/bin/env python3
"""Changelog from Conventional Commits (REL-01).

Reads commit subjects between the previous release tag and the current one and
groups them by type::

    changelog.py v1.2.3                 # range <previous v*-tag>..v1.2.3
    changelog.py v1.2.3 --since v1.2.0  # explicit range
    changelog.py v1.2.3 --store         # plain text, <= 500 chars (store notes)

Only subjects are used (bodies may mention internal details). Merge commits,
``chore(...)`` claim/status commits and ``test``/``ci`` noise are dropped from
user-facing output. Stdlib only.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

CC_RE = re.compile(
    r"^(?P<type>[a-z]+)(?:\((?P<scope>[^)]*)\))?(?P<bang>!)?:\s*(?P<desc>.+)$")

# Section order in the changelog; types not listed are dropped.
SECTIONS = (
    ("breaking", "Breaking changes"),
    ("feat", "Features"),
    ("fix", "Fixes"),
    ("perf", "Performance"),
    ("security", "Security"),
    ("docs", "Documentation"),
    ("refactor", "Internal"),
    ("build", "Internal"),
)
DROPPED = {"chore", "test", "ci", "style", "merge"}
# Play "What's new" limit per language.
STORE_LIMIT = 500


def parse(subjects: list[str]) -> dict[str, list[str]]:
    """Groups commit subjects by changelog section key."""
    out: dict[str, list[str]] = {}
    for s in subjects:
        s = s.strip()
        if not s or s.startswith("Merge "):
            continue
        m = CC_RE.match(s)
        if not m:
            out.setdefault("other", []).append(s)
            continue
        kind = m["type"]
        if m["bang"]:
            kind = "breaking"
        if kind in DROPPED:
            continue
        if kind not in dict(SECTIONS):
            continue
        scope = f"**{m['scope']}**: " if m["scope"] else ""
        out.setdefault(kind, []).append(f"{scope}{m['desc']}")
    return out


def render_markdown(version: str, groups: dict[str, list[str]]) -> str:
    lines = [f"## {version}", ""]
    seen_titles: dict[str, list[str]] = {}
    for key, title in SECTIONS:
        if key in groups:
            seen_titles.setdefault(title, []).extend(groups[key])
    if "other" in groups:
        seen_titles.setdefault("Other", []).extend(groups["other"])
    if not seen_titles:
        lines.append("- Maintenance release.")
    for title, items in seen_titles.items():
        lines.append(f"### {title}")
        lines += [f"- {i}" for i in items]
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def render_store(groups: dict[str, list[str]]) -> str:
    """User-facing plain text for TestFlight / Play: features + fixes only."""
    items = [re.sub(r"\*\*[^*]+\*\*: ", "", i)
             for k in ("breaking", "feat", "fix", "perf", "security")
             for i in groups.get(k, [])]
    text = "\n".join(f"• {i}" for i in items) or "Bug fixes and improvements."
    if len(text) > STORE_LIMIT:
        text = text[: STORE_LIMIT - 1].rsplit("\n", 1)[0] + "\n…"
    return text


def git(*args: str) -> str:
    return subprocess.run(["git", *args], cwd=ROOT, check=True,
                          capture_output=True, text=True).stdout


def previous_tag(tag: str) -> str | None:
    tags = [t for t in git("tag", "--list", "v*", "--sort=-v:refname").split()
            if t != tag]
    return tags[0] if tags else None


def subjects(since: str | None, until: str) -> list[str]:
    rng = f"{since}..{until}" if since else until
    return git("log", "--no-merges", "--format=%s", rng).splitlines()


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("tag")
    p.add_argument("--since")
    p.add_argument("--store", action="store_true")
    args = p.parse_args(argv)
    since = args.since or previous_tag(args.tag)
    groups = parse(subjects(since, args.tag))
    version = args.tag.removeprefix("v")
    sys.stdout.write(render_store(groups) + "\n" if args.store
                     else render_markdown(version, groups))
    return 0


if __name__ == "__main__":
    sys.exit(main())
