import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/native_failures.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/stt_engine.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_engines.dart';
import 'package:vaultvoice/features/pipeline/data/steps/step_support.dart';
import 'package:vaultvoice/features/pipeline/data/steps/transcribe_step.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_step.dart';
import 'package:vv_native/vv_native.dart';

import '../../db/db_test_utils.dart';
import '../../fakes/fake_stt_engine.dart';
import '../pipeline/pipeline_test_utils.dart';

class _Ctx implements StepContext {
  _Ctx(this.db, this.job);

  final VaultVoiceDatabase db;
  @override
  final JobSnapshot job;
  @override
  final CancelToken cancel = CancelToken();
  final List<double> progress = [];

  @override
  void reportProgress(double fraction) => progress.add(fraction);

  @override
  Future<void> saveCheckpoint(
    Map<String, Object?> checkpoint, {
    double? progress,
    Future<void> Function()? writes,
  }) => db.transaction(() async => await writes?.call());
}

void main() {
  test('segments land in transcript_segments with confidence + tokens; '
      'language option is passed to the engine', () async {
    final db = memoryDb();
    await seedRecordingWithChunks(db, 'r1', chunks: 2);
    final stt = FakeSttEngine(
      segments: const [
        TranscriptSegment(
          start: Duration(milliseconds: 100),
          end: Duration(milliseconds: 2500),
          text: 'ask not',
          avgLogprob: -0.25,
          noSpeechProb: 0.01,
          tokens: [
            TranscriptToken(
              text: ' ask',
              p: 0.9,
              start: Duration(milliseconds: 100),
              end: Duration(milliseconds: 400),
            ),
            TranscriptToken(text: ' not', p: 0.4),
          ],
        ),
      ],
    );
    final step = TranscribeStep(
      db: db,
      paths: StoragePaths('/tmp/vv-test'),
      stt: stt,
      config: const PipelineConfig(sttLanguage: 'de'),
    );
    final ctx = _Ctx(
      db,
      JobSnapshot(
        id: 'j1',
        recordingId: 'r1',
        state: JobState.transcribing,
        step: PipelineStepId.transcribe,
        createdAt: t0,
        updatedAt: t0,
      ),
    );
    expect(await step.run(ctx), isA<StepSucceeded>());
    expect(stt.lastOptions?.language, 'de');
    final rows = await (db.select(
      db.transcriptSegments,
    )..where((s) => s.transcriptId.equals(transcriptIdFor('j1')))).get();
    expect(rows, hasLength(2)); // one per chunk
    final first = rows.firstWhere((r) => r.seq == segmentSeq(0, 0));
    expect(first.startMs, 100);
    expect(first.endMs, 2500);
    expect(first.avgLogprob, closeTo(-0.25, 1e-9));
    final tokens = (jsonDecode(first.tokensJson!) as List)
        .cast<Map<String, Object?>>();
    expect(tokens.first, {
      'text': ' ask',
      'p': 0.9,
      't0_ms': 100,
      't1_ms': 400,
    });
    expect(tokens.last['t0_ms'], isNull);
    final second = rows.firstWhere((r) => r.seq == segmentSeq(1, 0));
    expect(second.startMs, 30000 + 100, reason: 'chunk offset applied');
  });

  test('segmentTokensJson is null without tokens', () {
    expect(
      segmentTokensJson(
        const TranscriptSegment(
          start: Duration.zero,
          end: Duration.zero,
          text: '',
        ),
      ),
      isNull,
    );
  });

  test('VV_E_* codes map to content-free failures in one place', () {
    expect(
      failureFromVvCode(VV_E_CANCELLED, operation: 'stt'),
      isA<CancelledFailure>(),
    );
    expect(
      failureFromVvCode(VV_E_OOM, operation: 'stt'),
      isA<OutOfMemoryFailure>(),
    );
    expect(failureFromVvCode(VV_E_IO, operation: 'stt'), isA<StorageFailure>());
    for (final code in [
      VV_E_MODEL_LOAD,
      VV_E_INVALID_ARG,
      VV_E_BACKEND,
      VV_E_BUSY,
      VV_E_INTERNAL,
      -99,
    ]) {
      final f = failureFromVvCode(code, operation: 'stt');
      expect(f, isA<NativeFailure>().having((n) => n.code, 'code', code));
      expect(f.message, startsWith('stt: '));
    }
  });
}
