# Models

What Lumen offers, why, and how it is chosen per device and plan. Catalog source:
`tools/model-catalog/models.json` → signed `app/assets/catalog/catalog.json` (MDL-01). LLM models
are documented by LLM-07/LLM-08; this page currently covers speech-to-text (STT-07).

## Speech-to-text (Whisper, STT-07)

### Variants in the catalog
All files are the whisper.cpp ggml conversions from `huggingface.co/ggerganov/whisper.cpp` at
revision `5359861c739e955e79d9a303bcbc70fb988958b1` (mirror; our CDN is primary). Sizes and
SHA-256 were computed from the downloaded files (`shasum -a 256`, equal to the HF LFS etag) —
see `_provenance` in `models.json`. License: MIT (OpenAI Whisper weights, whisper.cpp).

| Catalog id | File | Size (bytes) | SHA-256 (first 16) | Languages | Catalog tier | LIC-01 feature | `min_ram_mb` | Device tiers |
|---|---|---:|---|---|---|---|---:|---|
| `whisper-tiny.en` | `ggml-tiny.en.bin` | 77,704,715 | `921e4cf8686fdd99` | English | free | — | 2048 | low, mid, high |
| `whisper-tiny.en-q5_1` | `ggml-tiny.en-q5_1.bin` | 32,166,155 | `c77c5766f1cef09b` | English | free | — | 2048 | low |
| `whisper-base.en-q5_1` | `ggml-base.en-q5_1.bin` | 59,721,011 | `4baf70dd0d7c4247` | English | free | — | 2048 | low, mid, high |
| `whisper-base.en` | `ggml-base.en.bin` | 147,964,211 | `a03779c86df33230` | English | free | — | 3072 | mid, high |
| `whisper-small.en-q5_1` | `ggml-small.en-q5_1.bin` | 190,098,681 | `bfdff4894dcb76bb` | English | pro | `smallStt` | 3072 | low, mid, high |
| `whisper-small.en-q8_0` | `ggml-small.en-q8_0.bin` | 264,477,561 | `67a179f608ea6114` | English | pro | `smallStt` | 4096 | mid, high |
| `whisper-base-q5_1` | `ggml-base-q5_1.bin` | 59,707,625 | `422f1ae452ade6f3` | 99 languages, auto-detect | free | — | 2048 | low, mid, high |
| `whisper-small-q5_1` | `ggml-small-q5_1.bin` | 190,085,487 | `ae85e4a935d7a567` | 99 languages, auto-detect | pro | `smallStt` | 3072 | low, mid, high |
| `whisper-large-v3-turbo-q5_0` | `ggml-large-v3-turbo-q5_0.bin` | 574,041,195 | `394221709cd5ad1f` | 99 languages, auto-detect | pro | `highAccuracyStt` | 6144 | high |

Benchmarked but **not** offered: `base.en-q8_0` (no WER gain over q5_1, larger) and
`large-v3-turbo-q8_0` (874 MB, no WER gain over q5_0 on our corpus, ~3.5× the load time).

### Model matrix (host)
Raw data: `tools/bench/results/2026-10-14-stt07-variants.{md,json}` (run 2, 5 speed runs) and
`…-run1.{md,json}` (run 1, 3 speed runs). Harness: `tools/bench/stt_variants/` (`make_corpus.sh`,
`run.py`) over `native/tests/stt_backends bench`.

- **Setup:** Apple M3 Pro (12 cores, 18 GB), macOS, `native/build.sh host` (Release, Metal, one
  ggml), whisper.cpp v1.9.5 (`d1be6fde`), 4 threads, greedy, `no_context`, `suppress_nst`,
  temperature fallback 0.2, language = clip language. Thermal state not controlled.
- **Caveat — shared machine:** both runs ran while 8 other agents were building/testing on the
  same host (load average 50–400 on 12 cores). **WER is deterministic and unaffected; RTF and
  load times are inflated and noisy** — compare them only within a run, take the minimum as the
  closest to an idle machine, and use the device rows for real numbers.
- **Corpus:** 5 English passages (meeting ×2, warranty note, incident review, personal notes;
  ≈ 3 min, ~490 words, voices en-US/en-GB/en-AU/en-IE) + de/fr/es meeting passages (≈ 30 s each),
  rendered with macOS TTS (`tools/bench/stt_variants/passages.jsonl`). TTS is cleaner than real
  meetings: **use the numbers to rank variants, not as absolute accuracy** (QA-02 owns the real
  LibriSpeech/AMI corpus). 1 WER point ≈ 5 words, so differences < 1 pt are within noise.
