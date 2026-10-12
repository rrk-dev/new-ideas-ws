#!/usr/bin/env python3
"""VaultVoice task tool: list, show, find ready tasks, set status, validate task files.

Usage:
  tasks.py list   [--status S] [--phase N] [--workstream W]
  tasks.py ready  [--phase N] [--workstream W] [--no-git]
  tasks.py show   ID
  tasks.py set    ID STATUS            (review => implementer evidence check; done => full verify)
  tasks.py verify ID [--run]           independent-verification gate for one task
  tasks.py verify --all-done [--run]   re-check every done task (CI regression gate)
  tasks.py validate

Standard library only (Python 3.8+). Works from any directory. Windows: use `py -3 tasks.py …`.
"""
from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

STATUSES = ("todo", "in-progress", "blocked", "review", "done")
# Nothing else may reach `done` until CI (FND-03) and the test framework (QA-01) are done.
BOOTSTRAP = {"FND-01", "FND-02", "FND-03", "QA-01", "QA-05"}
EVIDENCE_KINDS = ("test", "device", "artifact", "ci")
SOURCE_DIRS = ("app", "packages", "native/bridge", "tools")
SOURCE_EXT = {".dart", ".py", ".c", ".cc", ".cpp", ".h", ".kt", ".swift", ".sh", ".m", ".mm"}
SKIP_DIRS = {".git", "build", ".dart_tool", "node_modules", "Pods", ".gradle", "__pycache__"}
EVIDENCE_RE = re.compile(
    r"^\s*-\s*AC(?P<n>\d+)(?:\s+\"[^\"]*\")?\s*:\s*(?P<mark>✅|⏳|❌)\s*(?P<rest>.*)$")
TOOLS = ("claude code", "codex", "cursor", "human")
ID_RE = re.compile(r"\b([A-Z]{2,4}-\d{2})\b")
META_RE = re.compile(
    r"^\*\*Workstream:\*\*\s*(?P<ws>[^|]+)\|\s*\*\*Phase:\*\*\s*(?P<phase>[^|]+)\|\s*"
    r"\*\*Size:\*\*\s*(?P<size>[^|]+)\|\s*\*\*Depends on:\*\*\s*(?P<deps>[^|]+)\|\s*"
    r"\*\*Source:\*\*\s*(?P<source>.+)$"
)
STATUS_RE = re.compile(r"^\*\*Status:\*\*\s*(?P<status>\S+)\s*$")
SKILLS_RE = re.compile(r"^\*\*Skills:\*\*\s*(?P<skills>.+)$")


@dataclass
class Task:
    id: str
    title: str
    path: Path
    workstream: str = ""
    phase: str = ""
    size: str = ""
    deps: list[str] = field(default_factory=list)
    status: str = ""
    skills: list[str] = field(default_factory=list)
    status_line: int | None = None
    errors: list[str] = field(default_factory=list)

    def phases(self) -> set[int]:
        """Phase numbers covered. Parentheticals are ignored; ranges expand; "4+" = phase 4
        (post-launch work is listed under phase 4)."""
        s = re.sub(r"\([^)]*\)", " ", self.phase)
        out: set[int] = set()
        for a, b in re.findall(r"(\d+)\s*[–-]\s*(\d+)", s):
            out |= set(range(int(a), int(b) + 1))
        s = re.sub(r"\d+\s*[–-]\s*\d+", " ", s)
        out |= {int(n) for n in re.findall(r"\d+", s)}
        return out

    def phase_label(self) -> str:
        ps = sorted(self.phases())
        if not ps:
            return "?"
        if ps == list(range(ps[0], ps[-1] + 1)) and len(ps) > 1:
            label = f"{ps[0]}-{ps[-1]}"
        else:
            label = ",".join(map(str, ps))
        return label + ("+" if "+" in self.phase else "")


def repo_root() -> Path:
    # Prefer the repo this script lives in (.agents/skills/vv-task-workflow/scripts/tasks.py).
    script_root = Path(__file__).resolve().parents[4]
    if (script_root / "tasks" / "README.md").exists():
        return script_root
    here = Path.cwd().resolve()
    for p in [here, *here.parents]:
        if (p / "tasks" / "README.md").exists():
            return p
    sys.exit("error: could not find repo root (tasks/README.md)")


SKIPPED: list[Path] = []


