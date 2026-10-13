import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';

import '../db_test_utils.dart';

void main() {
  late VaultVoiceDatabase db;
  setUp(() => db = memoryDb());

  test('[FND-04/AC2] recordings CRUD', () async {
    final repo = db.recordingsRepository;
    await seedRecording(db, 'r1', source: RecordingSource.imported);

    final created = expectOk(await repo.get('r1'));
    expect(created.status, RecordingStatus.recorded);
    expect(created.source, RecordingSource.imported);
    expect(created.tags, isEmpty);
    expect(created.recovered, isFalse);
    expect(created.createdAt, t0);
    expect(created.createdAt.isUtc, isTrue);

    expectErr(
      await repo.create(
        RecordingsCompanion.insert(
          id: 'r1',
          createdAt: t0,
          status: RecordingStatus.recorded,
          source: RecordingSource.mic,
        ),
      ),
      'sqlite error',
    );

    expectOk(
      await repo.updateFields(
        'r1',
        RecordingsCompanion(
          title: const Value('Weekly sync'),
          tags: const Value(['work', 'sync']),
          stopReason: const Value(StopReason.callInterruption),
          consentConfirmedAt: Value(t0),
          durationMs: const Value(61000),
        ),
      ),
    );
    final updated = expectOk(await repo.get('r1'));
    expect(updated.title, 'Weekly sync');
    expect(updated.tags, ['work', 'sync']);
    expect(updated.stopReason, StopReason.callInterruption);
    expect(updated.consentConfirmedAt, t0);
    expect(updated.durationMs, 61000);

    expect(
      expectOk(await repo.findByStatus(RecordingStatus.recorded)).single.id,
      'r1',
    );
    expect(expectOk(await repo.findByStatus(RecordingStatus.failed)), isEmpty);

    expectOk(await repo.deleteById('r1'));
    expectErr(await repo.get('r1'), 'not found');
    expectErr(await repo.deleteById('r1'), 'not found');
    expectErr(
      await repo.updateFields(
        'r1',
        const RecordingsCompanion(title: Value('x')),
      ),
      'not found',
    );
  });

  test('[FND-04/AC2] recordings streams emit on every change', () async {
    final repo = db.recordingsRepository;
    final all = StreamProbe(
      repo.watchAll().map((rows) => rows.map((r) => r.id).toList()),
    );
    final one = StreamProbe(repo.watch('r2').map((r) => r?.title));
    expect(await all.settled, isEmpty);
    expect(await one.settled, isNull);

    await seedRecording(db, 'r1');
    expect(await all.settled, ['r1']);
    await seedRecording(db, 'r2', createdAt: t0.add(const Duration(hours: 1)));
    expect(await all.settled, ['r2', 'r1']); // newest first
    expect(await one.settled, '');
    expectOk(
      await repo.updateFields(
        'r2',
        const RecordingsCompanion(title: Value('Renamed')),
      ),
    );
    expect(await one.settled, 'Renamed');
    expectOk(await repo.deleteById('r2'));
    expect(await all.settled, ['r1']);
    expect(await one.settled, isNull);
  });

  test('[FND-04/AC2] audio chunks upsert by (recording, seq) and stream '
      'in order', () async {
    final repo = db.recordingsRepository;
    await seedRecording(db, 'r1');
    final chunks = StreamProbe(
      repo
          .watchChunks('r1')
          .map((rows) => [for (final c in rows) '${c.seq}:${c.bytes}']),
    );
    expect(await chunks.settled, isEmpty);

    AudioChunksCompanion chunk(int seq, int bytes) =>
        AudioChunksCompanion.insert(
          recordingId: 'r1',
          seq: seq,
          path: 'audio/r1/chunk_$seq.wav',
          sampleRate: 16000,
          startMs: seq * 30000,
          endMs: (seq + 1) * 30000,
          bytes: bytes,
        );
    expectOk(await repo.upsertChunk(chunk(1, 100)));
    expect(await chunks.settled, ['1:100']);
    expectOk(await repo.upsertChunk(chunk(0, 50)));
    expect(await chunks.settled, ['0:50', '1:100']);
    expectOk(await repo.upsertChunk(chunk(1, 200))); // overwrite, no dup
    expect(await chunks.settled, ['0:50', '1:200']);

    expectErr(
      await repo.upsertChunk(
        AudioChunksCompanion.insert(
          recordingId: 'missing',
          seq: 0,
          path: 'x',
          sampleRate: 16000,
          startMs: 0,
          endMs: 1,
          bytes: 1,
        ),
      ),
      'sqlite error',
    );
  });

  test('[FND-04/AC2] speech segments, markers and speakers', () async {
    final repo = db.recordingsRepository;
    await seedRecording(db, 'r1');

    final vad = StreamProbe(
      repo
          .watchSpeechSegments('r1')
          .map((r) => [for (final s in r) '${s.startMs}-${s.endMs}']),
    );
    expect(await vad.settled, isEmpty);
    expectOk(
      await repo.replaceSpeechSegments('r1', [
        SpeechSegmentsCompanion.insert(
          recordingId: 'r1',
          startMs: 20,
          endMs: 30,
        ),
        SpeechSegmentsCompanion.insert(recordingId: 'r1', startMs: 0, endMs: 9),
      ]),
    );
    expect(await vad.settled, ['0-9', '20-30']);
    expectOk(
      await repo.replaceSpeechSegments('r1', [
        SpeechSegmentsCompanion.insert(recordingId: 'r1', startMs: 5, endMs: 7),
      ]),
    );
    expect(await vad.settled, ['5-7']);

    final markers = StreamProbe(
      repo.watchMarkers('r1').map((r) => [for (final m in r) m.kind]),
    );
    expect(await markers.settled, isEmpty);
    final markerId = expectOk(
      await repo.addMarker(
        MarkersCompanion.insert(
          recordingId: 'r1',
          atMs: 1200,
          kind: MarkerKind.callInterruption,
        ),
      ),
    );
    expect(await markers.settled, [MarkerKind.callInterruption]);
    expectOk(await repo.deleteMarker(markerId));
    expect(await markers.settled, isEmpty);
    expectErr(await repo.deleteMarker(markerId), 'not found');

    final speakers = StreamProbe(
      repo
          .watchSpeakers('r1')
          .map((r) => [for (final s in r) '${s.label}=${s.displayName}']),
    );
    expect(await speakers.settled, isEmpty);
    expectOk(
      await repo.upsertSpeaker(
        SpeakersCompanion.insert(recordingId: 'r1', label: 'Speaker 1'),
      ),
    );
    expect(await speakers.settled, ['Speaker 1=null']);
    expectOk(
      await repo.upsertSpeaker(
        SpeakersCompanion.insert(
          recordingId: 'r1',
          label: 'Speaker 1',
          displayName: const Value('Alex'),
        ),
      ),
    );
    expect(await speakers.settled, ['Speaker 1=Alex']);
  });

  test(
    '[FND-04/AC2] deleting a recording cascades to every child row',
    () async {
      await seedRecording(db, 'r1');
      final repo = db.recordingsRepository;
      expectOk(
        await repo.upsertChunk(
          AudioChunksCompanion.insert(
            recordingId: 'r1',
            seq: 0,
            path: 'audio/r1/chunk_0.wav',
            sampleRate: 16000,
            startMs: 0,
            endMs: 1,
            bytes: 1,
          ),
        ),
      );
      expectOk(
        await db.transcriptsRepository.create(
          TranscriptsCompanion.insert(
            id: 't1',
            recordingId: 'r1',
            modelId: 'm',
            language: 'en',
            createdAt: t0,
          ),
        ),
      );
      expectOk(
        await db.transcriptsRepository.upsertSegments([
          TranscriptSegmentsCompanion.insert(
            transcriptId: 't1',
            seq: 0,
            startMs: 0,
            endMs: 1,
            body: 'hi',
          ),
        ]),
      );
      expectOk(
        await db.jobsRepository.create(
          JobsCompanion.insert(
            id: 'j1',
            recordingId: 'r1',
            kind: 'process',
            step: 'transcribe',
            status: 'queued',
            createdAt: t0,
            updatedAt: t0,
          ),
        ),
      );

      expectOk(await repo.deleteById('r1'));
      for (final table in [
        'audio_chunks',
        'transcripts',
        'transcript_segments',
        'jobs',
      ]) {
        final n = await db
            .customSelect('SELECT COUNT(*) AS n FROM $table')
            .getSingle();
        expect(n.read<int>('n'), 0, reason: table);
      }
    },
  );
}
