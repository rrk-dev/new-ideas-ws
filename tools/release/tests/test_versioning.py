"""Versioning scheme + changelog generation (REL-01)."""
from __future__ import annotations

import importlib.util
import subprocess
import sys
from pathlib import Path

import pytest

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def _load(name: str):
    spec = importlib.util.spec_from_file_location(f"vv_release_{name}", HERE.parent / f"{name}.py")
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(mod)
    return mod


version = _load("version")
changelog = _load("changelog")

PUBSPEC = "name: vaultvoice\ndescription: x\nversion: 1.4.2+17\n"


def test_REL_01_AC1_tag_must_match_pubspec_version():
    """[REL-01/AC1] A release tag is accepted only when it equals the pubspec version."""
    assert version.check_tag("v1.4.2", PUBSPEC) == "1.4.2"
    assert version.check_tag("refs/tags/v1.4.2", PUBSPEC) == "1.4.2"
    with pytest.raises(version.VersionError, match="does not match"):
        version.check_tag("v1.4.3", PUBSPEC)
    for bad in ("1.4.2", "v1.4", "v1.4.2-rc1", "v01.4.2", "release-1"):
        with pytest.raises(version.VersionError):
            version.check_tag(bad, PUBSPEC)
    with pytest.raises(version.VersionError):
        version.pubspec_version("name: x\nversion: 1.4\n")


def test_REL_01_AC1_build_number_is_run_number_plus_offset_and_monotonic():
    """[REL-01/AC1] Build number = GITHUB_RUN_NUMBER + VV_BUILD_NUMBER_OFFSET."""
    assert version.build_number({"GITHUB_RUN_NUMBER": "7"}) == 7
    assert version.build_number({"GITHUB_RUN_NUMBER": "7", "VV_BUILD_NUMBER_OFFSET": ""}) == 7
    assert version.build_number({"GITHUB_RUN_NUMBER": "7", "VV_BUILD_NUMBER_OFFSET": "100"}) == 107
    nums = [version.build_number({"GITHUB_RUN_NUMBER": str(r), "VV_BUILD_NUMBER_OFFSET": "100"})
            for r in range(1, 50)]
    assert nums == sorted(set(nums))
    for env in ({}, {"GITHUB_RUN_NUMBER": "0"}, {"GITHUB_RUN_NUMBER": "x"},
                {"GITHUB_RUN_NUMBER": "3", "VV_BUILD_NUMBER_OFFSET": "-1"},
                {"GITHUB_RUN_NUMBER": "3", "VV_BUILD_NUMBER_OFFSET": str(version.MAX_BUILD_NUMBER)}):
        with pytest.raises(version.VersionError):
            version.build_number(env)


def test_REL_01_AC1_cli_emits_github_outputs(tmp_path):
    """[REL-01/AC1] `version.py github-output` feeds the release jobs; mismatch exits 1."""
    pub = tmp_path / "pubspec.yaml"
    pub.write_text(PUBSPEC)
    script = str(HERE.parent / "version.py")
    env = {"GITHUB_RUN_NUMBER": "42", "VV_BUILD_NUMBER_OFFSET": "1000", "PATH": "/usr/bin:/bin"}
    ok = subprocess.run([sys.executable, script, "--pubspec", str(pub), "github-output", "v1.4.2"],
                        env=env, capture_output=True, text=True)
    assert ok.returncode == 0, ok.stderr
    assert ok.stdout.splitlines() == ["build_name=1.4.2", "build_number=1042"]
    bad = subprocess.run([sys.executable, script, "--pubspec", str(pub), "github-output", "v2.0.0"],
                         env=env, capture_output=True, text=True)
    assert bad.returncode == 1 and "does not match" in bad.stderr


def test_repo_pubspec_version_is_semver():
    """The committed pubspec is releasable (MAJOR.MINOR.PATCH)."""
    v = version.pubspec_version((ROOT / "app/pubspec.yaml").read_text(encoding="utf-8"))
    assert version.SEMVER_RE.match(v)


SUBJECTS = [
    "feat(AUD-02): record in 16 kHz chunks",
    "fix(STT-04): resume long-form windows",
    "feat!: new vault layout",
    "chore(REL-01): claim task",
    "test(REL-01): pipeline checks",
    "ci: cache gradle",
    "Merge pull request #3 from x/y",
    "docs: release checklist",
    "perf(LLM-03): smaller KV cache",
    "random subject",
]


def test_changelog_groups_conventional_commits():
    groups = changelog.parse(SUBJECTS)
    assert groups["feat"] == ["**AUD-02**: record in 16 kHz chunks"]
    assert groups["breaking"] == ["new vault layout"]
    assert groups["fix"] == ["**STT-04**: resume long-form windows"]
    assert "chore" not in groups and "test" not in groups and "ci" not in groups
    assert groups["other"] == ["random subject"]
    md = changelog.render_markdown("1.4.2", groups)
    assert md.startswith("## 1.4.2\n")
    assert md.index("### Breaking changes") < md.index("### Features") < md.index("### Fixes")
    assert "claim task" not in md and "Merge pull" not in md


def test_changelog_store_notes_are_short_and_user_facing():
    groups = changelog.parse(SUBJECTS)
    store = changelog.render_store(groups)
    assert "• record in 16 kHz chunks" in store and "**" not in store
    assert "release checklist" not in store  # docs are not user facing
    many = changelog.parse([f"fix: issue number {i} with a long description" for i in range(100)])
    assert len(changelog.render_store(many)) <= changelog.STORE_LIMIT
    assert changelog.render_store({}) == "Bug fixes and improvements."
