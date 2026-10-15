"""Exercise store-build arguments without store credentials or platform SDKs."""
import json
import os
from pathlib import Path
import shutil
import subprocess

import pytest

ROOT = Path(__file__).resolve().parents[3]


def _build_fixture(tmp_path):
    script = tmp_path / "tools/release/build_release.sh"
    script.parent.mkdir(parents=True)
    shutil.copyfile(ROOT / "tools/release/build_release.sh", script)
    (tmp_path / "app").mkdir()
    fakebin = tmp_path / "bin"
    fakebin.mkdir()
    flutter = fakebin / "fvm"
    flutter.write_text("""#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
Path(os.environ['VV_TEST_ARGS']).write_text(json.dumps(sys.argv[1:]))
if 'appbundle' in sys.argv:
    dest = Path('build/app/outputs/bundle/prodRelease/app-prod-release.aab')
else:
    dest = Path('build/ios/ipa/app.ipa')
dest.parent.mkdir(parents=True, exist_ok=True)
dest.write_bytes(b'synthetic-build-artifact')
""")
    flutter.chmod(0o755)
    env = dict(os.environ, PATH=f"{fakebin}:{os.environ['PATH']}",
               VV_BUILD_NAME="1.2.3", VV_BUILD_NUMBER="42",
               VV_TEST_ARGS=str(tmp_path / "args.json"))
    env.pop("VV_PLAY_PUBLIC_KEY", None)
    return script, env


@pytest.mark.parametrize("platform", ["android", "ios"])
def test_LIC_02_AC1_store_builds_enable_commercial_mode(tmp_path, platform):
    """[LIC-02/AC1] Actual release script passes commercial flag to IPA and AAB."""
    script, env = _build_fixture(tmp_path)
    # Synthetic fixture, not a usable licensing/signing key.
    env["VV_PLAY_PUBLIC_KEY"] = "cHVibGljLXRlc3QtZml4dHVyZQ=="
    subprocess.run(["bash", str(script), platform, str(tmp_path / "export.plist")],
                   check=True, env=env, capture_output=True, text=True)
    args = json.loads((tmp_path / "args.json").read_text())
    assert args[:3] == ["flutter", "build", "appbundle" if platform == "android" else "ipa"]
    assert args.count("--dart-define=VV_COMMERCIAL=true") == 1
    assert args[args.index("--flavor") + 1] == "prod"
    assert "--release" in args
    assert not any(env["VV_PLAY_PUBLIC_KEY"] in arg for arg in args)


def test_LIC_02_AC1_android_release_refuses_missing_console_key(tmp_path):
    """[LIC-02/AC1] Missing verification key blocks the release before Flutter."""
    script, env = _build_fixture(tmp_path)
    result = subprocess.run(["bash", str(script), "android"], env=env,
                            capture_output=True, text=True)
    assert result.returncode != 0
    assert "VV_PLAY_PUBLIC_KEY" in result.stderr
    assert not (tmp_path / "args.json").exists()
