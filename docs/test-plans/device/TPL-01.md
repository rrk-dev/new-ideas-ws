# Device verification — TPL-01 Built-in profile: Lecture notes

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [TPL-01/AC5] | 1. Low-tier device, default LLM installed. 2. Import a 60-minute single-speaker lecture recording (e.g. a public-domain lecture). 3. Process it with the Lecture profile. 4. Watch peak memory (Xcode Instruments / Android Studio Profiler). | Job reaches `done` via map-reduce; note renders; no out-of-memory kill; peak RSS stays within the Low-tier LLM budget (`docs/long-transcripts.md`). | Low-tier Android (≤ 4 GB RAM) | Android 14 | ⏳ | | |

## Notes / evidence
Host test (`app/test/unit/extraction/lecture_long_host_test.dart`) covers the path with SmolLM2-135M; the device row covers the real Low-tier memory budget.
