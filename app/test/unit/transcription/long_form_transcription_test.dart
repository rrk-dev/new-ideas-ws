import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart' as db_enums;
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/stt_engine.dart';
import 'package:vaultvoice/core/platform/vad_engine.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_engines.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_orchestrator.dart';
import 'package:vaultvoice/features/pipeline/data/steps/step_support.dart';
import 'package:vaultvoice/features/pipeline/domain/heavy_model_gate.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/transcription/data/live_transcriber.dart';
import 'package:vaultvoice/features/transcription/data/live_transcription_service.dart';
import 'package:vaultvoice/features/transcription/data/window_result_cache.dart';
import 'package:vaultvoice/features/transcription/domain/window_planner.dart';

import '../../db/db_test_utils.dart';
import '../../fakes/fake_clock.dart';
import '../../fakes/fake_vault_writer.dart';
import '../../fakes/fake_windowed_stt_engine.dart';
import '../pipeline/pipeline_test_utils.dart';

const _chunkMs = 30000;

/// Recording [id] with [n] back-to-back 30 s chunks and VAD speech of 4 s
/// every 5 s (stored `speech_segments`, as AUD-03 will write them).
Future<void> _seedLongRecording(
  VaultVoiceDatabase db,
  String id, {
  required int n,
  bool withSpeech = true,
}) async {
  await seedRecording(db, id);
  for (var seq = 0; seq < n; seq++) {
    expectOk(
      await db.recordingsRepository.upsertChunk(
        AudioChunksCompanion.insert(
          recordingId: id,
          seq: seq,
          path: p.join('audio', id, 'chunk_$seq.wav'),
          sampleRate: 16000,
          startMs: seq * _chunkMs,
          endMs: (seq + 1) * _chunkMs,
          bytes: 1,
        ),
      ),
    );
  }
  if (!withSpeech) return;
  expectOk(
    await db.recordingsRepository.replaceSpeechSegments(id, [
      for (var t = 0; t + 4000 <= n * _chunkMs; t += 5000)
        SpeechSegmentsCompanion.insert(
          recordingId: id,
          startMs: t,
          endMs: t + 4000,
        ),
    ]),
  );
}

List<SpeechSpan> _spans(int totalMs) => [
  for (var t = 0; t + 4000 <= totalMs; t += 5000) SpeechSpan(t, t + 4000),
];

class _FakeVad implements VadEngine {
  _FakeVad(this.spans);

  final List<SpeechSpan> spans;
  int calls = 0;

  @override
  Future<Result<List<SpeechSpan>>> detect(
    List<VadChunk> chunks, {
    required String modelPath,
    CancelToken? cancel,
  }) async {
    calls++;
    return Ok(spans);
  }

  @override
  Future<void> dispose() async {}
}

/// Installs a (dummy) VAD model: the transcribe step asks VAD only when a
/// VAD model is installed and silence skipping is on (AUD-03).
Future<void> _installVad(VaultVoiceDatabase db, String root) async {
  const rel = 'models/silero/ggml-silero-v6.2.0.bin';
  File(p.join(root, rel))
    ..createSync(recursive: true)
    ..writeAsBytesSync(const [0]);
  expectOk(
    await db.modelsRepository.upsert(
      ModelsInstalledCompanion.insert(
        id: 'silero-vad-v6.2.0',
        type: db_enums.ModelType.vad,
        version: '1',
        path: rel,
        sha256: 'x',
        size: 1,
        installedAt: t0,
      ),
    ),
  );
}

