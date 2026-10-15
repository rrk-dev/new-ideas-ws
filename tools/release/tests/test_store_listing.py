"""Static checks of store-listing assets (REL-05).

Screenshot capture and store submission need simulators / consoles
(docs/test-plans/device/REL-05.md). These tests pin sizes, metadata
structure, reviewer notes, IAP IDs, and synthetic demo data.
"""
from __future__ import annotations

import json
import struct
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SIZES = ROOT / "tools/release/store_screenshot_sizes.json"
IAP = ROOT / "tools/release/iap_products.json"
SNAP = ROOT / "app/ios/fastlane/Snapfile"
SCREENGRAB = ROOT / "app/android/fastlane/Screengrabfile"
IOS_STORE = ROOT / "app/ios/fastlane/Fastfile.store"
ANDROID_STORE = ROOT / "app/android/fastlane/Fastfile.store"
CAPTURE = ROOT / "tools/release/capture_store_screenshots.sh"
DEMO = ROOT / "app/test/helpers/store_demo_data.dart"
IOS_NOTES = ROOT / "app/ios/fastlane/metadata/review_information/notes.txt"
ANDROID_NOTES = ROOT / "app/android/fastlane/metadata/android/en-US/review_notes.txt"
CHECKLIST = ROOT / "docs/release-checklist.md"
IAP_DOC = ROOT / "docs/iap-products.md"
STORE_DOC = ROOT / "docs/store-listing.md"
FEATURE = ROOT / "app/android/fastlane/metadata/android/en-US/images/featureGraphic.png"
ICON = ROOT / "app/android/fastlane/metadata/android/en-US/images/icon.png"
WAV = ROOT / "app/test/fixtures/audio/store_demo_silence.wav"
SPLASH_PROD = ROOT / "app/flutter_native_splash-prod.yaml"
SPLASH_DEV = ROOT / "app/flutter_native_splash-dev.yaml"
ICONS_PROD = ROOT / "app/flutter_launcher_icons-prod.yaml"
ICONS_DEV = ROOT / "app/flutter_launcher_icons-dev.yaml"

IOS_COPY = ROOT / "app/ios/fastlane/metadata/en-US"
ANDROID_COPY = ROOT / "app/android/fastlane/metadata/android/en-US"

REVIEWER_NEEDLES = (
    "does NOT record phone calls or VoIP",
    "user taps the Record",
    "Hugging Face",
    "audio",
    "processing",
    "store_demo_silence.wav",
    "vv_pro_annual",
    "vv_pro_lifetime",
)


def _png_size(path: Path) -> tuple[int, int]:
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", path
    return struct.unpack(">II", data[16:24])


def _wav_fmt(path: Path) -> tuple[int, int]:
    data = path.read_bytes()
    assert data[:4] == b"RIFF" and data[8:12] == b"WAVE"
    assert data[12:16] == b"fmt "
    channels, rate = struct.unpack_from("<HI", data, 22)
    return channels, rate


def test_REL_05_AC1_required_screenshot_sizes():
    """[REL-05/AC1] Required App Store / Play pixel sizes are pinned."""
    spec = json.loads(SIZES.read_text(encoding="utf-8"))
    assert spec["retrieved"] == "2026-10-15"
    shots = spec["shots"]
    assert shots == [
        "01_onboarding",
        "02_record",
        "03_library",
        "04_transcript",
        "05_settings",
    ]
    ios = {row["id"]: row for row in spec["ios"]}
    assert ios["iphone_dynamic_island_medium"]["portrait"] == [1206, 2622]
    assert ios["iphone_dynamic_island_medium"]["required"] is True
    assert "iPhone 16 Pro" in ios["iphone_dynamic_island_medium"]["devices"]
    assert ios["ipad_13"]["portrait"] == [2064, 2752]
    assert ios["ipad_13"]["required"] is True
    android = {row["id"]: row for row in spec["android"]}
    assert android["phone"]["portrait"] == [1080, 1920]
    assert android["feature_graphic"]["size"] == [1024, 500]
    assert android["hires_icon"]["size"] == [512, 512]


