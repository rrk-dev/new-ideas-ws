#!/usr/bin/env bash
# Recording-policy guard (SEC-09). Fails if a forbidden call-capture permission,
# audio source, CallKit provider/VoIP mode, playback/screen capture,
# accessibility service or mix-with-others session appears in the Android
# manifests (incl. the merged manifest when a build ran), Info.plist,
# entitlements or first-party sources. Rules: check_recording_policy.py and
# docs/adr/ADR-SEC-09-recording-policy.md.
# Usage: check_recording_policy.sh [repo-root] [--require-merged-manifest] [--manifest PATH]
set -euo pipefail
exec python3 "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check_recording_policy.py" "$@"
