#!/usr/bin/env bash
# AUD-14: Share extension target is embedded, App Group on Runner + extension.
set -euo pipefail
exec python3 "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check_ios_share_extension.py" "$@"