- **WER** normalization = `vv-benchmark-eval/scripts/wer.py`. **RTF** = decode wall time / audio
  (60 s tiled clip, excl. load). **Peak RSS** = process max RSS of the CPU-only run (Metal
  buffers on unified memory are not fully counted in the GPU run).

| Model | Size MB | WER en | WER de/fr/es | RTF Metal (run 1 / run 2) | RTF CPU median (min) run 2 | Load ms (run 2) | Peak RSS MB (CPU) |
|---|---:|---:|---:|---:|---:|---:|---:|
| tiny.en | 77.7 | 4.0 % | — | 0.011 / 0.018 | 0.052 (0.043) | 96 | 324–356 |
| tiny.en-q5_1 | 32.2 | 4.2 % | — | 0.010 / 0.028 | 0.049 (0.032) | 119 | 326–371 |
| base.en | 148.0 | 3.6 % | — | 0.070 / 0.068 | 0.134 (0.109) | 108 | 430–496 |
| **base.en-q5_1** | 59.7 | 3.6 % | — | 0.031 / 0.086 | 0.087 (0.076) | 73 | 380–460 |
| base.en-q8_0 *(not offered)* | 81.8 | 3.4 % | — | 0.059 / 0.085 | 0.088 (0.081) | 118 | 400–492 |
| **small.en-q5_1** | 190.1 | 2.6 % | — | 0.034 / 0.093 | 0.284 (0.244) | 235 | 618–624 |
| small.en-q8_0 | 264.5 | 3.0 % | — | 0.037 / 0.045 | 0.292 (0.220) | 468 | 659–661 |
| **base-q5_1** (multilingual) | 59.7 | 3.6 % | 2.7 % | 0.019 / 0.023 | 0.052 (0.047) | 62 | 353–354 |
| **small-q5_1** (multilingual) | 190.1 | 2.4 % | 2.7 % | 0.034 / 0.040 | 0.500 (0.162) | 276 | 578–580 |
| **large-v3-turbo-q5_0** | 574.0 | 2.0 % | 0.0 % | 0.055 / 0.077 | 0.719 (0.668) | 615 | 1075–1079 |
| large-v3-turbo-q8_0 *(not offered)* | 874.2 | 2.8 % | 0.0 % | 0.052 / 0.075 | 1.306 (0.646) | 2188 | 990–1349 |

Findings that drive the defaults:
1. **q5_1 is the sweet spot**: base.en-q5_1 = base.en on WER at 40 % of the size; small.en-q5_1
   ≤ small.en-q8_0 on WER (2.6 vs 3.0 %) at 72 % of the size. q8_0 variants buy nothing here.
2. **small is the first real accuracy step** (≈ 1 pt better than base) and costs ~3× CPU time.
3. **large-v3-turbo-q5_0 is the most accurate** (2.0 % en, 0 % on de/fr/es) but needs ~1.1 GB
   RSS and is ~8× slower than base on CPU — High tier with a GPU only; CPU-only background runs on
   iOS need a device measurement (follow-up STT-09).
4. The multilingual base/small are as good as the English-only ones on English here, but the
   `.en` models remain the English default (whisper's `.en` models are better on real English
   speech per upstream evaluations; re-check with QA-02).

### Model matrix per device class
Filled from `docs/test-plans/device/STT-07.md` (⏳ until run on devices).

| Model | Low (iPhone 11 / 4 GB Android) WER · RTF GPU/CPU · RSS | Mid (6 GB) | High (8 GB+, flagship) |
|---|---|---|---|
| tiny.en-q5_1 | ⏳ | — | — |
| base.en-q5_1 | ⏳ | ⏳ | ⏳ |
| small.en-q5_1 | ⏳ | ⏳ | ⏳ |
| small.en-q8_0 | — | ⏳ | ⏳ |
| base-q5_1 | ⏳ | ⏳ | ⏳ |
| small-q5_1 | ⏳ | ⏳ | ⏳ |
| large-v3-turbo-q5_0 | — | — | ⏳ |

### Tier × plan defaults (per-device recommended model)
Device tier from total RAM (`tierForRam`: Low < 5 GiB, Mid 5–7 GiB, High ≥ 7 GiB). Implemented
in `app/lib/features/transcription/domain/stt_model_policy.dart` (`kSttPreference`,
`recommendedSttModel`): the first id in the preference list that is in the catalog, entitled and
fits `min_ram_mb` wins.

