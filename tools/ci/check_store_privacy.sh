#!/usr/bin/env bash
# Store-privacy guard (SEC-06): privacy manifests, usage strings, Android
# permissions, no call-recording claims in listing/in-app copy, privacy-policy
# link. Rules: check_store_privacy.py and docs/store/.
# Usage: check_store_privacy.sh [repo-root]
set -euo pipefail
exec python3 "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check_store_privacy.py" "$@"