def load_tasks(root: Path) -> dict[str, Task]:
    tasks: dict[str, Task] = {}
    for path in sorted((root / "tasks").glob("*/*.md")):
        lines = path.read_text(encoding="utf-8").splitlines()
        head = re.match(r"^#\s+([A-Z]{2,4}-\d{2})\s+[—–-]\s+(.+)$", lines[0]) if lines else None
        if not head:
            print(f"warning: skipping {path} (no '# ID — Title' header)", file=sys.stderr)
            SKIPPED.append(path)
            continue
        t = Task(id=head.group(1), title=head.group(2).strip(), path=path)
        if not path.name.startswith(t.id + "-"):
            t.errors.append(f"filename should start with {t.id}-")
        for i, line in enumerate(lines[1:12], start=1):
            if m := META_RE.match(line):
                t.workstream = m["ws"].strip()
                t.phase = m["phase"].strip()
                t.size = m["size"].strip()
                t.deps = [d for d in ID_RE.findall(m["deps"]) if d != t.id]
            elif m := STATUS_RE.match(line):
                t.status = m["status"]
                t.status_line = i
            elif m := SKILLS_RE.match(line):
                t.skills = [s.strip() for s in m["skills"].split(",") if s.strip()]
        if t.id in tasks:
            t.errors.append(f"duplicate id (also {tasks[t.id].path})")
        tasks[t.id] = t
    return tasks


def claimed_branches(root: Path, fetch: bool = True) -> set[str]:
    if fetch:  # refresh remote-tracking refs so other agents' claims are visible
        try:
            subprocess.run(["git", "fetch", "--prune", "--quiet"], cwd=root,
                           capture_output=True, timeout=15, check=False)
        except (OSError, subprocess.TimeoutExpired):
            print("warning: git fetch failed; claim check uses local refs only", file=sys.stderr)
    try:
        out = subprocess.run(
            ["git", "branch", "-a", "--format=%(refname:short)"],
            cwd=root, capture_output=True, text=True, check=True,
        ).stdout
    except (OSError, subprocess.CalledProcessError):
        return set()
    ids = set()
    for ref in out.splitlines():
        if m := re.search(r"(?:^|/)task/([A-Z]{2,4}-\d{2})(?:-|$)", ref):
            ids.add(m.group(1))
    return ids


def fmt(t: Task) -> str:
    return f"{t.id:7} {t.status or '?':11} P{t.phase_label():<6} {t.size:3} {t.title}"


def cmd_list(tasks, args):
    for t in tasks.values():
        if args.status and t.status != args.status:
            continue
        if args.phase is not None and args.phase not in t.phases():
            continue
        if args.workstream and args.workstream.lower() not in t.workstream.lower():
            continue
        print(fmt(t))


def cmd_ready(tasks, args, root):
    claimed = set() if args.no_git else claimed_branches(root, fetch=not args.no_fetch)
    found = False
    skipped_claimed = []
    for t in tasks.values():
        if t.status != "todo":
            continue
        if t.id in claimed:
            skipped_claimed.append(t.id)
            continue
        if args.phase is not None and args.phase not in t.phases():
            continue
        if args.workstream and args.workstream.lower() not in t.workstream.lower():
            continue
        if all(tasks.get(d) and tasks[d].status == "done" for d in t.deps):
            print(fmt(t))
            found = True
    if skipped_claimed:
        print(f"(skipped {len(skipped_claimed)} claimed via task/* branches: {', '.join(sorted(skipped_claimed))})")
    pending_boot = sorted(b for b in BOOTSTRAP if tasks.get(b) and tasks[b].status != "done")
    if pending_boot:
        print(f"note: bootstrap tasks first — nothing else can reach done until FND-03 and QA-01 are done "
              f"(pending: {', '.join(pending_boot)})")
    if not found:
        print("no ready tasks (check `list --status in-progress` / `review`)")


def cmd_show(tasks, args):
    t = tasks.get(args.id)
    if not t:
        sys.exit(f"error: unknown task {args.id}")
    print(fmt(t))
    print(f"  file:   {t.path}")
    print(f"  skills: {', '.join(t.skills) or '-'}")
    for d in t.deps:
        dt = tasks.get(d)
        print(f"  dep:    {d:7} {dt.status if dt else 'MISSING':11} {dt.title if dt else ''}")
    dependents = [x.id for x in tasks.values() if t.id in x.deps]
    print(f"  unblocks: {', '.join(dependents) or '-'}")


