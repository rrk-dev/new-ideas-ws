import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/stt_engine.dart';
import 'package:vaultvoice/features/extraction/domain/long_transcript/extraction_prompts.dart';
import 'package:vaultvoice/features/extraction/domain/long_transcript/map_reduce_extractor.dart';
import 'package:vaultvoice/features/extraction/domain/long_transcript/partial_reducer.dart';
import 'package:vaultvoice/features/extraction/domain/long_transcript/transcript_chunker.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';
import 'package:vaultvoice/features/pipeline/data/long_transcript_strategy.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_engines.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_orchestrator.dart';
import 'package:vaultvoice/features/pipeline/data/steps/extract_step.dart';
import 'package:vaultvoice/features/pipeline/data/steps/render_write_steps.dart';
import 'package:vaultvoice/features/pipeline/data/steps/step_support.dart';
import 'package:vaultvoice/features/pipeline/data/steps/transcribe_step.dart';
import 'package:vaultvoice/features/pipeline/domain/heavy_model_gate.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';

import '../../db/db_test_utils.dart';
import '../../fakes/fake_clock.dart';
import '../../fakes/fake_vault_writer.dart';
import '../../fakes/oracle_llm_engine.dart';
import '../../helpers/synthetic_transcript.dart';
import '../templates/template_fixtures.dart' show profile;
import 'pipeline_test_utils.dart';

const _chunkMinutes = 10;

/// STT returning the synthetic meeting's lines of audio chunk n (10 min
/// each), as Whisper would without diarization (speaker inside the text).
class _MeetingStt implements SttEngine {
  _MeetingStt(this.lines);

  final List<TranscriptLine> lines;
  final List<String> calls = [];

  @override
  Future<Result<Transcript>> transcribe(
    String audioPath, {
    CancelToken? cancel,
    ProgressCallback? onProgress,
    SegmentCallback? onSegment,
    SttOptions options = const SttOptions(),
  }) async {
    calls.add(audioPath);
    final n = int.parse(p.basenameWithoutExtension(audioPath).split('_')[1]);
    final from = n * _chunkMinutes * 60000;
    final to = from + _chunkMinutes * 60000;
    return Ok(
      Transcript([
        for (final l in lines)
          if (l.startMs >= from && l.startMs < to)
            TranscriptSegment(
              start: Duration(milliseconds: l.startMs - from),
              end: Duration(milliseconds: l.startMs - from + 3000),
              text: '${l.speaker}: ${l.text}',
            ),
      ]),
    );
  }
}

final class _Prompts implements ExtractionPromptSource {
  @override
  String get systemPrompt =>
      'You extract structured data from transcripts. Output JSON only.';

  @override
  String get chunkSystemPrompt => systemPrompt;

  @override
  String transcript(List<TranscriptLine> lines) => transcriptBlock(lines);

  @override
  String singleUser(String block, {required bool withExamples}) =>
      '$block\nReturn the JSON now.';

  @override
  String chunkUser(String block, ChunkInfo info) =>
      'Part ${info.index + 1} of ${info.count}.\n$block\nReturn the JSON now.';

  @override
  String reduceUser(
    String field,
    List<String> parts, {
    required int maxLength,
    String? description,
  }) => 'Combine: ${parts.join(' | ')}';
}

ReduceStrategy _strategy(String f) => switch (f) {
  'title' || 'summary' => ReduceStrategy.llmSummarize,
  _ => ReduceStrategy.unionDedupe,
};

