# Diarization bench (STT-05)

Scores speaker diarization with `der.py` (NIST md-eval conventions, 0.25 s collar, Hungarian
speaker mapping) and runs the spike pipelines used by `docs/adr/ADR-STT-05-diarization.md`.

```bash
python3 der.py REF.rttm HYP.rttm --uem FILE.uem --collar 0.25   # DER of one meeting
```

Host spike (sherpa-onnx 1.13.8 + pyannote-segmentation-3.0 + WeSpeaker ResNet34, pyannote-3.1
centroid-linkage clustering). Keep scratch files in a git-ignored directory: speaker embeddings
are voiceprints and must never be committed.

```bash
uv venv .venv-diar && uv pip install --python .venv-diar sherpa-onnx numpy onnxruntime
.venv-diar/bin/python tools/spikes/STT-05-diarization/pyannote_port_spike.py \
  --items items.json --seg pyannote-seg-3.0.onnx --emb wespeaker_en_voxceleb_resnet34_LM.onnx \
  --cache .diar-cache --shift 0.5 --oracle
```

`items.json` is `[{"id","wav","rttm","uem"}]` (AMI Mix-Headset 16 kHz mono + reference RTTM).
The on-device run (AC1/AC2 rows in `docs/test-plans/device/STT-05.md`) uses the same scorer on
RTTM exported by the app's engine.
