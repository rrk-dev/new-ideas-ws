# Device verification — ASK-03 Ask your notes (engine)

Host tests cover the engine (`app/test/unit/ask/`: retrieval, citation validation, residency
exclusion, log content, history, expiry, delete cascade) and the host end-to-end eval
(`tools/bench/results/2026-10-17-ask03-eval.md`). Per-tier budgets are pre-registered in
`tasks/14-product-phase2/ASK-03-ask-engine.md`. These rows need a High-tier phone (3B model,
min RAM 7168 MB) and could not be run when this was authored.

Protocol (QA-03, `docs/perf.md`): a library of 100 recordings (the ASK-02 synthetic set, copied);
10 questions from the ASK-02 mix; Ask opened **cold** (LLM not resident; STT idle) and then
**warm**. Read the thermal state before and after the ten questions. No question text is
written down in the evidence: ids only.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [ASK-03/AC7] High tier, iOS cold | 1. Install the prod build, install the 3B model, import the 100-recording library. 2. Force-quit the app, relaunch, open Ask. 3. Ask question Q1; time to the first answer. 4. Peak RSS from Xcode Instruments. | ≤ 30 s to the first answer; peak RSS ≤ 4200 MiB | iPhone 15 Pro or newer (8 GB) | iOS 17+ | ⏳ | | |
| [ASK-03/AC7] High tier, iOS warm | 1. Immediately after the cold run ask Q2–Q10. 2. Median time-to-first-answer. 3. Thermal state after Q10. | Median ≤ 20 s; thermal no worse than `fair` | iPhone 15 Pro or newer | iOS 17+ | ⏳ | | |
| [ASK-03/AC7] High tier, Android cold + warm | Same as the two iOS rows; peak RSS from `dumpsys meminfo`; thermal from `PowerManager` status. | Same budgets | arm64 Android ≥ 8 GB RAM | API 34+ | ⏳ | | |
| [ASK-03/AC7] Mid/Low tier | Open Ask on a < 7 GB device. | "Not available on this device"; no model load attempted | arm64 Android 6 GB | API 26+ | ⏳ | | |
| [ASK-03/AC3] Pipeline running | Start a long import (STT running), then ask. | Ask waits (or shows the retrieved passages) and never unloads the STT model; after the job the answer arrives | High-tier phone | iOS 17+ / API 34+ | ⏳ | | |

## Notes / evidence
Screenshots and traces under `docs/test-plans/device/evidence/ASK-03/`. Numbers go into
`docs/perf.md` only when measured.