PipelineOrchestrator _orchestrator(
  VaultVoiceDatabase db,
  OracleLlmEngine llm,
  _MeetingStt stt,
) {
  final paths = tempPaths();
  const config = PipelineConfig();
  final clock = FakeClock(t0);
  final o = PipelineOrchestrator(
    db: db,
    paths: paths,
    clock: clock,
    gate: HeavyModelGate(release: (_) async {}),
    newId: sequentialIds(),
    steps: [
      TranscribeStep(
        db: db,
        paths: paths,
        stt: stt,
        config: config,
        clock: clock,
      ),
      ExtractStep(
        db: db,
        llm: llm,
        config: config,
        clock: clock,
        // Integration W3: LLM-06 runs through FND-11's ExtractionStrategy
        // seam (profile path: profile + grammar resolved first).
        profiles: (id) async => profile(id),
        grammars: (_) async => 'root ::= "{}"',
        strategy: LongTranscriptStrategy(
          LongTranscriptExtraction(
            extractor: MapReduceExtractor(
              engine: llm,
              tokenizer: WordTokenizer(),
            ),
            inputFor:
                (
                  profile,
                  lines, {
                  required modelId,
                  required maxTokens,
                  metadata,
                }) async => LongExtractionInput(
                  lines: lines,
                  prompts: _Prompts(),
                  spec: const MapReduceSpec(
                    schema: meetingTestSchema,
                    grammar: 'root ::= "{}"',
                    strategyFor: _strategy,
                  ),
                  tier: DeviceTier.mid,
                  maxTokens: maxTokens,
                  paramsKey: '$modelId|${profile.id}',
                ),
          ),
        ),
      ),
      RenderStep(db: db, paths: paths),
      WriteStep(db: db, paths: paths, vault: FakeVaultWriter(), clock: clock),
    ],
  );
  addTearDown(o.dispose);
  return o;
}

Future<void> _seed(VaultVoiceDatabase db, int chunks) async {
  await seedRecordingWithChunks(db, 'r1', chunks: chunks);
  await seedVaultTarget(db);
}

void main() {
  test('[LLM-06/AC1] 2-hour recording: killed during the map step, the '
      'relaunched job resumes at the next chunk and extracts every action '
      'item once', () async {
    final meeting = syntheticMeeting();
    final dir = Directory.systemTemp.createTempSync('vv_llm06_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/vaultvoice.sqlite');
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

    // Run 1: map chunk 4 hangs; the app is killed.
    final db1 = VaultVoiceDatabase(NativeDatabase(file));
    await _seed(db1, 120 ~/ _chunkMinutes);
    final llm1 = OracleLlmEngine(blockAt: 4);
    final o1 = _orchestrator(db1, llm1, _MeetingStt(meeting.lines));
    await o1.start();
    final id = expectOk(await o1.enqueue('r1'));
    await until(() => llm1.blocked, timeout: const Duration(seconds: 20));
    await o1.dispose();
    await db1.close();

    final db2 = VaultVoiceDatabase(NativeDatabase(file));
    addTearDown(db2.close);
    final killed = await loadJob(db2, id);
    expect(killed.state, JobState.extracting);
    final cp = MapReduceCheckpoint.fromJson(killed.checkpoint)!;
    expect(cp.results.keys, [0, 1, 2, 3]);
    final chunks = cp.chunks.length;
    expect(chunks, greaterThan(8));
    expect(killed.progress, greaterThan(0));

    // Run 2: recovered; only the remaining map chunks run.
    final llm2 = OracleLlmEngine();
    final stt2 = _MeetingStt(meeting.lines);
    final o2 = _orchestrator(db2, llm2, stt2);
    await o2.start();
    await o2.whenIdle();
    expect(stt2.calls, isEmpty, reason: 'resume at extract, no STT');
    expect(
      llm2.requests.where((r) => r.grammar != null),
      hasLength(chunks - 4),
    );
    final job = await loadJob(db2, id);
    expect(job.state, JobState.done);
    final ext = expectOk(
      await db2.extractionsRepository.get(extractionIdFor(id)),
    );
    expect(ext.valid, isTrue);
    final items = ext.json['action_items']! as List;
    expect(items, hasLength(meeting.actions.length));
    expect(actionItemRecall(items, meeting.actions, tokenJaccard), 1);
  });

  test(
    'a failure in a map chunk keeps finished chunks for the retry',
    () async {
      final meeting = syntheticMeeting(minutes: 60);
      final db = memoryDb();
      await _seed(db, 60 ~/ _chunkMinutes);
      final llm = OracleLlmEngine(failAt: {2: const StorageFailure('io')});
      final o = _orchestrator(db, llm, _MeetingStt(meeting.lines));
      await o.start();
      final id = expectOk(await o.enqueue('r1'));
      await until(() => llm.requests.length >= 3);
      await o.whenIdle();
      final job = await loadJob(db, id);
      // Retryable: back at the step boundary waiting for the backoff, with
      // the checkpoint of chunks 0–1 kept for the retry.
      expect(job.state, JobState.transcribed);
      expect(job.attempts, 1);
      expect(MapReduceCheckpoint.fromJson(job.checkpoint)!.results.keys, [
        0,
        1,
      ]);
    },
  );
}