def cmd_set(tasks, args, root):
    if args.status not in STATUSES:
        sys.exit(f"error: status must be one of {', '.join(STATUSES)}")
    t = tasks.get(args.id)
    if not t:
        sys.exit(f"error: unknown task {args.id}")
    if args.status in ("review", "done"):
        errs, warns, _ = check_evidence(t, tasks, root, args.status)
        for w in warns:
            print(f"{t.id}: warning: {w}")
        if errs:
            for e in errs:
                print(f"{t.id}: FAIL {e}")
            sys.exit(f"refusing to set {t.id} to {args.status}: {len(errs)} problem(s) (see vv-task-verify)")
    if t.status_line is None:
        sys.exit(f"error: {t.path} has no **Status:** line")
    lines = t.path.read_text(encoding="utf-8").splitlines(keepends=True)
    lines[t.status_line] = f"**Status:** {args.status}\n"
    with open(t.path, "w", encoding="utf-8", newline="") as f:  # keep LF on Windows
        f.write("".join(lines))
    print(f"{t.id}: {t.status} -> {args.status}")


# ---------------------------------------------------------------- verification
def section(text: str, title: str) -> str | None:
    m = re.search(rf"^## {re.escape(title)}\s*$(.*?)(?=^## |\Z)", text, re.M | re.S)
    return m.group(1) if m else None


def acceptance_criteria(text: str) -> list[str]:
    body = section(text, "Acceptance Criteria") or ""
    return [ln.strip()[2:] for ln in body.splitlines() if ln.strip().startswith("- ")]


def tool_of(line: str, field_name: str) -> str:
    """Tool named in `**<field_name>:** <tool> …` (text up to the next '·' or '|')."""
    m = re.search(rf"\*\*{field_name}:\*\*\s*([^·|\n]+)", line)
    low = m.group(1).lower() if m else ""
    for t in TOOLS:
        if t in low:
            return t
    return ""


_TAG_INDEX: dict[str, list[Path]] | None = None


def tag_index(root: Path) -> dict[str, list[Path]]:
    """Map every `[ID/ACn]` tag found in source/test files to the files containing it."""
    global _TAG_INDEX
    if _TAG_INDEX is None:
        _TAG_INDEX = {}
        tag_re = re.compile(r"\[([A-Z]{2,4}-\d{2})/AC(\d+)\]")
        for d in SOURCE_DIRS:
            base = root / d
            if not base.exists():
                continue
            for f in base.rglob("*"):
                if f.suffix not in SOURCE_EXT or any(part in SKIP_DIRS for part in f.parts):
                    continue
                try:
                    txt = f.read_text(encoding="utf-8", errors="ignore")
                except OSError:
                    continue
                for tid, n in tag_re.findall(txt):
                    _TAG_INDEX.setdefault(f"[{tid}/AC{n}]", []).append(f)
    return _TAG_INDEX