def test_REL_05_AC1_fastlane_snapshot_and_screengrab():
    """[REL-05/AC1] Snapfile / Screengrabfile / Fastfile.store match the sizes file."""
    spec = json.loads(SIZES.read_text(encoding="utf-8"))
    snap = SNAP.read_text(encoding="utf-8")
    assert "iPhone 16 Pro" in snap
    assert "iPad Pro 13-inch (M4)" in snap
    assert "en-US" in snap
    grab = SCREENGRAB.read_text(encoding="utf-8")
    assert "en-US" in grab
    assert "com.vaultvoice.vaultvoice" in grab
    for fast in (IOS_STORE, ANDROID_STORE):
        text = fast.read_text(encoding="utf-8")
        assert "lane :screenshots" in text
        assert "capture_store_screenshots.sh" in text
    script = CAPTURE.read_text(encoding="utf-8")
    exe = "\n".join(
        ln for ln in script.splitlines() if not ln.lstrip().startswith("#")
    )
    assert "flutter build" not in exe
    assert "store_screenshots_test.dart" in exe
    assert spec["shots"][0] == "01_onboarding"


def test_REL_05_AC1_synthetic_demo_data_not_real_people():
    """[REL-05/AC1] Screenshot seed uses Speaker A/B, never real names or photos."""
    demo = DEMO.read_text(encoding="utf-8")
    assert "Speaker A" in demo and "Speaker B" in demo
    assert "Sample weekly planning" in demo
    for banned in ("Priya", "'Sam'", '"Sam"', "NetworkImage", "FileImage"):
        assert banned not in demo, banned
    integ = (ROOT / "app/integration_test/store_screenshots_test.dart").read_text(
        encoding="utf-8")
    assert "storeDemoOverrides" in integ
    assert "[REL-05/AC1]" in integ


def test_REL_05_AC1_metadata_placeholders_and_reviewer_notes():
    """[REL-05/AC1] fastlane metadata structure + engineering reviewer notes."""
    ios_files = (
        "name.txt", "subtitle.txt", "description.txt", "keywords.txt",
        "promotional_text.txt", "release_notes.txt", "support_url.txt",
        "marketing_url.txt", "privacy_url.txt",
    )
    for name in ios_files:
        text = (IOS_COPY / name).read_text(encoding="utf-8")
        assert "[PRODUCT]" in text, name
    android_files = (
        "title.txt", "short_description.txt", "full_description.txt",
        "changelogs/default.txt",
    )
    for name in android_files:
        text = (ANDROID_COPY / name).read_text(encoding="utf-8")
        assert "[PRODUCT]" in text, name
    for notes in (IOS_NOTES, ANDROID_NOTES):
        text = notes.read_text(encoding="utf-8")
        assert "[PRODUCT]" not in text
        for needle in REVIEWER_NEEDLES:
            assert needle in text, f"{notes.name}: missing {needle!r}"
        assert "CallKit" in text or "READ_PHONE_STATE" in text


def test_REL_05_AC1_iap_product_ids():
    """[REL-05/AC1] vv_pro_annual and vv_pro_lifetime are the store product IDs."""
    spec = json.loads(IAP.read_text(encoding="utf-8"))
    ids = [p["id"] for p in spec["products"]]
    assert ids == ["vv_pro_annual", "vv_pro_lifetime"]
    doc = IAP_DOC.read_text(encoding="utf-8")
    for pid in ids:
        assert f"`{pid}`" in doc
    listing = STORE_DOC.read_text(encoding="utf-8")
    for pid in ids:
        assert pid in listing


def test_REL_05_AC1_icons_splash_and_play_graphics():
    """[REL-05/AC1] Flavor icons/splash config and Play graphics dimensions."""
    assert "icon_prod.png" in ICONS_PROD.read_text(encoding="utf-8")
    assert "icon_dev.png" in ICONS_DEV.read_text(encoding="utf-8")
    prod = SPLASH_PROD.read_text(encoding="utf-8")
    dev = SPLASH_DEV.read_text(encoding="utf-8")
    assert "#3F51B5" in prod
    assert "#5C6BC0" in dev
    assert _png_size(FEATURE) == (1024, 500)
    assert _png_size(ICON) == (512, 512)
    channels, rate = _wav_fmt(WAV)
    assert channels == 1 and rate == 16000
    checklist = CHECKLIST.read_text(encoding="utf-8")
    assert "Store listing (REL-05)" in checklist
    assert "vv_pro_annual" in checklist
    assert "capture_store_screenshots.sh" in checklist


def test_REL_05_AC1_capture_script_skips_without_args():
    """[REL-05/AC1] Capture script is syntax-valid and does not compile the app."""
    subprocess.run(["bash", "-n", str(CAPTURE)], check=True)
    proc = subprocess.run(
        ["bash", str(CAPTURE)],
        capture_output=True,
        text=True,
        check=False,
    )
    assert proc.returncode == 2
    body = "\n".join(
        ln for ln in CAPTURE.read_text(encoding="utf-8").splitlines()
        if not ln.lstrip().startswith("#")
    )
    assert "flutter build" not in body
    assert "flutter test integration_test/store_screenshots_test.dart" in body
