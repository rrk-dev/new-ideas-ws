"""Static checks of the release pipeline (REL-01).

The pipeline itself can only run on GitHub Actions with store credentials
(docs/test-plans/device/REL-01.md). These tests pin down everything that can be
checked without it: tag trigger, both store uploads, obfuscation + private
symbols, secrets only from GitHub secrets and all documented, no key material
committed. Stdlib only (no PyYAML on the CI task-gate runner).
"""
from __future__ import annotations

import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
WORKFLOW = ROOT / ".github/workflows/release.yml"
BUILD = ROOT / "tools/release/build_release.sh"
IOS_FASTFILE = ROOT / "app/ios/fastlane/Fastfile"
ANDROID_FASTFILE = ROOT / "app/android/fastlane/Fastfile"
SIGNING = ROOT / "app/android/signing.gradle"
GRADLE = ROOT / "app/android/app/build.gradle.kts"
SECRETS_DOC = ROOT / "docs/release-secrets.md"
CHECKLIST = ROOT / "docs/release-checklist.md"


def _code(path: Path) -> str:
    """File content without full-line comments (#, //)."""
    return "\n".join(
        ln for ln in path.read_text(encoding="utf-8").splitlines()
        if not re.match(r"^\s*(#|//)", ln))


def _jobs(text: str) -> dict[str, str]:
    """Top-level jobs of a workflow -> their YAML block (indentation based)."""
    body = text.split("\njobs:\n", 1)[1]
    jobs: dict[str, str] = {}
    name = None
    for ln in body.splitlines():
        if m := re.match(r"^  ([a-z][a-z0-9_-]*):\s*$", ln):
            name = m[1]
            jobs[name] = ""
        elif name:
            jobs[name] += ln + "\n"
    return jobs


def test_REL_01_AC1_release_runs_only_on_version_tags():
    """[REL-01/AC1] Tagging vX.Y.Z (and nothing else) starts the release."""
    text = WORKFLOW.read_text(encoding="utf-8")
    on = text.split("\non:\n", 1)[1].split("\n\n", 1)[0]
    assert re.search(r"push:\s*\n\s*tags:\s*\[\"v\*\.\*\.\*\"\]", on), on
    assert "branches" not in on and "pull_request" not in on
    assert "workflow_dispatch" not in on, "releases must come from a tag"
    assert "cancel-in-progress: false" in text
    # The tag is validated against pubspec before anything is built.
    jobs = _jobs(text)
    assert "version.py github-output \"$GITHUB_REF_NAME\"" in jobs["prepare"]
    for j in ("android", "ios"):
        assert "needs: prepare" in jobs[j]
        assert "environment: release" in jobs[j]
    for j in ("publish-android", "publish-ios"):
        assert "environment: release" in jobs[j]


def test_REL_01_AC1_signed_builds_go_to_testflight_and_play_internal():
    """[REL-01/AC1] Both lanes sign and upload: TestFlight + Play internal track."""
    jobs = _jobs(WORKFLOW.read_text(encoding="utf-8"))
    assert "bundle exec fastlane android upload" in jobs["publish-android"]
    assert "bundle exec fastlane ios upload" in jobs["publish-ios"]

    ios = _code(IOS_FASTFILE)
    assert re.search(r"lane :beta do\s*\n\s*build\s*\n\s*upload\b", ios)
    assert re.search(r"lane :upload do", ios)
    assert re.search(r"match\(type: \"appstore\", readonly: true", ios)
    assert "app_store_connect_api_key(" in ios
    assert "upload_to_testflight(" in ios
    assert "update_code_signing_settings(" in ios and "Release-prod" in ios
    # API key only: no Apple ID password flows.
    assert not re.search(r"FASTLANE_PASSWORD|APP_SPECIFIC_PASSWORD|apple_id\(", ios)

    android = _code(ANDROID_FASTFILE)
    assert re.search(r"lane :internal do\s*\n\s*build\s*\n\s*upload\b", android)
    assert re.search(r"lane :upload do", android)
    assert re.search(r"upload_to_play_store\(\s*\n\s*track: \"internal\"", android)
    assert "app-prod-release.aab" in android

    # Gradle: release uses the upload key; CI refuses a debug-signed fallback.
    assert 'apply(from = "../signing.gradle")' in GRADLE.read_text(encoding="utf-8")
    signing = _code(SIGNING)
    assert "signingConfig signingConfigs.upload" in signing
    assert 'System.getenv("VV_REQUIRE_RELEASE_SIGNING") == "true"' in signing
    assert "export VV_REQUIRE_RELEASE_SIGNING=true" in _code(BUILD)


def test_REL_01_AC1_obfuscated_builds_keep_symbols_private():
    """[REL-01/AC1] --obfuscate + --split-debug-info; symbols only as private artifacts."""
    build = _code(BUILD)
    flags = build.split("RELEASE_FLAGS=(", 1)[1].split(")", 1)[0]
    for f in ("--obfuscate", "--split-debug-info=", "--flavor prod",
              "lib/main_prod.dart", "--build-number=", "--save-obfuscation-map="):
        assert f in flags, f
    assert re.search(r"build appbundle \"\$\{RELEASE_FLAGS\[@\]\}\"", build)
    assert re.search(r"build ipa \"\$\{RELEASE_FLAGS\[@\]\}\"", build)
    # Apple must not receive dSYMs from the export either.
    assert "<key>uploadSymbols</key><false/>" in IOS_FASTFILE.read_text(encoding="utf-8")

    text = WORKFLOW.read_text(encoding="utf-8")
    jobs = _jobs(text)
    for j in ("android", "ios"):
        assert f"app/build/release-symbols/{j}/" in jobs[j]
        assert re.search(r"uses: actions/upload-artifact@\S+\n\s+with:\n\s+name: symbols-" + j, jobs[j])
    # No third-party crash/symbol upload anywhere in the release path, and
    # no public GitHub Release carrying artifacts.
    release_path = "\n".join(_code(p).lower() for p in (WORKFLOW, BUILD, IOS_FASTFILE, ANDROID_FASTFILE))
    for forbidden in ("crashlytics", "sentry", "bugsnag", "firebase", "upload_symbols_to",
                      "softprops/action-gh-release", "gh release", "contents: write"):
        assert forbidden not in release_path, forbidden