def check_evidence(t: Task, tasks, root: Path, level: str) -> tuple[list[str], list[str], list[tuple[str, Path]]]:
    """level = 'review' (implementer hand-off) or 'done' (independent verification).
    Returns (errors, warnings, tests_to_run)."""
    text = t.path.read_text(encoding="utf-8")
    errs: list[str] = []
    warns: list[str] = []
    to_run: list[tuple[str, Path]] = []
    acs = acceptance_criteria(text)
    if not acs:
        errs.append("no bullets under '## Acceptance Criteria'")
    scope = section(text, "Scope") or ""
    open_items = [ln.strip() for ln in scope.splitlines() if ln.strip().startswith("- [ ]")]
    if open_items:
        errs.append(f"{len(open_items)} Scope item(s) still '[ ]' (tick or mark '[~] deferred → <ID>'): {open_items[0][:70]}")
    notes = section(text, "Completion Notes")
    if notes is None:
        errs.append("missing '## Completion Notes'")
        notes = ""
    agent_line = next((ln for ln in notes.splitlines() if "**Agent:**" in ln), "")
    if notes and not tool_of(agent_line, "Agent"):
        errs.append("Completion Notes: '**Agent:**' must name Claude Code, Codex, Cursor or Human")
    evidence: dict[int, tuple[str, str]] = {}
    for ln in notes.splitlines():
        if m := EVIDENCE_RE.match(ln):
            evidence[int(m["n"])] = (m["mark"], m["rest"].strip())
    for i, ac in enumerate(acs, start=1):
        if not notes:
            break
        if i not in evidence:
            errs.append(f"AC{i}: no evidence line ('- AC{i}: ✅ test: [{t.id}/AC{i}]' …) for: {ac[:60]}")
            continue
        mark, rest = evidence[i]
        if mark == "❌":
            errs.append(f"AC{i}: marked failed")
            continue
        if mark == "⏳" and level == "done":
            errs.append(f"AC{i}: still pending (⏳) — cannot be done")
        items = [x.strip() for x in rest.split(";") if x.strip()]
        if not items:
            errs.append(f"AC{i}: evidence missing after mark")
        for item in items:
            kind, _, val = item.partition(":")
            kind, val = kind.strip().lower(), val.strip()
            if kind not in EVIDENCE_KINDS or not val:
                errs.append(f"AC{i}: evidence '{item[:50]}' must be one of {'/'.join(EVIDENCE_KINDS)}: <value>")
                continue
            if kind == "test":
                tag = f"[{t.id}/AC{i}]"
                if val != tag:
                    errs.append(f"AC{i}: test evidence must be the tag {tag}")
                files = tag_index(root).get(tag, [])
                if not files:
                    errs.append(f"AC{i}: no test containing {tag} found under {', '.join(SOURCE_DIRS)}")
                to_run += [(tag, f) for f in files]
            elif kind == "device":
                f = root / val.split("#")[0]
                if not f.exists():
                    errs.append(f"AC{i}: device checklist {val} not found")
                    continue
                rows = [ln for ln in f.read_text(encoding="utf-8").splitlines()
                        if ln.startswith("|") and f"[{t.id}/AC{i}]" in ln]
                if not rows:
                    errs.append(f"AC{i}: no row for [{t.id}/AC{i}] in {val}")
                elif level == "done" and not any(re.search(r"\|\s*PASS\s*\|", r) and re.search(r"\d{4}-\d{2}-\d{2}", r) for r in rows):
                    errs.append(f"AC{i}: device row in {val} has no PASS result with a date")
            elif kind == "artifact":
                if not (root / val.split("#")[0]).exists():
                    errs.append(f"AC{i}: artifact {val} not found")
            elif kind == "ci":
                warns.append(f"AC{i}: 'ci:' evidence ({val[:40]}) is not machine-checked — verifier must confirm it")
    if level == "done":
        for d in t.deps:
            if tasks.get(d) is None or tasks[d].status != "done":
                errs.append(f"dependency {d} is not done")
        if t.id not in BOOTSTRAP:
            for b in ("FND-03", "QA-01"):
                if tasks.get(b) is None or tasks[b].status != "done":
                    errs.append(f"{b} (CI / test framework) must be done before any non-bootstrap task")
        rep_ = section(text, "Verification Report")
        if rep_ is None:
            errs.append("missing '## Verification Report' (written by the independent verifier — vv-task-verify)")
        else:
            ver_line = next((ln for ln in rep_.splitlines() if "**Verifier:**" in ln), "")
            vtool, atool = tool_of(ver_line, "Verifier"), tool_of(agent_line, "Agent")
            if not vtool:
                errs.append("Verification Report: '**Verifier:**' must name Claude Code, Codex, Cursor or Human")
            elif vtool == atool and vtool != "human" and "**Verifier override:**" not in rep_:
                errs.append(f"verifier tool ({vtool}) is the same as the implementer — use a different tool or a human "
                            "(or add '**Verifier override:** <human name + reason>')")
            if not re.search(r"\*\*Verdict:\*\*\s*PASS\b", rep_):
                errs.append("Verification Report: '**Verdict:** PASS' not found")
            if not re.search(r"\*\*Commit:\*\*\s*[0-9a-f]{7,40}", rep_):
                errs.append("Verification Report: '**Commit:** <sha>' of the verified revision missing")
    return errs, warns, to_run


def run_tagged_tests(root: Path, to_run: list[tuple[str, Path]]) -> list[str]:
    errs = []
    seen = set()
    for tag, f in to_run:
        if (tag, f) in seen:
            continue
        seen.add((tag, f))
        rel = f.relative_to(root)
        if f.suffix == ".dart":
            pkg = next((p for p in f.parents if (p / "pubspec.yaml").exists()), None)
            if pkg is None:
                errs.append(f"{tag}: {rel} is not inside a Dart package")
                continue
            exe = ["fvm", "flutter"] if shutil.which("fvm") else (["flutter"] if shutil.which("flutter") else None)
            if exe is None:
                errs.append(f"{tag}: cannot run {rel} — neither fvm nor flutter is on PATH")
                continue
            kind = "integration (needs a device: run manually)" if "integration_test" in f.parts else None
            if kind:
                print(f"  SKIP {tag} {rel}: {kind}")
                continue
            cmd = exe + ["test", str(f.relative_to(pkg)), "--plain-name", tag]
            print(f"  RUN  {' '.join(cmd)}  (in {pkg.relative_to(root)})")
            r = subprocess.run(cmd, cwd=pkg)
            if r.returncode != 0:
                errs.append(f"{tag}: tests failed in {rel}")
        elif f.suffix == ".py":
            cmd = [sys.executable, "-m", "pytest", str(rel), "-q", "-k", tag.strip("[]").replace("/", "_")]
            print(f"  RUN  {' '.join(cmd)}  (pytest test names must contain {tag.strip('[]').replace('/', '_')})")
            if subprocess.run(cmd, cwd=root).returncode != 0:
                errs.append(f"{tag}: pytest failed in {rel}")
        else:
            print(f"  NOTE {tag} {rel}: run via its native test runner (ctest / xcodebuild test / gradle)")
    return errs


