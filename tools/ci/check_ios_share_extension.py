#!/usr/bin/env python3
"""AUD-14: static artifact check for the iOS Share extension wiring.

Asserts that Runner.xcodeproj has a ShareExtension app-extension target that
is embedded in Runner ("Embed Foundation Extensions"), that Runner and the
extension both carry the same App Group entitlement, and that the extension
declares no network/microphone capability. Usage: check_ios_share_extension.py [repo-root]
"""
import plistlib
import re
import sys
from pathlib import Path

GROUP = "group.$(APP_BUNDLE_IDENTIFIER)"
FORBIDDEN_KEYS = ("NSMicrophoneUsageDescription", "NSAppTransportSecurity", "UIBackgroundModes")


def check(root: Path) -> list[str]:
    ios = root / "app/ios"
    errs: list[str] = []
    pbx = (ios / "Runner.xcodeproj/project.pbxproj").read_text()
    if "ShareExtension.appex in Embed Foundation Extensions" not in pbx:
        errs.append("ShareExtension.appex is not in the Embed Foundation Extensions phase")
    if 'productType = "com.apple.product-type.app-extension"' not in pbx or "name = ShareExtension;" not in pbx:
        errs.append("no ShareExtension app-extension target in project.pbxproj")
    if len(re.findall(r"ShareExtension/ShareExtension\.entitlements", pbx)) < 6:
        errs.append("ShareExtension target must use its entitlements in all 6 configurations")
    if len(re.findall(r"PRODUCT_BUNDLE_IDENTIFIER = \"\$\(APP_BUNDLE_IDENTIFIER\)\.ShareExtension\"", pbx)) != 6:
        errs.append("ShareExtension bundle id must be $(APP_BUNDLE_IDENTIFIER).ShareExtension x6")
    for rel in ("Runner/Runner.entitlements", "ShareExtension/ShareExtension.entitlements"):
        try:
            ent = plistlib.loads((ios / rel).read_bytes())
        except Exception as e:  # noqa: BLE001
            errs.append(f"{rel}: unreadable ({e})")
            continue
        if GROUP not in ent.get("com.apple.security.application-groups", []):
            errs.append(f"{rel}: missing App Group {GROUP}")
        if rel.startswith("ShareExtension") and set(ent) != {"com.apple.security.application-groups"}:
            errs.append("ShareExtension entitlements must only hold the App Group")
    info = plistlib.loads((ios / "ShareExtension/Info.plist").read_bytes())
    if info.get("NSExtension", {}).get("NSExtensionPointIdentifier") != "com.apple.share-services":
        errs.append("ShareExtension Info.plist is not a share-services extension")
    for k in FORBIDDEN_KEYS:
        if k in info:
            errs.append(f"ShareExtension Info.plist must not declare {k}")
    return errs


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[2]
    errs = check(root)
    for e in errs:
        print(f"FAIL: {e}")
    print("ios share extension check:", "FAILED" if errs else "OK")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
