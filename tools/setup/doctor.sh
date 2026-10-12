#!/usr/bin/env bash
# VaultVoice toolchain check. Read-only: it never installs anything.
# Usage: tools/setup/doctor.sh            # check everything, show which tasks each gap blocks
#        tools/setup/doctor.sh core       # only what FND-01..03 / QA-01 need
# Exit code: 0 = core toolchain OK (other gaps are reported as warnings), 1 = core missing.
set -u
only="${1:-all}"
fail_core=0
missing=()

if [ -t 1 ]; then G=$'\033[32m'; R=$'\033[31m'; Y=$'\033[33m'; N=$'\033[0m'; else G=; R=; Y=; N=; fi
ok()   { printf '  %sOK%s   %-22s %s\n' "$G" "$N" "$1" "$2"; }
miss() { printf '  %sMISS%s %-22s %s\n' "$R" "$N" "$1" "$2"; missing+=("$1"); }
warn() { printf '  %sWARN%s %-22s %s\n' "$Y" "$N" "$1" "$2"; }
have() { command -v "$1" >/dev/null 2>&1; }

os="$(uname -s)"
root="$(cd "$(dirname "$0")/../.." && pwd)"

section() { [ "$only" = all ] || [ "$only" = "$1" ]; }

if section core; then
  echo "core (needed now: FND-01, FND-02, FND-03, QA-01)"
  have git && ok git "$(git --version)" || { miss git "install git"; fail_core=1; }
  if have python3 && python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)'; then
    ok python3 "$(python3 --version 2>&1)"
  else miss python3 ">= 3.8 required (tasks.py)"; fail_core=1; fi
  if have fvm; then ok fvm "$(fvm --version 2>/dev/null | head -1)"
  else miss fvm "macOS: brew tap leoafarias/fvm && brew install fvm   (or: dart pub global activate fvm)"; fail_core=1; fi
  if [ -f "$root/.fvmrc" ] && have fvm; then
    if (cd "$root" && fvm flutter --version >/dev/null 2>&1); then
      ok "flutter (fvm)" "$(cd "$root" && fvm flutter --version 2>/dev/null | head -1)"
    else miss "flutter (fvm)" "run: fvm install   (in repo root, installs the pinned SDK)"; fail_core=1; fi
  elif have flutter; then ok flutter "$(flutter --version 2>/dev/null | head -1) (no .fvmrc yet — FND-01 pins it)"
  else
    if have fvm; then warn flutter "no .fvmrc yet: FND-01 runs 'fvm install <stable>' + 'fvm use'"
    else miss flutter "installed via fvm (see above)"; fail_core=1; fi
  fi
fi

if section ios && [ "$os" = Darwin ]; then
  echo "ios (FND-01 AC on simulator; STT-01, LLM-02, AUD-04, EXP-04 …)"
  if xcodebuild -version >/dev/null 2>&1; then ok Xcode "$(xcodebuild -version | head -1)"
  else miss Xcode "install Xcode from the App Store, then: sudo xcode-select -s /Applications/Xcode.app"; fi
  have pod && ok CocoaPods "$(pod --version)" || miss CocoaPods "brew install cocoapods"
  if xcrun simctl list devices available 2>/dev/null | grep -q iPhone; then ok "iOS simulator" "available"
  else miss "iOS simulator" "Xcode > Settings > Platforms: install an iOS runtime"; fi
fi

if section android; then
  echo "android (FND-01 AC on emulator; STT-02, LLM-03, AUD-05, EXP-03 …)"
  sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
  [ -d "$sdk" ] && ok "Android SDK" "$sdk" || miss "Android SDK" "install Android Studio (brew install --cask android-studio), open it once, or set ANDROID_HOME"
  have adb && ok adb "$(adb version | head -1)" || miss adb "add \$ANDROID_HOME/platform-tools to PATH"
  if have java && java -version 2>&1 | grep -Eq 'version "(1[7-9]|2[0-9])'; then ok "JDK 17+" "$(java -version 2>&1 | head -1)"
  else miss "JDK 17+" "use Android Studio's bundled JDK or: brew install --cask temurin@17"; fi
  if [ -d "$sdk/emulator" ] && ls "$HOME/.android/avd" 2>/dev/null | grep -q '\.avd$'; then ok "Android emulator" "AVD present"
  else miss "Android emulator" "Android Studio > Device Manager: create an arm64 AVD"; fi
fi

if section native; then
  echo "native (FND-06 and later: whisper.cpp / llama.cpp builds)"
  have cmake && ok cmake "$(cmake --version | head -1)" || miss cmake "brew install cmake (>= 3.22)"
  have ninja && ok ninja "$(ninja --version)" || miss ninja "brew install ninja"
  sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
  if ls -d "$sdk"/ndk/2[8-9]* "$sdk"/ndk/[3-9][0-9]* >/dev/null 2>&1; then ok "Android NDK r28+" "$(ls "$sdk/ndk" | tail -1)"
  else miss "Android NDK r28+" "Android Studio > SDK Manager > SDK Tools > NDK (Side by side) r28+"; fi
fi

echo
if [ ${#missing[@]} -eq 0 ]; then echo "All checked tools present."
else echo "Missing: ${missing[*]}"; echo "Agents: do NOT install system tools yourself — report this list to the user and stop."; fi
[ $fail_core -eq 0 ] && echo "Core toolchain: OK" || echo "Core toolchain: MISSING (FND-01 cannot start)"
exit $fail_core
