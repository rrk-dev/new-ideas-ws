# STT-05 — On-Device Speaker Diarization

**Workstream:** STT | **Phase:** 2–3 | **Size:** L | **Depends on:** STT-04 | **Source:** Gap (Meeting profile promises "attendees" and task assignment; Whisper has no speaker labels)
**Status:** todo
**Skills:** vv-task-workflow, vv-whisper-stt, vv-decision-records, vv-benchmark-eval, vv-native-build, vv-ffi-bridge, vv-pipeline-orchestrator, vv-model-delivery, vv-local-database, vv-flutter-architecture, vv-markdown-vault-export, vv-testing

## Goal
Label transcript segments by speaker ("Speaker 1/2/…") so the LLM can attribute decisions and action items.

## Scope
- [ ] Spike: sherpa-onnx speaker diarization (pyannote segmentation + speaker embedding models) vs whisper.cpp tinydiarize vs simpler embedding clustering. Measure DER, speed, model size.
- [ ] Integrate chosen approach natively; align speaker turns with Whisper segments.
- [ ] UI to rename speakers ("Speaker 2 → Priya"); names persist per recording and flow into Markdown.
- [ ] **No voice enrollment / voiceprints.** Speaker embeddings are biometric data (e.g. BIPA, GDPR special category): compute them transiently for clustering only, never persist them, delete them when the diarization step ends. Speakers are identified only by the user renaming "Speaker N".
- [ ] Make diarization optional (off for single-speaker profiles like voice notes / warranties).

## Acceptance Criteria
- DER ≤ 20% on 2–4 speaker meeting test set.
- Adds ≤ 30% to total STT processing time.
- Renamed speakers appear correctly in exported Markdown.
- No speaker embeddings remain on disk or in the DB after the step completes (automated check).
