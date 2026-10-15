# PRF-09 — Extraction Quality Evaluation Harness

**Workstream:** Profiles | **Phase:** 2–3 (start early) | **Size:** L | **Depends on:** LLM-04, PRF-02 | **Source:** Gap (no quality bar defined for extraction)
**Status:** review
**Skills:** vv-task-workflow, vv-benchmark-eval, vv-extraction-profiles, vv-llm-inference, vv-testing

## Goal
A repeatable, offline eval that scores prompts/models per profile so changes are measured, not guessed.

## Scope
- [x] Seed meeting cases from `vv-extraction-profiles/references/meeting-profile.example.yaml`; draft warranty/engineering schemas here (PRF-04/05 finalize them). Synthetic audio recipe: `vv-benchmark-eval` → LLM extraction eval.
- [x] Golden dataset: ≥ 30 transcripts per built-in profile (synthetic + consented real recordings), each with expected JSON.
- [x] Desktop runner (same llama.cpp build on macOS/Linux) for fast iteration; on-device runner for final numbers. [~] on-device runner deferred → PRF-10 (needs the device lab; `run.py --from-results` already scores device output)
- [x] Metrics: schema validity, per-field exact/fuzzy match, list recall/precision, hallucination rate (items not grounded in transcript), latency.
- [x] Report diff between runs (prompt or model changes) — used as a regression gate in CI for prompt changes.

## Acceptance Criteria
- `make eval PROFILE=meeting MODEL=...` (root `Makefile` wrapping `tools/bench/eval/run.py`) produces a report in < 30 min on a dev machine; `tools/ci/eval.sh` runs it in CI on prompt/profile changes.
- Baseline numbers recorded for each built-in profile.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/PRF-09-extraction-eval-harness (stacked on task/PRF-02-system-prompt-builder — needs
  `app/tool/render_prompt.dart`) · **Date:** 2026-10-14
- **Summary:** `tools/bench/eval/`: 90 synthetic cases (30 × meeting / warranty / engineering; `script.md`, `meta.json`,
  `transcript.txt`, `expected.json`; fictional people/brands; short/long, 1–6 speakers, filler words, relative/absolute dates,
  no items, reassigned/cancelled tasks, corrections, phonetic serials, injection attempts). Transcripts made with the
  synthetic-audio recipe `synth.py` (macOS `say` per turn → 16 kHz WAV in `~/.cache/vaultvoice/eval-audio` → host
  `whisper-cli` from the pinned `native/whisper.cpp`, `ggml-base.en-q8_0`; ASR errors kept; speakers from turn timing).
  `run.py` renders + generates every case in one `app/tool/render_prompt.dart --generate` process (app PromptBuilder, GGUF chat
  template, exact budget, GBNF from the schema, extraction preset seed 42, Dart schema validator) and scores with `scoring.py`
  (stdlib only): schema validity, scalar exact/fuzzy, list P/R/F1 with fuzzy one-to-one matching + sub-field accuracy (owner,
  due), hallucination rate, prefill/decode tok/s, latency, peak RSS. Reports `tools/bench/results/<date>-eval-<profile>-<model>.{md,json}`,
  baselines `tools/bench/eval/baselines/`, diff + `--gate` (F1/accuracy −2 pt, validity < 99 %). Root `Makefile` (`make eval`,
  `eval-all`, `eval-synth`), CI wrapper `tools/ci/eval.sh` (runs only on profile/prompt/eval/llama changes), docs
  `tools/bench/eval/README.md`. Runs are deterministic (re-run vs baseline: Δ 0.0 on every metric).
- **Baselines (M3 Pro, macOS; n_ctx 4096, max_tokens 1024; full set, 1 run each — deterministic):**
  | Profile | Model | Valid | Key metric | Hallucination | Wall |
  |---|---|---|---|---|---|
  | meeting | SmolLM2-135M Q8_0 (CPU) | 100 % | action items P 3 % / R 2 % | 34 % | 117 s |
  | meeting | Llama-3.2-1B Q4_K_M (Metal) | 97 % | action items P 59 % / R 52 %, owner 66 %, attendees F1 95 % | 5 % | 74 s |
  | warranty | SmolLM2-135M | 100 % | field accuracy 39 %, serial exact 3 % | 39 % | 52 s |
  | warranty | Llama-3.2-1B | 100 % | field accuracy 71 %, serial exact 17 % | 8 % | 35 s |
  | engineering | SmolLM2-135M | 100 % | TODO recall 9 %, trade-offs recall 22 % | 50 % | 92 s |
  | engineering | Llama-3.2-1B | 93 % | TODO recall 34 %, trade-offs recall 72 % | 19 % | 184 s |
  Prompt = PRF-02 incl. the compact-JSON guidance (11912d6). The first baseline run before that change (same cases) had
  Llama meeting valid 100 % / action items P 52 % R 57 %, engineering valid 97 % / TODO R 50 % — the change is not a clear
  win and is exactly what PRF-03/05 should tune with `--gate`. Every invalid output (meeting-006, engineering-012/013) hit
  the 1024-token cap through runaway lists (decisions / open questions up to `maxItems`), not whitespace: lower `maxItems`
  or raise `n_predict` (PRF-03/05, LLM-05). Neither model meets the PRF-03/04/05 targets yet (PRF-03/04/05/LLM-08 work:
  prompt tuning, 3B-class models); the 1B over-extracts decisions/open questions (precision < 15 %) and fills placeholders
  ("unknown", "N/A") for missing serials.
- **Acceptance evidence:**
  - AC1: ✅ test: [PRF-09/AC1]; artifact: Makefile; artifact: tools/ci/eval.sh; artifact: tools/bench/eval/README.md
  - AC2: ✅ test: [PRF-09/AC2]; artifact: tools/bench/eval/baselines/; artifact: tools/bench/results/2026-10-14-eval-meeting-SmolLM2-135M-Instruct-Q8-0.md
- **Decisions:** no ADR (dev tooling). Stdlib-only metrics (no jiwer/rapidfuzz in CI). `ci.yml` not edited (rule for this wave) —
  the step to add is in `tools/bench/eval/README.md` → CI. Llama-3.2-1B (Llama 3.2 Community License) used for the eval
  baseline only, not shipped; license review stays with SEC-05/LLM-08.
- **Follow-ups:** see below.

## Follow-ups
- PRF-10 (proposed): on-device eval runner — integration test that runs the same `cases.jsonl` through `PromptBuilder` +
  `LlmService` on a device and writes the `render_prompt.dart --generate` JSONL; score with `run.py --from-results`.
- CI: add the `tools/ci/eval.sh` step (README → CI) to `.github/workflows/ci.yml` (integration agent).
- PRF-03/04/05: tune prompts against these baselines (`make eval … --gate`), and add consented real recordings when available.
- LLM-05/PRF-02 wiring: the harness scores the first pass; once the app uses `BuiltPrompt` + repair, add repair_used.
