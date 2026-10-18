"""[AUD-14/AC2] artifact check: Share extension embedded + App Group on both targets."""
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "tools" / "ci" / "check_ios_share_extension.sh"
AC2 = pytest.mark.parametrize("tag", ["AUD-14_AC2"])


def run(root):
    return subprocess.run([str(SCRIPT), str(root)], capture_output=True, text=True)


def copy_tree(tmp_path):
    dst = tmp_path / "app/ios"
    (dst / "Runner.xcodeproj").mkdir(parents=True)
    shutil.copy(ROOT / "app/ios/Runner.xcodeproj/project.pbxproj", dst / "Runner.xcodeproj")
    (dst / "Runner").mkdir()
    shutil.copy(ROOT / "app/ios/Runner/Runner.entitlements", dst / "Runner")
    shutil.copytree(ROOT / "app/ios/ShareExtension", dst / "ShareExtension")
    return tmp_path


@AC2
def test_repo_passes(tag):
    r = run(ROOT)
    assert r.returncode == 0, r.stdout


@AC2
def test_missing_group_on_runner_fails(tag, tmp_path):
    root = copy_tree(tmp_path)
    (root / "app/ios/Runner/Runner.entitlements").write_text(
        '<?xml version="1.0"?><plist version="1.0"><dict/></plist>')
    assert run(root).returncode == 1


@AC2
def test_not_embedded_fails(tag, tmp_path):
    root = copy_tree(tmp_path)
    p = root / "app/ios/Runner.xcodeproj/project.pbxproj"
    p.write_text(p.read_text().replace("ShareExtension.appex in Embed Foundation Extensions", "x"))
    assert run(root).returncode == 1


@AC2
def test_microphone_key_in_extension_fails(tag, tmp_path):
    root = copy_tree(tmp_path)
    p = root / "app/ios/ShareExtension/Info.plist"
    p.write_text(p.read_text().replace("<dict>", "<dict><key>NSMicrophoneUsageDescription</key><string>x</string>", 1))
    assert run(root).returncode == 1
