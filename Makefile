# Developer entry points (dev machines + CI). Recipes run from the repo root.
#
#   make eval PROFILE=meeting MODEL=<model.gguf> [EVAL_ARGS="--gpu --limit 5"]
#       Extraction quality eval (PRF-09): tools/bench/eval/run.py → report in
#       tools/bench/results/<date>-eval-<profile>-<model>.md (+ .json).
#   make eval-all MODEL=<model.gguf>    all built-in profiles
#   make eval-synth                     (re)generate missing eval transcripts
#                                       (macOS say + host whisper-cli)
# Needs the host bridge: native/build.sh host.

VV_TEST_MODELS_DIR ?= $(HOME)/.cache/vaultvoice/test-models
PROFILE ?= meeting
MODEL ?= $(VV_TEST_MODELS_DIR)/SmolLM2-135M-Instruct-Q8_0.gguf
EVAL_ARGS ?=
EVAL_PROFILES := meeting warranty engineering

.PHONY: eval eval-all eval-synth

eval:
	python3 tools/bench/eval/run.py --profile $(PROFILE) --model $(MODEL) $(EVAL_ARGS)

eval-all:
	@set -e; for p in $(EVAL_PROFILES); do \
	  python3 tools/bench/eval/run.py --profile $$p --model $(MODEL) $(EVAL_ARGS); \
	done

eval-synth:
	python3 tools/bench/eval/synth.py
