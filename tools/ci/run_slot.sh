#!/usr/bin/env bash
# Runs tools/ci/<script> if it exists, else reports that the slot is still
# empty (warning, not failure). Usage: run_slot.sh <script> <owner-task>
# Slots: check_recording_policy.sh (SEC-09), native_host.sh (FND-06).
source "$(dirname "$0")/lib.sh"
script="$1"; owner="$2"
if [ -f "$ROOT/tools/ci/$script" ]; then
  exec bash "$ROOT/tools/ci/$script"
fi
msg="tools/ci/$script is not delivered yet ($owner); this check did NOT run"
echo "::warning::$msg"
echo "$msg"