def cmd_verify(tasks, args, root) -> int:
    targets = [t for t in tasks.values() if t.status == "done"] if args.all_done else [tasks.get(args.id)]
    if not args.all_done and targets[0] is None:
        sys.exit(f"error: unknown task {args.id}")
    failed = 0
    for t in targets:
        errs, warns, to_run = check_evidence(t, tasks, root, "done")
        if args.run and not errs:
            errs += run_tagged_tests(root, to_run)
        for w in warns:
            print(f"{t.id}: warning: {w}")
        for e in errs:
            print(f"{t.id}: FAIL {e}")
        if errs:
            failed += 1
        else:
            print(f"{t.id}: PASS ({len(acceptance_criteria(t.path.read_text(encoding='utf-8')))} criteria)")
    if args.all_done and not targets:
        print("no done tasks yet")
    return 1 if failed else 0


def cmd_validate(tasks, root) -> int:
    errors = []
    skills_dir = root / ".agents" / "skills"
    known_skills = {p.parent.name for p in skills_dir.glob("*/SKILL.md")}
    readme = (root / "tasks" / "README.md").read_text(encoding="utf-8")
    errors += [f"{p}: missing or malformed '# ID — Title' header" for p in SKIPPED]
    for t in tasks.values():
        e = list(t.errors)
        if not t.phases():
            e.append(f"unparseable phase '{t.phase}'")
        if not t.workstream:
            e.append("missing/invalid metadata line")
        if t.status not in STATUSES:
            e.append(f"invalid or missing status '{t.status}'")
        if not t.skills:
            e.append("missing **Skills:** line")
        if "vv-task-workflow" not in t.skills:
            e.append("Skills must include vv-task-workflow")
        for s in t.skills:
            if s not in known_skills:
                e.append(f"unknown skill '{s}'")
        for d in t.deps:
            if d not in tasks:
                e.append(f"unknown dependency {d}")
        if f"[{t.id}](" not in readme:
            e.append("not linked from tasks/README.md")
        errors += [f"{t.id}: {msg}" for msg in e]
    # cycle detection
    state: dict[str, int] = {}

    def visit(n, stack):
        state[n] = 1
        for d in tasks[n].deps:
            if d not in tasks:
                continue
            if state.get(d) == 1:
                errors.append(f"dependency cycle: {' -> '.join(stack + [n, d])}")
            elif state.get(d) is None:
                visit(d, stack + [n])
        state[n] = 2

    for n in tasks:
        if n not in state:
            visit(n, [])
    for msg in errors:
        print(msg)
    print(f"{len(tasks)} tasks, {len(known_skills)} skills, {len(errors)} problem(s)")
    return 1 if errors else 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("list")
    p.add_argument("--status", choices=STATUSES)
    p.add_argument("--phase", type=int)
    p.add_argument("--workstream")
    p = sub.add_parser("ready")
    p.add_argument("--phase", type=int)
    p.add_argument("--workstream", help="substring match, e.g. Audio, STT, 'Security'")
    p.add_argument("--no-git", action="store_true", help="ignore task/* branches")
    p.add_argument("--no-fetch", action="store_true", help="don't run git fetch before checking claims")
    p = sub.add_parser("show")
    p.add_argument("id")
    p = sub.add_parser("set")
    p.add_argument("id")
    p.add_argument("status")
    p = sub.add_parser("verify")
    g = p.add_mutually_exclusive_group(required=True)
    g.add_argument("id", nargs="?")
    g.add_argument("--all-done", action="store_true", help="re-verify every task with status done")
    p.add_argument("--run", action="store_true", help="also run the tagged Dart/pytest tests")
    sub.add_parser("validate")
    args = ap.parse_args()
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    root = repo_root()
    tasks = load_tasks(root)
    if args.cmd == "list":
        cmd_list(tasks, args)
    elif args.cmd == "ready":
        cmd_ready(tasks, args, root)
    elif args.cmd == "show":
        cmd_show(tasks, args)
    elif args.cmd == "set":
        cmd_set(tasks, args, root)
    elif args.cmd == "verify":
        return cmd_verify(tasks, args, root)
    elif args.cmd == "validate":
        return cmd_validate(tasks, root)
    return 0


if __name__ == "__main__":
    sys.exit(main())
