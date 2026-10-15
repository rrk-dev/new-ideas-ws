# STT-05 — On-Device Speaker Diarization

**Workstream:** STT | **Phase:** 2–3 | **Size:** L | **Depends on:** STT-04 | **Source:** Gap (Meeting profile promises "attendees" and task assignment; Whisper has no speaker labels)
**Status:** review
**Skills:** vv-task-workflow, vv-whisper-stt, vv-decision-records, vv-benchmark-eval, vv-native-build, vv-ffi-bridge, vv-pipeline-orchestrator, vv-model-delivery, vv-local-database, vv-flutter-architecture, vv-markdown-vault-export, vv-testing

## Goal
Label transcript segments by speaker ("Speaker 1/2/…") so the LLM can attribute decisions and action items.

## Scope
- [x] Spike: sherpa-onnx speaker diarization (pyannote segmentation + speaker embedding models) vs whisper.cpp tinydiarize vs simpler embedding clustering. Measure DER, speed, model size.
- [x] Align speaker turns with Whisper segments (`DiarizationEngine` interface, `alignSpeakers`, `DiarizeStep` in the pipeline after STT).
- [~] deferred → STT-05b: integrate the chosen approach natively (sherpa-onnx/onnxruntime `vv_diar_*` in `native/bridge` + Dart FFI engine + model catalog entries); needs the native build and device runs, out of this PR's reach.
- [x] UI to rename speakers ("Speaker 2 → Priya"); names persist per recording and flow into Markdown.
- [x] **No voice enrollment / voiceprints.** Speaker embeddings are biometric data (e.g. BIPA, GDPR special category): compute them transiently for clustering only, never persist them, delete them when the diarization step ends. Speakers are identified only by the user renaming "Speaker N".
- [x] Make diarization optional (off for single-speaker profiles like voice notes / warranties).

## Acceptance Criteria
- DER ≤ 20% on 2–4 speaker meeting test set.
- Adds ≤ 30% to total STT processing time.
- Renamed speakers appear correctly in exported Markdown.
- No speaker embeddings remain on disk or in the DB after the step completes (automated check).

## Completion Notes
- **Agent:** GitHub Copilot CLI · **Branch:** fix/sttllm (PR with LLM-08; builds on origin/task/STT-05-diarization) · **Date:** 2026-10-15
- **Summary:** `core/platform/diarization_engine.dart` (`SpeakerTurn`, `DiarizationEngine`: turns only, embeddings never cross the interface); `features/transcription/domain/speaker_alignment.dart` (max-overlap, token-boundary split for ≥ 1 s changes, nearest turn in silence, edited segments never split); `pipeline/data/steps/diarize_step.dart` (optional per profile `stt.diarization` else setting `processing.diarization_default`, default off; "Speaker N" by first appearance; scratch dir removed on every outcome; commit in the step transaction); `TranscriptsRepository.applyDiarization`, `RecordingsRepository.replaceSpeakers/renameSpeaker/speakerNames`; `NoteInput.speakerNames` → `TemplateNoteRenderer` (transcript + `meta.speakers`) in the pipeline, review and share paths; `SpeakerNamesDialog` (transcript screen "Name speakers"). Bench: `tools/bench/diarization/{der.py,README.md}`, spikes in `tools/spikes/STT-05-diarization/`, ADR-STT-05 (Proposed). Tests: `test/unit/transcription/diarization_test.dart` (10), `test/widget/speaker_names_dialog_test.dart`, `tools/ci/tests/test_stt05_der.py`; fake `FakeDiarizationEngine`.
- **Host numbers (AMI, sherpa-onnx pyannote-seg-3.0 + WeSpeaker, pyannote-3.1 centroid clustering, auto speaker count):** DER TS3003a 16.4%, ES2004a 20.1%, EN2002a 26.4%, IS1009a 42.3% (mean 26.3%) → the ≤ 20% target is NOT met on the full set; sherpa's stock clustering was 46–66%. Cost 3–15% of audio duration on desktop CPU; Whisper time not measured.
- **Acceptance evidence:**
  - AC1: ⏳ test: [STT-05/AC1]; artifact: docs/adr/ADR-STT-05-diarization.md; device: docs/test-plans/device/STT-05.md
  - AC2: ⏳ device: docs/test-plans/device/STT-05.md
  - AC3: ✅ test: [STT-05/AC3]; device: docs/test-plans/device/STT-05.md
  - AC4: ✅ test: [STT-05/AC4]
- **Decisions:** ADR-STT-05-diarization (Proposed).
- **Follow-ups:** see below

## Follow-ups
- **STT-05b (native engine, not filed):** implement Option B in `native/bridge` (`vv_diar_*`, onnxruntime/sherpa-onnx, centroid-linkage AHC, transient embeddings zeroed at the end), Dart FFI `DiarizationEngine`, wire into `PipelineEngines.diarization` and `defaultSteps`, catalog the two ONNX models (≈ 31 MB, MDL-01). The step runs only when `engines.diarization != null`, so nothing is user-visible until then.
- **DER (AC1) gap:** tune threshold / shift 0.1 s / VAD gating / min-cluster-size on a bigger set until ≥ 3 of 4 AMI meetings are ≤ 20%; fix the top-k (speaker count given) collapse seen in the Python port on 3 meetings; IS1009a collapses to one speaker.
- **Time (AC2) gap:** measure the ≤ 30% STT overhead on devices; host Whisper comparison missing.
- Speaker merge/split UI and a diarization settings toggle surface (setting exists; profile editor already has "Several speakers").
- SEC-05: confirm licences of pyannote-segmentation-3.0 and the WeSpeaker model before catalog entry.