def test_REL_01_AC1_secrets_only_from_github_and_all_documented():
    """[REL-01/AC1] Every credential is a GitHub secret listed in docs/release-secrets.md."""
    text = WORKFLOW.read_text(encoding="utf-8")
    used = set(re.findall(r"\$\{\{\s*secrets\.([A-Z0-9_]+)\s*\}\}", text))
    assert used, "workflow uses no secrets?"
    doc = SECRETS_DOC.read_text(encoding="utf-8")
    documented = set(re.findall(r"^\| `([A-Z0-9_]+)` \|", doc, re.M))
    variables = set(re.findall(r"\$\{\{\s*vars\.([A-Z0-9_]+)\s*\}\}", text))
    assert used <= documented, f"undocumented secrets: {used - documented}"
    assert documented - variables <= used, f"documented but unused: {documented - variables - used}"
    assert variables <= documented
    # Secrets are only exposed as step env (not job-wide, not inline in run:).
    for ln in _code(WORKFLOW).splitlines():
        if "secrets." in ln:
            assert re.match(r"^\s{10}[A-Z0-9_]+: \$\{\{ secrets\.[A-Z0-9_]+ \}\}$", ln), ln
    # Steps that decode secrets never trace and write private files.
    for block in re.findall(r"run: \|\n((?:\s{10}.*\n)+)", text):
        if "base64 --decode" in block:
            assert "set +x" in block and "umask 077" in block


def test_REL_01_AC1_no_key_material_committed():
    """[REL-01/AC1] No keystore, .p8, key.properties or private key in the repo."""
    files = subprocess.run(["git", "ls-files"], cwd=ROOT, check=True,
                           capture_output=True, text=True).stdout.splitlines()
    bad_names = [f for f in files if re.search(
        r"(\.jks|\.keystore|\.p8|\.p12|\.mobileprovision|key\.properties)$", f)]
    assert not bad_names, bad_names
    pem = re.compile(r"-----BEGIN (RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----")
    checked = 0
    for f in files:
        p = ROOT / f
        if p.suffix in {".png", ".jpg", ".bin", ".gguf", ".sig"} or not p.is_file():
            continue
        try:
            txt = p.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        checked += 1
        assert not pem.search(txt), f"private key material in {f}"
    assert checked > 50
    # The files CI writes are gitignored.
    ignore = (ROOT / "app/android/.gitignore").read_text(encoding="utf-8")
    for pat in ("key.properties", "**/*.jks", "**/*.keystore"):
        assert pat in ignore


def test_release_checklist_covers_required_items():
    """Scope: release checklist (SEC-06, licence screen, version bump, smoke test)."""
    text = CHECKLIST.read_text(encoding="utf-8").lower()
    for item in ("sec-06", "licence screen", "version bumped", "changelog", "egress report",
                 "size check", "oldest and newest device", "symbols archived"):
        assert item in text, item


def test_REL_01_AC1_uploads_only_after_all_gates_pass():
    """[REL-01/AC1] Codex review: size + recording-policy gates precede BOTH store uploads."""
    jobs = _jobs(WORKFLOW.read_text(encoding="utf-8"))
    for j in ("android", "ios"):
        assert "fastlane" in jobs[j] and f"fastlane {j} build" in jobs[j]
        assert not re.search(r"fastlane (android internal|ios beta|\w+ upload)", jobs[j])
        assert "tools/ci/size_check.sh" in jobs[j]
        assert "check_recording_policy.sh" in jobs[j]
        assert f"name: binary-{j}" in jobs[j]
        # build jobs hold no store credentials
        assert "PLAY_SERVICE_ACCOUNT" not in jobs[j]
    for j, lane in (("publish-android", "android upload"), ("publish-ios", "ios upload")):
        needs = re.search(r"needs: \[([^\]]*)\]", jobs[j])[1]
        assert {"android", "ios"} <= {n.strip() for n in needs.split(",")}
        assert f"fastlane {lane}" in jobs[j]
        assert "size_check.sh" not in jobs[j]


def test_REL_01_AC1_symbols_archived_with_release_and_retention_documented():
    """[REL-01/AC1] Codex review: symbols are uploaded before publish and the
    90-day artifact limit is documented as needing a durable archive."""
    jobs = _jobs(WORKFLOW.read_text(encoding="utf-8"))
    for j in ("android", "ios"):
        assert f"name: symbols-{j}-" in jobs[j]
    for j in ("publish-android", "publish-ios"):
        assert "symbols-" not in jobs[j]
    assert "90 days" in CHECKLIST.read_text(encoding="utf-8")


def test_REL_02_AC1_native_dsyms_packaged_and_collected():
    """[REL-02/AC1] Codex review: vv_native dSYMs go into the xcframework and into release symbols."""
    native = _code(ROOT / "native/build.sh")
    assert native.count("-debug-symbols") >= 2
    assert "vv_native.framework.dSYM" in native
    build = _code(BUILD)
    assert "vv_native.xcframework" in build and "dSYMs/*.dSYM" in build
    assert "native/dSYMs/" in build
