# STT-07 model variants — host bench (run 1 of 2, 3 speed runs)

- Host: Darwin arm64 Apple M3 Pro; whisper.cpp v1.9.5; threads 4; speed runs 3 (median, min–max); WER runs 1 (greedy is deterministic per backend).
- Corpus: tools/bench/stt_variants/passages.jsonl rendered by make_corpus.sh (macOS TTS). English WER over 5 clips; multilingual WER over de/fr/es clips with the language selected.
- RTF = decode wall time / audio duration (excl. load) on a 60 s tiled clip; peak RSS = process max RSS of the CPU run (Metal buffers on unified memory are not fully counted in the GPU run).

| Model | Size MB | sha256 (16) | WER en | WER de/fr/es | RTF Metal | RTF CPU (min–max) | Load ms | Peak RSS MB (CPU) |
|---|---:|---|---:|---:|---:|---:|---:|---:|
| ggml-tiny.en.bin | 77.7 | `921e4cf8686fdd99` | 4.0% | — | 0.011 | 0.022 (0.019–0.023) | 61 | 356 |
| ggml-tiny.en-q5_1.bin | 32.2 | `c77c5766f1cef09b` | 4.2% | — | 0.010 | 0.025 (0.021–0.025) | 39 | 371 |
| ggml-base.en.bin | 148.0 | `a03779c86df33230` | 3.6% | — | 0.070 | 0.967 (0.326–1.275) | 238 | 430 |
| ggml-base.en-q5_1.bin | 59.7 | `4baf70dd0d7c4247` | 3.6% | — | 0.031 | 0.214 (0.170–0.215) | 164 | 380 |
| ggml-base.en-q8_0.bin | 81.8 | `a4d4a0768075e13c` | 3.4% | — | 0.059 | 0.358 (0.329–0.564) | 317 | 400 |
| ggml-small.en-q5_1.bin | 190.1 | `bfdff4894dcb76bb` | 2.6% | — | 0.034 | 0.294 (0.289–0.378) | 155 | 624 |
| ggml-small.en-q8_0.bin | 264.5 | `67a179f608ea6114` | 3.0% | — | 0.037 | 0.210 (0.131–0.262) | 374 | 659 |
| ggml-base-q5_1.bin | 59.7 | `422f1ae452ade6f3` | 3.6% | 2.7% | 0.019 | 0.095 (0.092–0.164) | 92 | 354 |
| ggml-small-q5_1.bin | 190.1 | `ae85e4a935d7a567` | 2.4% | 2.7% | 0.034 | 0.147 (0.129–0.232) | 97 | 578 |
| ggml-large-v3-turbo-q5_0.bin | 574.0 | `394221709cd5ad1f` | 2.0% | 0.0% | 0.055 | 0.568 (0.505–0.855) | 486 | 1079 |
| ggml-large-v3-turbo-q8_0.bin | 874.2 | `317eb69c11673c9d` | 2.8% | 0.0% | 0.052 | 0.744 (0.355–0.896) | 1399 | 990 |
