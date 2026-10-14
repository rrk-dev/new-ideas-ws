#!/usr/bin/env python3
"""VaultVoice versioning scheme (REL-01).

* Marketing version: SemVer ``MAJOR.MINOR.PATCH`` in ``app/pubspec.yaml``
  (the part before ``+``). A release is triggered by pushing the tag
  ``vMAJOR.MINOR.PATCH``; the tag MUST equal the pubspec version.
* Build number: ``GITHUB_RUN_NUMBER + VV_BUILD_NUMBER_OFFSET``. The run number
  of the release workflow only ever grows, so the build number is monotonic
  and shared by both stores (Play ``versionCode`` / App Store
  ``CFBundleVersion``). The offset (repo variable, default 0) lets us jump past
  numbers already used by manual uploads or a re-created workflow — it may only
  ever be increased.

The ``+N`` in pubspec is ignored for releases (local builds only); CI passes
``--build-name`` / ``--build-number`` explicitly.

Usage::

    version.py check-tag v1.2.3            # exit 1 if pubspec version differs
    version.py build-number                # prints the build number
    version.py flutter-args v1.2.3         # --build-name=1.2.3 --build-number=N
    version.py github-output v1.2.3        # name/number lines for $GITHUB_OUTPUT

Stdlib only (runs before any dependency install).
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PUBSPEC = ROOT / "app" / "pubspec.yaml"

SEMVER_RE = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$")
TAG_RE = re.compile(r"^v(?P<v>\d+\.\d+\.\d+)$")
PUBSPEC_VERSION_RE = re.compile(
    r"^version:\s*(?P<name>[0-9A-Za-z.\-]+?)(?:\+(?P<build>\d+))?\s*$", re.M)

# Play's versionCode ceiling; App Store has no lower limit we would hit first.
MAX_BUILD_NUMBER = 2_100_000_000


class VersionError(ValueError):
    """The repository/tag state does not allow a release."""


def pubspec_version(text: str) -> str:
    m = PUBSPEC_VERSION_RE.search(text)
    if not m:
        raise VersionError("no 'version:' line in pubspec.yaml")
    name = m["name"]
    if not SEMVER_RE.match(name):
        raise VersionError(f"pubspec version '{name}' is not MAJOR.MINOR.PATCH")
    return name


def tag_version(tag: str) -> str:
    tag = tag.removeprefix("refs/tags/")
    m = TAG_RE.match(tag)
    if not m or not SEMVER_RE.match(m["v"]):
        raise VersionError(f"tag '{tag}' is not vMAJOR.MINOR.PATCH")
    return m["v"]


def check_tag(tag: str, pubspec_text: str) -> str:
    """Returns the version when ``tag`` matches pubspec, else raises."""
    tv, pv = tag_version(tag), pubspec_version(pubspec_text)
    if tv != pv:
        raise VersionError(
            f"tag {tag} does not match pubspec version {pv}: bump "
            "app/pubspec.yaml in the release commit first")
    return tv


def build_number(env: dict[str, str]) -> int:
    """``GITHUB_RUN_NUMBER + VV_BUILD_NUMBER_OFFSET`` (both non-negative)."""
    run = env.get("GITHUB_RUN_NUMBER", "")
    if not run.isdigit() or int(run) < 1:
        raise VersionError("GITHUB_RUN_NUMBER must be a positive integer")
    offset = env.get("VV_BUILD_NUMBER_OFFSET", "") or "0"
    if not offset.isdigit():
        raise VersionError("VV_BUILD_NUMBER_OFFSET must be a non-negative integer")
    n = int(run) + int(offset)
    if n > MAX_BUILD_NUMBER:
        raise VersionError(f"build number {n} exceeds the Play versionCode limit")
    return n


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = p.add_subparsers(dest="cmd", required=True)
    for name in ("check-tag", "flutter-args", "github-output"):
        sub.add_parser(name).add_argument("tag")
    sub.add_parser("build-number")
    p.add_argument("--pubspec", type=Path, default=PUBSPEC)
    args = p.parse_args(argv)
    try:
        if args.cmd == "build-number":
            print(build_number(dict(os.environ)))
            return 0
        version = check_tag(args.tag, args.pubspec.read_text(encoding="utf-8"))
        if args.cmd == "check-tag":
            print(version)
        elif args.cmd == "flutter-args":
            print(f"--build-name={version} --build-number={build_number(dict(os.environ))}")
        else:
            print(f"build_name={version}")
            print(f"build_number={build_number(dict(os.environ))}")
        return 0
    except VersionError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
