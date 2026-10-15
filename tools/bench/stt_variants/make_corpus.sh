#!/usr/bin/env bash
# STT-07 synthetic bench corpus: renders tools/bench/stt_variants/passages.jsonl with macOS
# `say` (vv-benchmark-eval → "Creating cases without real people") and converts each clip to
# 16 kHz mono PCM16 WAV with `afconvert`. Output stays outside the repo (never commit audio):
#   $VV_BENCH_MODELS_DIR/corpus/<id>.wav + <id>.txt (reference)   default ~/.cache/vaultvoice/bench
# TTS speech is cleaner than real meetings: use the WER numbers to *rank* variants, not as
# absolute accuracy (QA-02 owns the real LibriSpeech/AMI corpus).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
OUT="${VV_BENCH_MODELS_DIR:-$HOME/.cache/vaultvoice/bench}/corpus"
command -v say >/dev/null && command -v afconvert >/dev/null || {
  echo "needs macOS say + afconvert" >&2; exit 2; }
mkdir -p "$OUT"
python3 -I - "$ROOT/tools/bench/stt_variants/passages.jsonl" "$OUT" <<'PY'
import json, subprocess, sys, pathlib
src, out = sys.argv[1], pathlib.Path(sys.argv[2])
for line in open(src, encoding="utf-8"):
    if not line.strip():
        continue
    p = json.loads(line)
    wav = out / f"{p['id']}.wav"
    (out / f"{p['id']}.txt").write_text(p["text"], encoding="utf-8")
    if wav.exists():
        continue
    aiff = out / f"{p['id']}.aiff"
    subprocess.run(["say", "-v", p["voice"], "-o", str(aiff), p["text"]], check=True)
    subprocess.run(["afconvert", "-f", "WAVE", "-d", "LEI16@16000", "-c", "1", str(aiff), str(wav)],
                   check=True)
    aiff.unlink()
    print(f"{p['id']}: {wav}")
PY
ls -l "$OUT"
