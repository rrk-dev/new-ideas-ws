# Distribution license inventory — SEC-05

Engineering inventory reviewed by Codex against the resolved package sources and pinned native sources, 2026-10-14. Independent acceptance remains pending. Regenerate with `python3 tools/licenses/generate.py`; this runs `flutter pub deps --json`. Full package notices are in `app/assets/licenses/pub_inventory.json`, including build-only packages. Flutter supplies pub notices to LicenseRegistry at build time; additional native/model notices are registered by `bundled_licenses.dart`. Settings → About → Open-source & model licenses displays both.

## Native and model obligations

- whisper.cpp, llama.cpp and their ggml copies: MIT; retain the exact upstream copyright and permission notices, pinned commits in `native/VERSIONS.md`. ggml is built once from the llama.cpp tree.
- SQLite3 Multiple Ciphers 2.5.0 / SQLite 3.53.4: MIT wrapper and cipher implementation notices plus SQLite public-domain dedication. sqlite3 Dart hook pins the binary and hashes. Preserve bundled third-party notices (AES, ChaCha20, Ascon and Argon2 where included); source: https://github.com/utelle/SQLite3MultipleCiphers/blob/v2.5.0/LICENSE .
- Whisper weights (including quantizations and Core ML encoder conversions): MIT, OpenAI copyright; conversion does not remove original obligations. https://github.com/openai/whisper/blob/main/LICENSE
- Silero VAD v6.2.0: MIT, Silero Team copyright; ggml conversion by ggml-org. https://github.com/snakers4/silero-vad/blob/v6.2.0/LICENSE
- Llama 3.2 **1B Instruct** and **3B Instruct** (Q4_K_M GGUF by bartowski, llama.cpp quantization of Meta's weights; the 3B entry was added by ASK-01 under the same agreement and obligations): Llama 3.2 Community License (https://www.llama.com/llama3_2/license/). Obligations: ship a copy of the agreement (bundled in the notices screen), show "Built with Llama" in the product UI/docs, pass through the Acceptable Use Policy (https://www.llama.com/llama3_2/use-policy), the 700 M monthly-active-user clause does not apply to us today, and any AI model trained/fine-tuned with its outputs must start with "Llama". Replaces Qwen2.5-0.5B, which was removed because corporate proxies block its download. The AUP pass-through line is shown on each Llama model card in Settings › Models (`modelLlamaUsePolicy`), and the full agreement plus "Built with Llama" are in the notices screen for both models (`native_models.json`). The exact catalog revision is listed below.
- SmolLM2 (135M/360M/1.7B): Apache-2.0, preserve license and any NOTICE and describe quantization modifications. Not currently in the bundled catalog; adding weights requires a pinned model card and notice. Source: https://huggingface.co/HuggingFaceTB/SmolLM2-135M-Instruct .
- No diarization weights are currently shipped. Do not infer redistribution rights from a framework license: pyannote gated/non-commercial variants need individual review.

## Conditional model families (not currently distributed)

Llama 3.2 text (1B and 3B Instruct) is distributed since ASK-01 and is documented in the model list above: Llama 3.2 Community License (September 25, 2024), not MIT/Apache. Obligations (agreement bundled, “Built with Llama”, Acceptable Use Policy pass-through, 700-million monthly-active-user clause) are listed there. Any other Llama size or version needs its own review before catalog admission.

Gemma: version-specific Gemma Terms of Use, plus Prohibited Use Policy, not a blanket Apache license. Redistribution must include the agreement, enforceable downstream use restrictions, notice to recipients, modification notices, and the required Notice file. Terms reviewed at https://ai.google.dev/gemma/terms (April 1, 2026; Gemma 4 has separate terms) and https://ai.google.dev/gemma/prohibited_use_policy . No Gemma weights are enabled before those pass-through controls exist.

Preserve full upstream notices in the shipped app and with redistributed model files. Inventory refresh and separate licensing review are required whenever lockfile, native pins, model revision, or distribution changes. This is an engineering record, not independent legal approval.