| Device tier | Free · English | Pro · English | Free · other languages | Pro · other languages |
|---|---|---|---|---|
| Low | base.en-q5_1 (→ tiny.en-q5_1 → tiny.en) | small.en-q5_1 | base-q5_1 | small-q5_1 |
| Mid | base.en-q5_1 (→ base.en) | small.en-q5_1 (→ small.en-q8_0) | base-q5_1 | small-q5_1 |
| High | base.en-q5_1 (→ base.en) | large-v3-turbo-q5_0 (→ small.en-q5_1) | base-q5_1 | large-v3-turbo-q5_0 (→ small-q5_1) |

### Plan enforcement (LIC-01)
- Size class → feature: tiny/base = baseline (no flag), small = `Feature.smallStt`,
  medium/large/large-v3-turbo = `Feature.highAccuracyStt` (`sttFeatureFor`).
- A model is usable only if **both** its size-class feature is entitled **and** its catalog
  `tier` is allowed (`sttModelEntitled` via `SttPlanGate.entitlements(EntitlementService)` /
  `sttPlanGateProvider`). A mis-tagged catalog entry can only make a model stricter.
- `resolveSttModel` is the single enforcement point for the model picker (MDL-03) and the engine
  factory (FND-11): an unentitled, unknown, too-large or wrong-language selection falls back to the
  recommended default. Downgrade (subscription lapsed): Pro models stay installed but are no
  longer selected (`sttModelAccess` → `readOnly`); nothing is deleted.
- Tests: `[STT-07/AC2]` in `app/test/unit/transcription/stt_model_policy_test.dart` (every bundled
  STT model × plan, catalog-tag consistency, live downgrade).

### Language handling
- Setting: an ISO 639-1 code or `auto`. Default = the device locale's language
  (`defaultSttLanguage`; PRODUCT-DECISION: English locales → `en`, others → their language;
  `auto` offered but not default because detection on the first window can pick the wrong
  language in mixed-language meetings).
- `en` → English-only (`.en`) models; anything else (incl. `auto`) → multilingual models
  (`needsMultilingual`). `.en` models always decode with `language = en` (`sttLanguageFor`); a
  `.en` selection for a non-English user is replaced by the multilingual default.

### Default decode parameters
As in `vv-whisper-stt` → Default parameters (greedy on Low, beam 5 on Mid/High — QA-02 to
confirm), `no_context = true`, `carry_initial_prompt = true`, temperature 0 / +0.2,
entropy/logprob/no-speech thresholds 2.4 / −1.0 / 0.6, `suppress_nst = true`.

### PRODUCT-DECISIONs (open for the owner)
- `small` / `small.en` is **Pro** (master plan §7 says Free gets "small/tiny"; skills default to
  Pro) — one cell in `feature_matrix.dart` (`Feature.smallStt`) flips it.
- large-v3-turbo is the High-tier Pro default for English as well (best WER; larger download).
- Default language follows the device locale (see above).

### Reproduce
```bash
native/build.sh host                                  # builds stt_backends too
tools/bench/stt_variants/make_corpus.sh               # macOS: say + afconvert → ~/.cache
# models in $VV_BENCH_MODELS_DIR (default ~/.cache/vaultvoice/bench), never in the repo
python3 -I tools/bench/stt_variants/run.py --runs 5 --out tools/bench/results/<date>-stt07-variants
```

## LLM defaults (LLM-08)
Decision record: [ADR-LLM-08](adr/ADR-LLM-08-default-llm.md) (**Proposed** — host numbers for
Llama-3.2-1B only; the other candidates are `needs-eval`). Ranking harness:
`make llm-select` (`tools/bench/llm_select/rank.py` + `candidates.json`) over the PRF-09 eval
results (`make eval-all MODEL=<gguf>` per candidate).

| Tier | Default (today) | Fallback | Status |
|---|---|---|---|
| Free (any device) | Llama-3.2-1B-Instruct Q4_K_M | none in catalog (Qwen2.5-0.5B removed: blocked by corporate proxies) | provisional |
| Low (< 5 GiB) | Llama-3.2-1B-Instruct Q4_K_M | — | provisional |
| Mid (5–7 GiB) | Llama-3.2-3B-Instruct Q4_K_M *(unmeasured; expected, see ADR)* | Llama-3.2-1B | needs-eval |
| High (≥ 7 GiB) | Llama-3.2-3B-Instruct Q4_K_M *(unmeasured)* | Llama-3.2-1B | needs-eval |

Licences (SEC-05 has the final word): Llama 3.2 Community License (attribution "Built with
Llama", AUP pass-through, 700 M MAU clause), Gemma Terms of Use (prohibited-use pass-through),
Qwen2.5-3B is **Qwen Research License — not usable commercially** (rejected by the harness);
Qwen2.5-0.5B/1.5B, Qwen3, SmolLM2 Apache-2.0; Phi-4-mini MIT.