void main() {
  late VaultVoiceDatabase db;
  late String root;

  setUp(() async {
    db = memoryDb();
    root = tempPaths().root;
    await seedVaultTarget(db);
  });

  Future<PipelineOrchestrator> start(
    WindowedSttEngine stt, {
    VadEngine? vad,
    WindowResultCache cache = const NoWindowResultCache(),
  }) async {
    final o = PipelineOrchestrator.withEngines(
      db: db,
      paths: StoragePaths(root),
      engines: PipelineEngines(
        stt: stt,
        llm: ScriptedLlm(),
        vault: FakeVaultWriter(),
        clock: FakeClock(t0),
        gate: HeavyModelGate(release: (_) async {}),
        vad: vad,
        windowCache: cache,
      ),
      newId: sequentialIds(),
    );
    await o.start();
    return o;
  }

  Future<List<TranscriptSegmentRow>> segments(String jobId) async {
    final r = await db.transcriptsRepository.segments(transcriptIdFor(jobId));
    final List<TranscriptSegmentRow> rows = expectOk(r);
    return rows;
  }

  test(
    '[STT-04/AC1] 2-hour recording: bounded windows, killed mid-job, '
    'resumes at the next window with no duplicate or lost segments',
    () async {
      await _seedLongRecording(db, 'r1', n: 240); // 2 h
      final plan = planWindows(
        chunks: [
          for (var s = 0; s < 240; s++)
            PlanChunk(
              seq: s,
              path: p.join(root, 'audio', 'r1', 'chunk_$s.wav'),
              startMs: s * _chunkMs,
              endMs: (s + 1) * _chunkMs,
            ),
        ],
        speech: _spans(240 * _chunkMs),
      );
      final total = plan.windows.length;
      expect(total, greaterThan(60));

      // Run 1: killed while decoding window 10.
      final first = FakeWindowedSttEngine(blockOn: 10);
      var o = await start(first);
      final jobId = expectOk(await o.enqueue('r1'));
      await until(() => first.blocked, timeout: const Duration(seconds: 20));
      await o.dispose(); // "app killed"
      expect(first.calls, hasLength(11));
      final afterKill = await segments(jobId);
      final windowsDone = {for (final s in afterKill) s.seq ~/ 100000};
      expect(windowsDone, {for (var i = 0; i < 10; i++) i});
      final job = await loadJob(db, jobId);
      expect(job.checkpoint['nextWindow'], 10);

      // Every decode is one bounded window (≤ 120 s), handed over as ranges —
      // peak memory per call cannot grow with the recording length.
      for (final call in first.calls) {
        final ms = call.fold<int>(0, (a, r) => a + r.endMs - r.startMs);
        expect(ms, inInclusiveRange(1, 120000));
      }

      // Run 2: relaunch on the same DB.
      final second = FakeWindowedSttEngine();
      o = await start(second);
      addTearDown(o.dispose);
      await o.whenIdle();
      expect((await loadJob(db, jobId)).state, JobState.done);
      expect(
        second.calls,
        hasLength(total - 10),
        reason: 'resumes at window 10',
      );
      expect(
        second.calls.first.map((r) => r.startMs + r.recordingOffsetMs),
        plan.windows[10].ranges.map((r) => r.recordingStartMs),
      );
      // Continuity: window 10's prompt carries the tail of window 9.
      expect(second.options.first.initialPrompt, contains('w9r0'));

      final rows = await segments(jobId);
      final seqs = rows.map((r) => r.seq).toList();
      expect(seqs.toSet(), hasLength(seqs.length), reason: 'no duplicates');
      expect(
        {for (final s in rows) s.seq ~/ 100000},
        {for (var i = 0; i < total; i++) i},
      );
      // Timestamps are on the recording timeline and monotonic.
      for (var i = 1; i < rows.length; i++) {
        expect(rows[i].startMs, greaterThanOrEqualTo(rows[i - 1].startMs));
      }
      expect(rows.last.endMs, lessThanOrEqualTo(240 * _chunkMs));
    },
  );

  test(
    'guards drop hallucinations and repetition loops before storage',
    () async {
      await _seedLongRecording(db, 'r1', n: 2);
      TranscriptSegment seg(int ms, String text, {double ns = 0.01}) =>
          TranscriptSegment(
            start: Duration(milliseconds: ms),
            end: Duration(milliseconds: ms + 2000),
            text: text,
            noSpeechProb: ns,
            avgLogprob: ns > 0.5 ? -1.4 : -0.2,
          );
      final stt = FakeWindowedSttEngine(
        script: {
          0: [
            seg(0, 'Welcome to the planning meeting.'),
            seg(2000, 'Thanks for watching!'),
            seg(4000, 'go go go go go go go go go go go go'),
            seg(6000, 'mm hmm', ns: 0.9),
            seg(8000, 'Welcome to the planning meeting.'),
            seg(10000, 'First item is the release.'),
          ],
        },
      );
      final o = await start(stt);
      addTearDown(o.dispose);
      final jobId = expectOk(await o.enqueue('r1'));
      await o.whenIdle();
      final rows = await segments(jobId);
      expect(rows.where((r) => r.seq < 100000).map((r) => r.body), [
        'Welcome to the planning meeting.',
        'First item is the release.',
      ]);
    },
  );

  test('without stored speech the VAD engine runs once and its spans are '
      'stored; windows follow them', () async {
    await _seedLongRecording(db, 'r1', n: 4, withSpeech: false);
    await _installVad(db, root);
    final vad = _FakeVad(const [
      SpeechSpan(1000, 20000),
      SpeechSpan(21000, 34000),
      SpeechSpan(90000, 100000),
    ]);
    final stt = FakeWindowedSttEngine();
    final o = await start(stt, vad: vad);
    addTearDown(o.dispose);
    expectOk(await o.enqueue('r1'));
    await o.whenIdle();
    expect(vad.calls, 1);
    final stored = await db.recordingsRepository
        .watchSpeechSegments('r1')
        .first;
    expect(stored.map((s) => (s.startMs, s.endMs)), [
      (1000, 20000),
      (21000, 34000),
      (90000, 100000),
    ]);
    // Window 1: 1–34 s (1 s pause kept), crosses the chunk 0|1 boundary.
    expect(
      stt.calls.first.map((r) => (r.startMs, r.endMs, r.recordingOffsetMs)),
      [(1000, 30000, 0), (0, 4000, 30000)],
    );
    // Window 2: 90–100 s; the silence 34–90 s is never decoded.
    expect(stt.calls[1].map((r) => (r.startMs, r.endMs, r.recordingOffsetMs)), [
      (0, 10000, 90000),
    ]);
    expect(stt.calls, hasLength(2));
  });

  test('[STT-04/AC3] near-real-time: windows decoded while recording are '
      'reused, so after stop only the last window is left', () async {
    // A 30-min recording, simulated in 30 s steps.
    const n = 60;
    await _seedLongRecording(db, 'r1', n: n);
    final cache = FileWindowResultCache(root);
    final live = FakeWindowedSttEngine();
    final transcriber = LiveTranscriber(
      recordingId: 'r1',
      engine: live,
      cache: cache,
      modelId: const PipelineConfig().sttModelId,
      language: const PipelineConfig().sttLanguage,
    );
    for (var k = 1; k <= n; k++) {
      final chunks = [
        for (var s = 0; s < k; s++)
          PlanChunk(
            seq: s,
            path: p.join(root, 'audio', 'r1', 'chunk_$s.wav'),
            startMs: s * _chunkMs,
            endMs: (s + 1) * _chunkMs,
          ),
      ];
      final horizon = k * _chunkMs;
      await transcriber.update(
        chunks: chunks,
        speech: [
          for (final s in _spans(horizon))
            if (s.endMs <= horizon) s,
        ],
        horizonMs: horizon,
      );
    }
    final liveWindows = live.calls.length;
    expect(liveWindows, greaterThan(10));

    final stt = FakeWindowedSttEngine();
    final o = await start(stt, cache: cache);
    addTearDown(o.dispose);
    final jobId = expectOk(await o.enqueue('r1'));
    await o.whenIdle();
    // Only what was still open at stop is decoded after stop: ≤ 1 window
    // (≤ 120 s of audio — seconds on a flagship, budget 60 s, device row).
    expect(stt.calls.length, lessThanOrEqualTo(1));
    final leftMs = stt.calls.fold<int>(
      0,
      (a, c) => a + c.fold<int>(0, (b, r) => b + r.endMs - r.startMs),
    );
    expect(leftMs, lessThanOrEqualTo(120000));
    final rows = await segments(jobId);
    expect({
      for (final r in rows) r.seq ~/ 100000,
    }, hasLength(liveWindows + stt.calls.length));
    // Cache is cleared once the job has the transcript.
    expect(File(p.join(root, 'work', 'live', 'r1.json')).existsSync(), isFalse);
  });

  test(
    'near-real-time cache is ignored when model or language differ',
    () async {
      final cache = FileWindowResultCache(root);
      await cache.store('r1', 'k', 'paramsA', [
        const TranscriptSegment(
          start: Duration.zero,
          end: Duration(seconds: 1),
          text: 'hi',
          tokens: [TranscriptToken(text: ' hi', p: 0.4)],
        ),
      ]);
      expect(await cache.lookup('r1', 'k', 'paramsB'), isNull);
      expect(await cache.lookup('r1', 'other', 'paramsA'), isNull);
      final hit = (await cache.lookup('r1', 'k', 'paramsA'))!;
      expect(hit.single.text, 'hi');
      expect(hit.single.tokens.single.p, 0.4);
      expect(() => cache.lookup('../x', 'k', 'p'), throwsArgumentError);
      await cache.clear('r1');
      expect(await cache.lookup('r1', 'k', 'paramsA'), isNull);
    },
  );

  test('near-real-time policy: tier ≥ Mid, charging or > 50 %; CPU when '
      'backgrounded on iOS', () {
    bool allowed(DeviceTier t, {bool charging = false, int battery = 80}) =>
        nearRealTimeAllowed(
          enabled: true,
          tier: t,
          charging: charging,
          batteryPercent: battery,
        );
    expect(allowed(DeviceTier.low), isFalse);
    expect(allowed(DeviceTier.mid), isTrue);
    expect(allowed(DeviceTier.high, battery: 50), isFalse);
    expect(allowed(DeviceTier.high, battery: 20, charging: true), isTrue);
    expect(
      nearRealTimeAllowed(
        enabled: false,
        tier: DeviceTier.high,
        charging: true,
        batteryPercent: 100,
      ),
      isFalse,
    );
    expect(
      liveUseGpu(isIos: true, inForeground: false, policyAllowsGpu: true),
      isFalse,
    );
    expect(
      liveUseGpu(isIos: true, inForeground: true, policyAllowsGpu: true),
      isTrue,
    );
    expect(
      liveUseGpu(isIos: false, inForeground: false, policyAllowsGpu: true),
      isTrue,
    );
    expect(
      liveUseGpu(isIos: false, inForeground: true, policyAllowsGpu: false),
      isFalse,
    );
  });

  test(
    'live transcriber stops when it may not run (heavy model busy)',
    () async {
      final live = FakeWindowedSttEngine();
      var allowed = false;
      final t = LiveTranscriber(
        recordingId: 'r1',
        engine: live,
        cache: const NoWindowResultCache(),
        modelId: 'm',
        language: 'en',
        canRun: () => allowed,
      );
      final chunks = [
        for (var s = 0; s < 6; s++)
          PlanChunk(
            seq: s,
            path: '/x/c$s.wav',
            startMs: s * _chunkMs,
            endMs: (s + 1) * _chunkMs,
          ),
      ];
      expect(
        await t.update(
          chunks: chunks,
          speech: _spans(180000),
          horizonMs: 180000,
        ),
        0,
      );
      allowed = true;
      expect(
        await t.update(
          chunks: chunks,
          speech: _spans(180000),
          horizonMs: 180000,
        ),
        greaterThan(0),
      );
      final n = live.calls.length;
      // A repeated update does not decode the same windows again.
      await t.update(chunks: chunks, speech: _spans(180000), horizonMs: 180000);
      expect(live.calls, hasLength(n));
    },
  );

  test('LiveTranscriptionService follows the DB while recording and stops '
      'on demand', () async {
    await seedRecording(db, 'r2');
    final engine = FakeWindowedSttEngine();
    final cache = FileWindowResultCache(root);
    final service = LiveTranscriptionService(
      recordings: db.recordingsRepository,
      paths: StoragePaths(root),
      allowed: () => true,
      create: (id) => LiveTranscriber(
        recordingId: id,
        engine: engine,
        cache: cache,
        modelId: 'm',
        language: 'en',
      ),
    );
    addTearDown(service.dispose);
    service
      ..watch('r2')
      ..watch('r2'); // idempotent
    expect(service.isWatching('r2'), isTrue);
    for (var seq = 0; seq < 4; seq++) {
      expectOk(
        await db.recordingsRepository.upsertChunk(
          AudioChunksCompanion.insert(
            recordingId: 'r2',
            seq: seq,
            path: p.join('audio', 'r2', 'chunk_$seq.wav'),
            sampleRate: 16000,
            startMs: seq * _chunkMs,
            endMs: (seq + 1) * _chunkMs,
            bytes: 1,
          ),
        ),
      );
      expectOk(
        await db.recordingsRepository.replaceSpeechSegments('r2', [
          for (final s in _spans((seq + 1) * _chunkMs))
            SpeechSegmentsCompanion.insert(
              recordingId: 'r2',
              startMs: s.startMs,
              endMs: s.endMs,
            ),
        ]),
      );
      await pumpEventQueue();
      await service.idle();
    }
    // 2 min recorded → the first windows (≥ 30 s each) are already decoded.
    expect(engine.calls.length, greaterThanOrEqualTo(2));
    for (final c in engine.calls) {
      expect(
        c.last.endMs + c.last.recordingOffsetMs,
        lessThanOrEqualTo(119000),
      );
    }
    await service.stop('r2');
    expect(service.isWatching('r2'), isFalse);
    final n = engine.calls.length;
    expectOk(
      await db.recordingsRepository.upsertChunk(
        AudioChunksCompanion.insert(
          recordingId: 'r2',
          seq: 4,
          path: p.join('audio', 'r2', 'chunk_4.wav'),
          sampleRate: 16000,
          startMs: 4 * _chunkMs,
          endMs: 5 * _chunkMs,
          bytes: 1,
        ),
      ),
    );
    await pumpEventQueue();
    expect(engine.calls, hasLength(n), reason: 'stopped: no more decoding');
  });
}
