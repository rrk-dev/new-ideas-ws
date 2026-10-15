# ADR-STT-05 — Speaker diarization: sherpa-onnx pyannote pipeline with centroid-linkage clustering

- **Status:** Proposed (host DER misses the ≤ 20% target on 3 of 4 AMI meetings; no on-device engine or timing yet — rows ⏳ in `docs/test-plans/device/STT-05.md`)
- **Date:** 2026-10-15
- **Task:** STT-05
- **Deciders:** Copilot (implementer); pending independent verifier and device numbers
- **Supersedes:** —

## Context
Whisper has no speaker labels, but the Meeting profile promises attendees and task owners.
Speakers are labelled "Speaker N" on-device after STT; the user renames them per recording.
Speaker embeddings are biometric data (BIPA, GDPR special category): they may exist only in
memory during clustering and never be persisted or enrolled (no voiceprints).

## Options
| Option | Idea | Result |
|---|---|---|
| A. sherpa-onnx `OfflineSpeakerDiarization` as shipped | pyannote-seg-3.0 windows → WeSpeaker embeddings → complete-linkage AHC | 46–66% DER on AMI in the earlier spike (`pyannote_port_spike.py` docstring) — rejected |
| B. **pyannote-3.1 recipe on the same ONNX models** | same segmentation/embeddings, centroid-linkage AHC on L2-normalised embeddings (threshold 0.7046), small clusters re-assigned | 16–42% DER, see below — **chosen, to be tuned** |
| C. Own embedding + clustering on VAD spans (`embed_cluster_spike.py`) | no segmentation model, one embedding per VAD span | no overlap handling, worse boundaries; kept only as the fallback |
| D. whisper.cpp tinydiarize | speaker-turn token from a finetuned small.en | English-only, one model size, marks turns but does not identify returning speakers; rejected for ≥ 3 speakers |

## Criteria
DER (≤ 20%, weight 50%), added processing time (≤ 30% of STT, 20%), model size (10%),
no persisted biometrics / offline / licence (hard gates, 20%).

## Evidence
Host: Apple Silicon CPU, sherpa-onnx 1.13.8, onnxruntime, segmentation shift 0.5 s,
WeSpeaker ResNet34 (25 MB) + pyannote-seg-3.0 (5.7 MB; int8 1.5 MB), AMI Mix-Headset,
0.25 s collar, md-eval conventions (`tools/bench/diarization/der.py`). Speaker count automatic
(threshold 0.7046).

| Meeting | Audio | Ref / hyp speakers | DER | Miss / FA / conf (s) | Segmentation + embedding |
|---|---|---|---|---|---|
| TS3003a | 25.1 min | 4 / 3 | **16.4%** | — | 7 s + 33 s |
| ES2004a | 17.5 min | 4 / 5 | 20.1% (17.9% with the speaker count given) | 84.5 / 12.1 / 37.0 | 36 s + 120 s |
| EN2002a | 35.7 min | 4 / 5 | 26.4% | — | 11 s + 53 s |
| IS1009a | 14.0 min | 4 / 1 | 42.3% (collapses to one cluster) | 63.0 / 9.0 / 145.4 | 6 s + 61 s |

Mean 26.3%: the ≤ 20% criterion is met on 1 meeting, borderline on another. A fixed threshold of
0.9 collapses everything to one speaker (ES2004a 56.9%), so the threshold matters. Passing the
speaker count (profile `num_speakers`) helps ES2004a but the top-k reconstruction collapsed on
three meetings in this spike (an implementation bug in the Python port to fix before the native
port). Cost on this host: 3–15% of audio duration (segmentation + embedding, 4 threads); Whisper
time on the same host was not measured, so AC2 (≤ 30% of STT time) is unproven, and phone numbers
need the device rows.

## Decision (provisional)
Ship the product side now: `DiarizationEngine` interface (turns only; embeddings never leave the
engine), the aligner (max overlap, token-boundary split for ≥ 1 s changes, edited segments never
split), `DiarizeStep` (optional: profile `stt.diarization`, else the `processing.diarization_default`
setting, default off), per-recording speaker renames flowing into Markdown, and the automated
no-embeddings-persisted check. Native engine (Option B on the bridge) is a follow-up; before
Accepting, tune the clustering (threshold per language, the segmentation shift 0.1 s, VAD gating,
min-cluster-size) on a larger set until ≥ 3 of 4 AMI meetings reach ≤ 20%, and fill the device rows.

## Consequences
- + Privacy invariant is enforced by structure: the engine returns `SpeakerTurn`s only; the step's
  scratch directory is removed on every outcome; no table has an embedding column (test AC4).
- + Works with any engine (fake in tests) so the pipeline, UI and export are shippable before the
  native piece.
- − DER on short, similar-voice meetings (IS1009a) is poor; users can still rename/merge by hand.
- − Two small ONNX models (≈ 31 MB) join the model catalog (MDL-01) when the engine lands.
- Licences: pyannote-segmentation-3.0 MIT, WeSpeaker/3D-Speaker models Apache-2.0/CC-BY per card
  (SEC-05 to confirm before shipping).

## Revisit when
The device rows are filled, a larger test set is run, or sherpa-onnx ships a centroid-linkage
clustering option.
