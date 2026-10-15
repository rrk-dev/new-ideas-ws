# STT-07 model variants — host bench (run 2 of 2, 5 speed runs)

- Host: Darwin arm64 Apple M3 Pro; whisper.cpp v1.9.5; threads 4; speed runs 5 (median, min–max); WER runs 1 (greedy is deterministic per backend).
- Corpus: tools/bench/stt_variants/passages.jsonl rendered by make_corpus.sh (macOS TTS). English WER over 5 clips; multilingual WER over de/fr/es clips with the language selected.
- RTF = decode wall time / audio duration (excl. load) on a 60 s tiled clip; peak RSS = process max RSS of the CPU run (Metal buffers on unified memory are not fully counted in the GPU run).

| Model | Size MB | sha256 (16) | WER en | WER de/fr/es | RTF Metal | RTF CPU (min–max) | Load ms | Peak RSS MB (CPU) |
|---|---:|---|---:|---:|---:|---:|---:|---:|
| ggml-tiny.en.bin | 77.7 | `921e4cf8686fdd99` | 4.0% | — | 0.018 | 0.052 (0.043–0.063) | 96 | 324 |
| ggml-tiny.en-q5_1.bin | 32.2 | `c77c5766f1cef09b` | 4.2% | — | 0.028 | 0.049 (0.032–0.050) | 119 | 326 |
| ggml-base.en.bin | 148.0 | `a03779c86df33230` | 3.6% | — | 0.068 | 0.134 (0.109–0.363) | 108 | 496 |
| ggml-base.en-q5_1.bin | 59.7 | `4baf70dd0d7c4247` | 3.6% | — | 0.086 | 0.087 (0.076–0.101) | 73 | 460 |
| ggml-base.en-q8_0.bin | 81.8 | `a4d4a0768075e13c` | 3.4% | — | 0.085 | 0.088 (0.081–0.115) | 118 | 492 |
| ggml-small.en-q5_1.bin | 190.1 | `bfdff4894dcb76bb` | 2.6% | — | 0.093 | 0.284 (0.244–0.569) | 235 | 618 |
| ggml-small.en-q8_0.bin | 264.5 | `67a179f608ea6114` | 3.0% | — | 0.045 | 0.292 (0.220–0.433) | 468 | 661 |
| ggml-base-q5_1.bin | 59.7 | `422f1ae452ade6f3` | 3.6% | 2.7% | 0.023 | 0.052 (0.047–0.135) | 62 | 353 |
| ggml-small-q5_1.bin | 190.1 | `ae85e4a935d7a567` | 2.4% | 2.7% | 0.040 | 0.500 (0.162–0.928) | 276 | 580 |
| ggml-large-v3-turbo-q5_0.bin | 574.0 | `394221709cd5ad1f` | 2.0% | 0.0% | 0.077 | 0.719 (0.668–1.774) | 615 | 1075 |
| ggml-large-v3-turbo-q8_0.bin | 874.2 | `317eb69c11673c9d` | 2.8% | 0.0% | 0.075 | 1.306 (0.646–2.513) | 2188 | 1349 |
