"""Beta exit gate and promotion wiring (REL-04).

Host-side only. Store consoles are docs/test-plans/device/REL-04.md.
Stdlib only (no PyYAML), same as the REL-01 pipeline tests.
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))

from tools.release.beta_gate import evaluate, load_thresholds  # noqa: E402

GATE = ROOT / "tools/release/beta_gate.py"
THRESHOLDS = ROOT / "tools/release/beta_thresholds.json"
WORKFLOW = ROOT / ".github/workflows/beta.yml"
RELEASE = ROOT / ".github/workflows/release.yml"
IOS = ROOT / "app/ios/fastlane/Fastfile.beta"
ANDROID = ROOT / "app/android/fastlane/Fastfile.beta"
NOTES = ROOT / "app/ios/fastlane/beta_review_notes.txt"
DOC = ROOT / "docs/beta.md"
CHECKLIST = ROOT / "docs/release-checklist.md"


def _passing() -> dict:
    return {
        "ios_testers": 20,
        "android_testers": 30,
        "crash_free_session_rate": 0.995,
        "data_loss_reports": 0,
        "extraction_satisfaction": 0.8,
        "open_s1": 0,
    }


def _jobs(text: str) -> dict[str, str]:
    body = text.split("\njobs:\n", 1)[1]
    jobs: dict[str, str] = {}
    name = None
    for ln in body.splitlines():
        if len(ln) > 2 and not ln.startswith(" ") and ln.endswith(":"):
            break
        if m := __import__("re").match(r"^  ([a-z][a-z0-9_-]*):\s*$", ln):
            name = m[1]
            jobs[name] = ""
        elif name:
            jobs[name] += ln + "\n"
    return jobs


def _lane(source: str, lane: str) -> str:
    """Ruby from `lane :name do` through the next `lane :` or end."""
    marker = f"lane :{lane} do"
    start = source.index(marker)
    rest = source[start + len(marker):]
    nxt = rest.find("\n  lane :")
    return marker + (rest if nxt < 0 else rest[:nxt])


def test_REL_04_AC1_thresholds_are_the_exit_bar():
    """[REL-04/AC1] The published bar is 50 testers, 99.5% crash-free, zero data loss."""
    raw = json.loads(THRESHOLDS.read_text(encoding="utf-8"))
    assert raw["min_testers"] == 50
    assert raw["min_crash_free_session_rate"] == 0.995
    assert raw["max_data_loss_reports"] == 0
    assert raw["min_extraction_satisfaction"] == 0.8
    assert raw["max_open_s1"] == 0
    loaded = load_thresholds()
    assert loaded["min_testers"] == 50
    doc = DOC.read_text(encoding="utf-8")
    assert "50" in doc and "99.5%" in doc and "0.80" in doc
    assert "S1" in doc and "`beta`" in doc
    checklist = CHECKLIST.read_text(encoding="utf-8")
    assert "beta_gate.py" in checklist
    assert ".github/workflows/beta.yml" in checklist


def test_REL_04_AC1_production_blocked_until_criteria_met():
    """[REL-04/AC1] Fewer than 50 testers, one platform, or a missed bar blocks production."""
    limits = load_thresholds()
    assert evaluate(_passing(), limits) == []

    short = _passing() | {"ios_testers": 19, "android_testers": 30}
    # 49 testers.
    assert 19 + 30 == 49
    blockers = evaluate(short, limits)
    assert blockers and any("50" in b for b in blockers)

    ios_only = _passing() | {"ios_testers": 50, "android_testers": 0}
    assert any("both" in b for b in evaluate(ios_only, limits))
    android_only = _passing() | {"ios_testers": 0, "android_testers": 50}
    assert any("both" in b for b in evaluate(android_only, limits))

    shaky = _passing() | {"crash_free_session_rate": 0.994}
    assert any("0.995" in b for b in evaluate(shaky, limits))
    # Exactly 99.5% is enough.
    assert evaluate(_passing() | {"crash_free_session_rate": 0.995}, limits) == []

    loss = _passing() | {"data_loss_reports": 1}
    assert any("data-loss" in b for b in evaluate(loss, limits))

    unhappy = _passing() | {"extraction_satisfaction": 0.79}
    assert any("0.800" in b or "0.8" in b for b in evaluate(unhappy, limits))

    s1 = _passing() | {"open_s1": 1}
    assert any("S1" in b for b in evaluate(s1, limits))


def test_REL_04_AC1_cli_refuses_production_and_accepts_a_met_report(tmp_path: Path):
    """[REL-04/AC1] The release script exits 1 until the report clears the bar."""
    bad = tmp_path / "bad.json"
    good = tmp_path / "good.json"
    bad.write_text(json.dumps(_passing() | {"ios_testers": 1, "android_testers": 1}), encoding="utf-8")
    good.write_text(json.dumps(_passing()), encoding="utf-8")
    refused = subprocess.run([sys.executable, str(GATE), str(bad)], capture_output=True, text=True)
    assert refused.returncode == 1
    assert "50" in refused.stderr
    assert "transcript" not in refused.stderr.lower()
    allowed = subprocess.run([sys.executable, str(GATE), str(good)], capture_output=True, text=True)
    assert allowed.returncode == 0, allowed.stderr
    broken = tmp_path / "nope.json"
    broken.write_text("{", encoding="utf-8")
    invalid = subprocess.run([sys.executable, str(GATE), str(broken)], capture_output=True, text=True)
    assert invalid.returncode == 2


def test_REL_04_AC1_promotion_workflow_gates_production_only():
    """[REL-04/AC1] External/closed open the beta; production cannot skip the gate."""
    beta = WORKFLOW.read_text(encoding="utf-8")
    release = RELEASE.read_text(encoding="utf-8")
    # REL-01 stays a tag pipeline. Promotion is a separate manual workflow.
    on = release.split("\non:\n", 1)[1].split("\n\n", 1)[0]
    assert "workflow_dispatch" not in on
    assert "workflow_dispatch" in beta.split("\njobs:\n", 1)[0]
    jobs = _jobs(beta)
    assert "beta_gate.py" in jobs["gate"]
    assert "needs: gate" in jobs["production_ios"]
    assert "needs.gate.result == 'success'" in jobs["production_ios"]
    assert "needs: gate" in jobs["production_android"]
    assert "beta_gate.py" in jobs["production_ios"]
    assert "beta_gate.py" in jobs["production_android"]
    assert "fastlane ios production" in jobs["production_ios"]
    assert "fastlane android production" in jobs["production_android"]
    # Opening the beta is not itself gated on the exit criteria.
    assert "beta_gate.py" not in jobs["external"]
    assert "beta_gate.py" not in jobs["closed"]
    assert "fastlane ios external" in jobs["external"]
    assert "fastlane android closed" in jobs["closed"]
    # The tag workflow still uploads internal tracks only.
    assert "fastlane android internal" in release
    assert "fastlane ios beta" in release
    assert "Fastfile.beta" not in release

    ios = IOS.read_text(encoding="utf-8")
    assert 'ENV.fetch("VV_TESTFLIGHT_EXTERNAL_GROUP", "VaultVoice External")' in ios
    external = _lane(ios, "external")
    assert "distribute_only: true" in external
    assert "distribute_external: true" in external
    assert "groups: [EXTERNAL_GROUP]" in external
    assert "skip_waiting_for_build_processing: false" in external
    assert "beta_gate.py" not in external
    assert "require_beta_exit" not in external
    production = _lane(ios, "production")
    assert ios.index("beta_gate.py") < ios.index("lane :production")
    assert production.index("require_beta_exit") < production.index("deliver(")
    assert "submit_for_review: false" in production
    assert "automatic_release: false" in production

    android = ANDROID.read_text(encoding="utf-8")
    closed = _lane(android, "closed")
    assert 'promote("internal", CLOSED_TRACK, "completed")' in closed
    assert 'ENV.fetch("VV_PLAY_CLOSED_TRACK", "alpha")' in android
    assert "beta_gate.py" not in closed
    play_prod = _lane(android, "production")
    assert play_prod.index("require_beta_exit") < play_prod.index("promote(")
    assert '"draft"' in play_prod

    notes = NOTES.read_text(encoding="utf-8").lower()
    assert "does not record phone calls or voip calls" in notes
    assert "taps record" in notes
    assert "visible indicator" in notes
    assert "hugging face" in notes
    # No credential material in the beta lanes.
    for text in (ios, android, beta):
        assert "-----BEGIN" not in text
        assert "PRIVATE KEY" not in text
