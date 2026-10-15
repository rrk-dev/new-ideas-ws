# Device verification — STT-05 On-device speaker diarization

Host (desktop CPU) measurements and the DER harness: `docs/adr/ADR-STT-05-diarization.md`,
`tools/bench/diarization/README.md`. The native engine (`vv_diar_*`) is a follow-up (see the task's
Follow-ups); rows below run once it ships. Nothing here uses a voiceprint: only anonymous labels and
user-typed names are stored.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [STT-05/AC1] ⏳ | Run the diarization bench (`tools/bench/diarization/README.md`) on the AMI 2–4 speaker meetings with the on-device engine; export RTTM; score with `der.py --collar 0.25` | DER ≤ 20% on every meeting of the set (host spike: ES2004a 17.9–20.1%, IS1009a 42% — below target, see ADR) | iPhone 14/15 Pro (VV-IOS-16) | iOS 17+ | | | |
| [STT-05/AC1] ⏳ | Same on Android flagship | Same DER as host within ±1 pt | VV-AND-FLG | Android 14+ | | | |
| [STT-05/AC2] ⏳ | Record/import a 30-min 3-speaker meeting; time STT alone, then STT + diarization (same model, thermal state cool) | Diarization adds ≤ 30% to the STT processing time | iPhone 11 (VV-IOS-11) low tier | iOS 16+ | | | |
| [STT-05/AC2] ⏳ | Same | Same | VV-AND-LOW budget | Android 14+ | | | |
| [STT-05/AC3] ⏳ | Open a diarized recording, tap "Name speakers", rename "Speaker 2" → "Priya", export to the vault | Note shows `Priya:` in the transcript and routing; unrenamed speakers keep "Speaker N" | iPhone 14/15 Pro | iOS 17+ | | | |

## Notes / evidence
Screenshots / measurements: `docs/test-plans/device/evidence/STT-05/`.
