# GATE-02 — Phase 2 scenario: on-device transcription and extraction

Task: [GATE-02](../../../tasks/13-milestones/GATE-02-phase2-on-device-ai.md).
Automated half: `app/integration_test/gate_02_pipeline_test.dart` (real orchestrator and
database file, scripted engines). The real-tiny-model run is
`app/integration_test/production_pipeline_test.dart` (see
[../device/FND-11.md](../device/FND-11.md)). Device rows:
[../device/GATE-02.md](../device/GATE-02.md), all ⏳.

Enterprise/MDM (LIC-04) is out of scope for the gates and is not checked here.

## Devices

One Low-tier and one High-tier device per platform, with the tier-default models
(LLM-07): VV-IOS-11 and VV-IOS-16, VV-AND-4G and VV-AND-FLG. See
[device-matrix.md](../../device-matrix.md).

## Steps and expected results

### S1 — Fresh install to JSON (AC1)

1. Install a fresh build with no models. Open Settings → Models.
2. Download the tier-default STT and LLM models and watch the progress.
3. Record 30 minutes of speech (a scripted reading is fine).
4. Stop and let processing finish; open the transcript and the extraction output.
5. Watch for OOM kills (Xcode memory gauge, `adb logcat | grep -i lowmemorykiller`).

Expected: download shows progress and verifies; a transcript appears; the extraction is
schema-valid JSON; the app is never killed for memory; STT and LLM are never loaded at
the same time.

Automated: `[GATE-02/AC1]` (60 chunks × 30 s, schema-valid, one heavy model at a time).

### S2 — Force-kill during transcription and extraction (AC2)

1. Record 10 minutes and start processing.
2. While the job shows Transcribing, force-kill the app, relaunch, wait for completion.
3. Repeat, killing while the job shows Extracting.

Expected: the job resumes from its checkpoint and completes; the transcript has no
duplicate segments; a kill during extraction does not transcribe again; one note.

Automated: `[GATE-02/AC2]` (both kill points).

### S3 — Airplane mode (AC3)

1. After the model download, turn on airplane mode (Wi-Fi and Bluetooth off).
2. Repeat S1 steps 3 to 4 with a 5 minute recording.

Expected: the pipeline completes; Settings → Network activity shows no new requests.

Automated: `[GATE-02/AC3]` (no HTTP client is created during a run).

### S4 — Benchmark report (AC4)

1. Run the STT WER/RTF and LLM tokens/s protocol from `vv-benchmark-eval` on each device
   with the QA-02 corpus (`tools/bench/stt_wer/`, `tools/bench/llm_select/`).
2. Record end-to-end processing time of the 30 minute recording per device.
3. Commit the report under `docs/` (for example `docs/perf-report.md`) with WER per
   model, RTF, tokens/s and the per-device processing time.

Expected: the report is committed and lists every device in S1.

### S5 — Repository check (AC5)

Run `python3 .agents/skills/vv-task-workflow/scripts/tasks.py verify --all-done --run` on
`main`. Expected: exit 0; all GATE-02 dependencies `done`.

## Pass rule

GATE-02 passes when S1 to S5 pass on all four devices and the report is committed.
