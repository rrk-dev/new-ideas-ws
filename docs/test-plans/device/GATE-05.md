# Device verification — GATE-05 Product Phase 2 gate

Full scenario: [../gates/GATE-05.md](../gates/GATE-05.md). Signed release build. Every row
is ⏳ until a person runs it. Ask quality gates (ASK-03/ASK-05) are unmet and Ask is behind
`ask.enabled` (off by default); Live Activity (AUD-13) is a separate task.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [GATE-05/AC1] | S1: tap each quick-capture entry (iOS widget, Control; Android widget, tile, shortcut), cold and warm | Record screen opens, not recording | VV-IOS-16, VV-AND-PIX | current | ⏳ | | |
| [GATE-05/AC1] | S2: lecture, sales, interview profile: import, process, open the vault note | Sections and front matter correct; opens in vault app | VV-IOS-16, VV-AND-PIX | current | ⏳ | | |
| [GATE-05/AC1] | S3: Ask with `ask.enabled` on: single-recording, two-recording and unanswerable questions; open citations | Cited answers; refusal text; "answers can be wrong" note; history kept and clearable | VV-IOS-16, VV-AND-FLG | current | ⏳ | | |
| [GATE-05/AC1] | S3: High device without the 3B model | "Ask requires the 3B model" with a download action | VV-IOS-16 | current | ⏳ | | |
| [GATE-05/AC1] | S3: Mid and Low devices | "Ask isn't available on this device"; no model loaded | VV-IOS-14, VV-AND-7, VV-IOS-11, VV-AND-4G | current | ⏳ | | |
| [GATE-05/AC1] | S4: open, expand, export the mind map as Markdown and image | Matches the note; inert export; opens in vault | VV-IOS-16, VV-AND-PIX | current | ⏳ | | |
| [GATE-05/AC1] | S5: export two action items to Reminders; repeat; revoke and export | Created once; no duplicates; Settings message after revoke | VV-IOS-16 | current | ⏳ | | |
| [GATE-05/AC1] | S6: stress D-26 call interrupts a recording started from each entry | Stops on call; no call audio; never auto-resumes | VV-IOS-16, VV-AND-PIX | current | ⏳ | | |
| [GATE-05/AC1] | S6: stress D-27 low memory while asking | Clear message or queued answer; no crash; no half history entry | VV-IOS-16, VV-AND-FLG | current | ⏳ | | |
| [GATE-05/AC1] | S6: stress D-28 app killed during mind-map generation | Resumes or retry works; exactly one map | VV-IOS-16, VV-AND-PIX | current | ⏳ | | |
| [GATE-05/AC1] | S6: stress D-29 Reminders permission revoked | Message with Settings action; nothing lost | VV-IOS-16 | current | ⏳ | | |
| [GATE-05/AC1] | S6: stress D-30 quick capture never records by itself | See AC2 rows | VV-IOS-16, VV-AND-PIX | current | ⏳ | | |
| [GATE-05/AC1] | S6: stress D-31 Ask while a recording is processing | Answer waits or retrieval-only; recording unaffected | VV-IOS-16, VV-AND-FLG | current | ⏳ | | |
| [GATE-05/AC1] | S6: stress D-32 Share-extension import with the app killed | File imported once on next launch; no loss | VV-IOS-16 | current | ⏳ | | |
| [GATE-05/AC1] | S6: rerun D-13 to D-17 (call handling) on the release build | Zero call-capture failures | VV-IOS-16, VV-AND-PIX | current | ⏳ | | |
| [GATE-05/AC2] | S1: wait over 10 s after tapping an entry before the app opens; replay a tap; cold-launch the app by icon | No recording starts in any case | VV-IOS-16, VV-AND-PIX | current | ⏳ | | |
| [GATE-05/AC2] | S1: build a Shortcuts automation (iOS) that opens the Control; trigger it | Opens Record screen only; no recording | VV-IOS-16 | current | ⏳ | | |
| [GATE-05/AC3] | S7: Ask, 10 questions, 3B model, per [perf.md](../../perf.md) | Cold ≤ 30 s, warm ≤ 20 s, peak RSS ≤ 4200 MiB, thermal ≤ fair | VV-IOS-16, VV-AND-FLG | current | ⏳ | | |
| [GATE-05/AC3] | S7: mind-map step, 30 min recording | ≤ 30 s, battery ≤ 1 % | VV-IOS-16, VV-AND-FLG | current | ⏳ | | |
| [GATE-05/AC3] | S7: mind-map step, 30 min recording | ≤ 60 s, battery ≤ 1.5 % | VV-IOS-14, VV-AND-7 | current | ⏳ | | |
| [GATE-05/AC3] | S7: mind-map step, 30 min recording | ≤ 120 s, battery ≤ 2 % | VV-IOS-11, VV-AND-4G | current | ⏳ | | |
| [GATE-05/AC4] | S8: proxy capture of catalog refresh, 3B download, Ask, mind map, Reminders export, quick capture, Share import | Only allowlisted model hosts; no integration host | VV-IOS-16, VV-AND-FLG | current | ⏳ | | |
| [GATE-05/AC4] | S8: `tools/ci/check_egress.sh` on the release commit | Exit 0 | release commit | n/a | ⏳ | | |
| [GATE-05/AC5] | S9: `tasks.py verify --all-done --run` and human Verification Report | Exit 0; verifier is a human | release commit | n/a | ⏳ | | |

## Notes / evidence

Evidence goes under `docs/test-plans/device/evidence/GATE-05/`.
