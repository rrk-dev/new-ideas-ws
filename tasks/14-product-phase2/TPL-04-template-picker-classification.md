# TPL-04 — Template picker, auto-classification and eval for the new profiles

**Workstream:** Product Phase 2 | **Phase:** 5 | **Size:** M | **Depends on:** TPL-01, TPL-02, TPL-03, PRF-06, PRF-09, APP-05 | **Source:** User decision 2026-10-16 (product Phase 2: more summary templates)
**Status:** review
**Skills:** vv-task-workflow, vv-extraction-profiles, vv-flutter-architecture, vv-benchmark-eval, vv-testing, vv-licensing-iap

## Goal
Users can choose Lecture, Sales conversation and Interview (or let Auto pick them) before or after recording, and the quality of Auto selection is measured across all six built-in profiles.

## Scope
- [x] Profile choice UI lists all built-in profiles with name, one-line description and icon (uses the existing profile list/gating; no new gating logic — `FeatureGate`/`EntitlementService` only).
- [x] Extend Auto classification (PRF-06) with the new profile ids, descriptions and `classify.keywords`; keep the low-confidence ask-the-user path.
- [x] Mixed classification eval set (≥ 20 transcripts per profile, including ambiguous ones such as a meeting that mentions a sale, a lecture with Q&A) and a confusion matrix report in `tools/bench/eval/`.
- [x] Re-run extraction on an existing recording with a different profile (existing PRF-06 behaviour) works for the new profiles, and the review-before-export screen (APP-05) renders their schemas through `SchemaForm`.
- [x] Update `docs/profile-spec.md` and `docs/templates.md` listings of built-in profiles/templates and the in-app l10n strings (English only; `hardcoded_strings_test` stays green).

## Acceptance Criteria
- Auto selection accuracy ≥ 90% on the mixed eval set across the six built-in profiles (the PRF-06 bar), reported with the confusion matrix (artifact).
- Classification still adds < 10 s on a mid-tier device (device row, PRF-06 protocol).
- The picker shows locked/unlocked state per profile exactly as `kFeatureMatrix` says (widget test `[TPL-04/AC3]`).
- A recording can be re-extracted with each new profile and exported; review form renders every schema field type used (widget test `[TPL-04/AC4]`).
- Existing profile, classification and goldens tests stay green.

## Eval targets (written before the first baseline run)
Mirrored in `tools/bench/eval/classify/scoring.json`. These are targets, not measurements. The set is `tools/bench/eval/classify/cases.json`: 144 simulated transcripts, 24 per built-in profile (16 clear, 8 ambiguous: ~35 % of the sentences from a neighbouring profile; one prompt-injection case per profile), split alternately into `dev` and `holdout`. Classifier keywords may be tuned on `dev` only. A case is correct when the profile `ProfileClassifier.classify` picks equals the label (the user-is-asked path still counts by its suggestion); the label is the recording's primary purpose.

| Metric | Target |
|---|---|
| `accuracy` (all 144 cases, the PRF-06 bar) | ≥ 0.90 |
| `accuracy_holdout` (cases not used for keyword tuning) | ≥ 0.90 |
| `accuracy_ambiguous` | ≥ 0.75 |
| `recall_per_profile` (every one of the six profiles) | ≥ 0.80 |
| `confident_wrong_rate_max` (wrong pick and the user is not asked, share of all cases) | ≤ 0.05 |
| `keyword_precision` (keyword stage correct when it decides) | ≥ 0.95 |

Latency on the host is reported for information only; the < 10 s bar is a device row (`docs/test-plans/device/TPL-04.md`).

## Completion Notes
- **Agent:** Copilot CLI · **Branch:** task/TPL-04-template-picker-classification · **Date:** 2026-10-17
- **Summary:** Shared profile picker (`profile_picker.dart`: `GroupedCard` rows with icon, name, one-line description, check/lock; Auto row) used in the recording setup (bottom sheet behind the unchanged `record-profile` field) and "Change profile" on a recording (replaces the old dialog; keys `profile-option-<id>` kept). Locking uses `featureForProfile` → `featureProvider` / `ensureFeature` (new `PaywallEntryPoint.profilePicker`) with no new gating logic. Classification: keywords added to meeting (`minutes`, `blockers`), warranty (`manufacturer`, `support number`, `proof of purchase`) and interview (`welcome to the show`, `what would you do differently`), tuned on the `dev` split only; lecture and sales_call keywords unchanged because no `dev` miss pointed at them. The ask-the-user path (confidence < 0.6) is unchanged. New eval `tools/bench/eval/classify/` (`gen_cases.py`, 144 cases, `run_classify.py`, `app/tool/classify_eval.dart`) with confusion matrix. English l10n strings added. The task text's `[TPL-04/ACn]` tags match the positional numbering.
- **Baseline (measured, Llama-3.2-1B-Instruct Q4_K_M, host CPU, 144 simulated cases, one run, commit fbfc25e + uncommitted TPL-04 changes):** accuracy 93.8 % (dev 94.4 % / holdout 93.1 %), ambiguous 83.3 %, per-profile recall min 83.3 % (warranty; 4 of 24 picked meeting), wrong-and-not-asked 0.7 %, keyword stage decided 130 cases at 99.2 % precision. The LLM stage handled the remaining 14 cases at only 42.9 % accuracy; the user is asked in 9.0 % of cases. LLM-stage latency 1.6 s median on host CPU (informational). All six targets met. Report `tools/bench/results/2026-10-17-eval-classify-Llama-3-2-1B-Instruct-Q4-K-M.md`. **Caveat:** transcripts are pool-generated, so the keyword stage is easier here than on real speech; the 93.8 % is a regression bar, not a field accuracy. Keyword-only (no model) the same set gives 89.6 %.
- **Acceptance evidence:**
  - AC1: ✅ test: [TPL-04/AC1]; artifact: tools/bench/eval/baselines/classify.Llama-3-2-1B-Instruct-Q4-K-M.json
  - AC2: ⏳ test: [TPL-04/AC2]; device: docs/test-plans/device/TPL-04.md
  - AC3: ✅ test: [TPL-04/AC3]
  - AC4: ✅ test: [TPL-04/AC4]
  - AC5: ✅ test: [TPL-04/AC5]
- **Decisions:** lecture, sales_call and interview have no `Feature` row and stay ungated (`# PRODUCT-DECISION` in `profile_features.dart`; no Pro tier is enforced); warranty and engineering are locked in commercial Free per the existing matrix rows. `classify` is not added to `tools/ci/eval.sh` (it needs a model).
- **Follow-ups:**
  - Re-record the classification set with TTS → whisper (or real recordings) and re-baseline; the LLM stage (42.9 % on the 14 residual cases) needs a real set to judge.
  - Device row: classification latency < 10 s on a mid-tier phone.
  - Product: Free/Pro mapping for lecture, sales_call, interview; `minConfidence` 0.6.
  - Warranty vs meeting confusion when a warranty note has little keyword evidence.
