# Device verification — AUD-14 iOS Share extension wiring

Authored without a device: the target builds unsigned (`xcodebuild -target
ShareExtension CODE_SIGNING_ALLOWED=NO`), and the static wiring is checked by
`tools/ci/check_ios_share_extension.sh`. Entitlements are only applied when
signing, so every row below needs an iPhone. Fill Device/OS/Result/Date/Tester
only after running.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [AUD-14/AC2] | Paid team (or TestFlight): archive the dev flavor; `codesign -d --entitlements - Runner.app` and `…/PlugIns/ShareExtension.appex`. | Both contain `com.apple.security.application-groups` = `group.com.vaultvoice.vaultvoice.dev`; the `.appex` is in `PlugIns/`. | n/a (Mac) | Xcode current | | | |
| [AUD-14/D5] | Free Personal Team: run the dev flavor on a device with automatic signing (Runner + LumenWidgets + ShareExtension). | Records whether Xcode provisions the App Group and the extension, or the exact error (App ID limit, capability not supported). If it fails, follow the fallback in `docs/audio-import.md`. | iPhone | iOS 16+ | | | |
| [AUD-14/AC1] | Voice Memos → share a memo → Lumen; then open Lumen. | Extension finishes immediately; the app shows the attestation for the memo; import succeeds and converts to 16 kHz mono WAV; `Inbox/Audio` is empty afterwards. | iPhone | iOS 16+ | | | |
| [AUD-14/AC1] | Files → clip.m4a → Share → Lumen; repeat with 2 files selected. | Each file appears in the import flow. | iPhone | iOS 16+ | | | |
| [AUD-14/AC1] | Share a non-audio file (PDF) | Lumen is not offered in the share sheet. | iPhone | iOS 16+ | | | |
| [AUD-14/AC3] | Airplane mode on; share a memo. | Works identically (no network use). | iPhone | iOS 16+ | | | |
