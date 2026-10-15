"""Pins the product owner decisions of 2026-10-14 in build/config files.

iOS 16.4 minimum, ARMv8.2-A + dotprod Android CPU minimum (no Cortex-A53/A35), Hugging Face-only
model hosting, Core ML Whisper encoder shipped on iOS. Recorded in tasks/README.md -> Open
Decisions and the ADRs named below. A refactor that silently reverts one of them fails here.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CMAKE = (ROOT / "native" / "CMakeLists.txt").read_text()
BUILD = (ROOT / "native" / "build.sh").read_text()


def test_ios_minimum_is_16_4_everywhere():
    """ADR-FND-06: Xcode (every build configuration), podspec, native build, docs."""
    pbx = (ROOT / "app/ios/Runner.xcodeproj/project.pbxproj").read_text()
    targets = set(re.findall(r"IPHONEOS_DEPLOYMENT_TARGET = ([0-9.]+);", pbx))
    assert targets == {"16.4"}, targets
    podspec = (ROOT / "packages/vv_native/ios/vv_native.podspec").read_text()
    assert "s.platform = :ios, '16.4'" in podspec
    assert 'IOS_MIN_OS="${IOS_MIN_OS:-16.4}"' in BUILD
    assert "iOS 16.4+" in (ROOT / "AGENTS.md").read_text()
    assert "iOS 16.4+" in (ROOT / "CONTRIBUTING.md").read_text()


def test_android_cpu_minimum_is_armv8_2_dotprod():
    """ADR-LLM-03 / ADR-STT-02: static builds default to dotprod; DL builds drop armv8.0."""
    assert 'set(VV_ANDROID_CPU_MIN_ARCH "armv8.2-a+dotprod")' in CMAKE
    assert 'set(GGML_CPU_ARM_ARCH "${VV_ANDROID_CPU_MIN_ARCH}")' in CMAKE
    block = CMAKE[CMAKE.index("add_subdirectory(llama.cpp/ggml ggml)"):]
    block = block[: block.index("endif()")]
    assert "ggml-cpu-android_armv8.0_1 PROPERTIES EXCLUDE_FROM_ALL ON" in block
    assert "list(REMOVE_ITEM _vv_shipped_backends ggml-cpu-android_armv8.0_1)" in block
    # The bridge refuses CPUs below the minimum on every Android build.
    cpu_h = (ROOT / "native/bridge/vv_cpu.h").read_text()
    assert "#define VV_CPU_ANDROID_MIN (VV_CPU_FEAT_NEON | VV_CPU_FEAT_DOTPROD)" in cpu_h
    llama = (ROOT / "native/bridge/vv_llama.cpp").read_text()
    assert re.search(r"#if defined\(__ANDROID__\)\s*\n(\s*//.*\n)*\s*b \|= VV_CPU_ANDROID_MIN;", llama)


def test_models_are_hosted_on_hugging_face_only():
    """ADR-MDL-01 (Accepted): one host + its observed redirect host, no CDN placeholder."""
    hosts = (ROOT / "app/lib/core/network/model_hosts.dart").read_text()
    assert "vaultvoice.example" not in hosts
    assert "const Set<String> kModelHosts = {kModelHuggingFaceHost};" in hosts
    assert "const kModelRedirectHosts = {'us.aws.cdn.hf.co'};" in hosts
    for path in ("tools/model-catalog/models.json", "app/assets/catalog/catalog.json",
                 "app/lib/features/models/data/catalog_config.dart"):
        assert "vaultvoice.example" not in (ROOT / path).read_text(), path
    catalog = json.loads((ROOT / "app/assets/catalog/catalog.json").read_text())
    for m in catalog["models"]:
        for u in m["urls"]:
            assert u.startswith("https://huggingface.co/") and "/resolve/" in u, u


def test_ios_ships_the_coreml_encoder_with_fallback():
    """ADR-STT-01 (Accepted): Core ML on in the iOS build, fallback always compiled in, and a
    signed catalog companion for every shipped Whisper model."""
    ios = BUILD[BUILD.index("build_ios() {"):]
    ios = ios[: ios.index("\n}\n")]
    assert '-DVV_WHISPER_COREML="${VV_WHISPER_COREML:-ON}"' in ios
    assert "set(WHISPER_COREML_ALLOW_FALLBACK ON)" in CMAKE
    catalog = json.loads((ROOT / "app/assets/catalog/catalog.json").read_text())
    by_id = {m["id"]: m for m in catalog["models"]}
    for m in catalog["models"]:
        if m["type"] != "stt":
            continue
        enc = [by_id[c] for c in m["companions"] if by_id[c]["type"] == "coreml-encoder"]
        assert len(enc) == 1, m["id"]
        assert enc[0]["file"].endswith("-encoder.mlmodelc.zip")
