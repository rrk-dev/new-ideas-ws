import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_engines.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_orchestrator.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_providers.dart';
import 'package:vaultvoice/features/pipeline/data/steps/step_support.dart';
import 'package:vaultvoice/features/pipeline/domain/heavy_model_gate.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/transcription/domain/transcript_view.dart';
import 'package:vaultvoice/features/transcription/presentation/transcript_providers.dart';

import '../../db/db_test_utils.dart';
import '../../fakes/fake_clock.dart';
import '../../fakes/fake_vault_writer.dart';
import '../pipeline/pipeline_test_utils.dart';

void main() {
  late VaultVoiceDatabase db;
  late ScriptedStt stt;
  late ScriptedLlm llm;
  late PipelineOrchestrator o;
  late ProviderContainer container;

  setUp(() async {
    db = memoryDb();
    await seedRecordingWithChunks(db, 'r1');
    await seedVaultTarget(db);
    stt = ScriptedStt();
    llm = ScriptedLlm();
    o = PipelineOrchestrator.withEngines(
      db: db,
      paths: tempPaths(),
      engines: PipelineEngines(
        stt: stt,
        llm: llm,
        vault: FakeVaultWriter(),
        clock: FakeClock(t0),
        gate: HeavyModelGate(release: (_) async {}),
      ),
      newId: sequentialIds(),
    );
    addTearDown(o.dispose);
    await o.start();
    container = ProviderContainer(
      overrides: [
        vaultVoiceDatabaseProvider.overrideWithValue(db),
        pipelineClientProvider.overrideWith((ref) async => o),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<TranscriptViewData> view() async {
    // Keep the auto-dispose provider alive while reading it.
    final sub = container.listen(transcriptViewProvider('r1'), (_, _) {});
    addTearDown(sub.close);
    await pumpEventQueue();
    final v = await container.read(transcriptViewProvider('r1').future);
    return v!;
  }

  test('[STT-06/AC2] edits persist (original kept) and the next extraction '
      'run uses the edited text without re-running STT', () async {
    final jobId = expectOk(await o.enqueue('r1'));
    await o.whenIdle();
    expect(stt.calls, hasLength(3));
    expect(llm.requests.single.prompt, contains('chunk_1'));

    final editor = container.read(transcriptEditorProvider('r1'));
    final v = await view();
    final second = v.segments[1];
    expectOk(await editor.editSegment(second.id, '  Edited by user  '));

    // Persisted: body changed, original kept, transcript flagged edited.
    final rows = expectOk(
      await db.transcriptsRepository.segments(transcriptIdFor(jobId)),
    );
    expect(rows[1].body, 'Edited by user');
    expect(rows[1].originalText, 'chunk_1');
    expect(
      expectOk(await db.transcriptsRepository.get(transcriptIdFor(jobId)))
          .edited,
      isTrue,
    );
    // A second edit keeps the *first* original.
    expectOk(await editor.editSegment(second.id, 'Edited twice'));
    final again = expectOk(
      await db.transcriptsRepository.segments(transcriptIdFor(jobId)),
    );
    expect(again[1].originalText, 'chunk_1');

    // Find & replace across the transcript.
    final replaced = expectOk(
      await editor.replaceAll(await view(), 'chunk', 'part'),
    );
    expect(replaced, 2);

    // Re-extract: pipeline rerun from extract.
    expectOk(await editor.reExtract());
    await o.whenIdle();
    expect(stt.calls, hasLength(3), reason: 'STT must not run again');
    expect(llm.requests, hasLength(2));
    final prompt = llm.requests.last.prompt;
    expect(prompt, contains('Edited twice'));
    expect(prompt, contains('part_0'));
    expect(prompt, contains('part_2'));
    expect(prompt, isNot(contains('chunk_')));
    expect((await loadJob(db, jobId)).state, JobState.done);
  });

  test(
    'replace is scoped to one transcript; a foreign segment rolls back',
    () async {
      final jobId = expectOk(await o.enqueue('r1'));
      await o.whenIdle();
      final segs = expectOk(
        await db.transcriptsRepository.segments(transcriptIdFor(jobId)),
      );
      final r = await db.transcriptsRepository.editSegments('other', {
        segs.first.id: 'x',
      });
      expect(r.isOk, isFalse);
      final after = expectOk(
        await db.transcriptsRepository.segments(transcriptIdFor(jobId)),
      );
      expect(after.first.body, 'chunk_0');
      expect(after.first.originalText, isNull);
    },
  );

  test('re-extract without a job fails cleanly', () async {
    final r = await container.read(transcriptEditorProvider('r1')).reExtract();
    expect(r.isOk, isFalse);
  });

  test(
    'view maps speakers to display names and hides consent markers',
    () async {
      final jobId = expectOk(await o.enqueue('r1'));
      await o.whenIdle();
      final segs = expectOk(
        await db.transcriptsRepository.segments(transcriptIdFor(jobId)),
      );
      await (db.update(db.transcriptSegments)
            ..where((s) => s.id.equals(segs.first.id)))
          .write(const TranscriptSegmentsCompanion(speaker: Value('S1')));
      expectOk(
        await db.recordingsRepository.upsertSpeaker(
          SpeakersCompanion.insert(
            recordingId: 'r1',
            label: 'S1',
            displayName: const Value('Priya'),
          ),
        ),
      );
      for (final (kind, at) in [
        (MarkerKind.user, 31000),
        (MarkerKind.consent, 0),
        (MarkerKind.callInterruption, 89000),
      ]) {
        expectOk(
          await db.recordingsRepository.addMarker(
            MarkersCompanion.insert(recordingId: 'r1', atMs: at, kind: kind),
          ),
        );
      }
      final v = await view();
      expect(v.segments.first.speaker, 'Priya');
      expect(v.segments[1].speaker, isNull);
      expect(
        [for (final m in v.markers) m.kind],
        [TranscriptMarkerKind.user, TranscriptMarkerKind.callInterruption],
      );
      // [STT-06/AC1] the user marker at 31 s sits after the 30 s segment.
      expect(
        [
          for (final i in v.items)
            switch (i) {
              SegmentItem(:final segment) => segment.text,
              MarkerItem(:final marker) => 'marker@${marker.atMs}',
            },
        ],
        ['chunk_0', 'chunk_1', 'marker@31000', 'chunk_2', 'marker@89000'],
      );
    },
  );
}
