import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';

import '../db_test_utils.dart';

TranscriptSegmentsCompanion segment(
  String transcriptId,
  int seq,
  String text,
) => TranscriptSegmentsCompanion.insert(
  transcriptId: transcriptId,
  seq: seq,
  startMs: seq * 1000,
  endMs: seq * 1000 + 900,
  body: text,
);

JobsCompanion job(
  String id, {
  String recordingId = 'r1',
  String status = 'queued',
  int priority = 0,
  Duration age = Duration.zero,
}) => JobsCompanion.insert(
  id: id,
  recordingId: recordingId,
  kind: 'process',
  step: 'transcribe',
  status: status,
  priority: Value(priority),
  createdAt: t0.add(age),
  updatedAt: t0.add(age),
);

void main() {
  late VaultVoiceDatabase db;
  setUp(() async {
    db = memoryDb();
    await seedRecording(db, 'r1');
  });

  group('TranscriptsRepository', () {
    test('[FND-04/AC2] transcripts CRUD + latest stream', () async {
      final repo = db.transcriptsRepository;
      final latest = StreamProbe(repo.watchLatestFor('r1').map((t) => t?.id));
      expect(await latest.settled, isNull);
      expect(expectOk(await repo.latestFor('r1')), isNull);

      expectOk(
        await repo.create(
          TranscriptsCompanion.insert(
            id: 't1',
            recordingId: 'r1',
            modelId: 'ggml-base',
            language: 'en',
            createdAt: t0,
          ),
        ),
      );
      expect(await latest.settled, 't1');
      expectOk(
        await repo.create(
          TranscriptsCompanion.insert(
            id: 't2',
            recordingId: 'r1',
            modelId: 'ggml-small',
            language: 'de',
            createdAt: t0.add(const Duration(minutes: 5)),
          ),
        ),
      );
      expect(await latest.settled, 't2');
      expect(expectOk(await repo.latestFor('r1'))!.modelId, 'ggml-small');
      expect(expectOk(await repo.get('t1')).language, 'en');

      expectOk(await repo.deleteById('t2'));
      expect(await latest.settled, 't1');
      expectErr(await repo.get('t2'), 'not found');
      expectErr(await repo.deleteById('t2'), 'not found');
    });

    test('[FND-04/AC2] segments upsert idempotently, stream in seq order '
        'and keep the pre-edit text', () async {
      final repo = db.transcriptsRepository;
      expectOk(
        await repo.create(
          TranscriptsCompanion.insert(
            id: 't1',
            recordingId: 'r1',
            modelId: 'm',
            language: 'en',
            createdAt: t0,
          ),
        ),
      );
      final probe = StreamProbe(
        repo.watchSegments('t1').map((r) => [for (final s in r) s.body]),
      );
      expect(await probe.settled, isEmpty);

      expectOk(
        await repo.upsertSegments([
          segment('t1', 1, 'world'),
          segment('t1', 0, 'hello'),
        ]),
      );
      expect(await probe.settled, ['hello', 'world']);
      // Re-running the same chunk (resume) overwrites instead of appending.
      expectOk(await repo.upsertSegments([segment('t1', 1, 'world!')]));
      expect(await probe.settled, ['hello', 'world!']);
      expect(expectOk(await repo.segments('t1')), hasLength(2));

      final first = expectOk(await repo.segments('t1')).first;
      expectOk(await repo.editSegment(first.id, 'Hello'));
      expectOk(await repo.editSegment(first.id, 'Hello there'));
      expect(await probe.settled, ['Hello there', 'world!']);
      final edited = expectOk(await repo.segments('t1')).first;
      expect(edited.originalText, 'hello');
      expect(expectOk(await repo.get('t1')).edited, isTrue);

      expectErr(await repo.editSegment(9999, 'x'));
      expectErr(await repo.upsertSegments([segment('missing', 0, 'x')]));
    });
  });

  group('JobsRepository', () {
    test('[FND-04/AC2] jobs CRUD', () async {
      final repo = db.jobsRepository;
      expectOk(await repo.create(job('j1')));
      final created = expectOk(await repo.get('j1'));
      expect(created.progress, 0);
      expect(created.attempts, 0);
      expect(created.checkpoint, isEmpty);
      expect(created.notBefore, isNull);

      expectOk(
        await repo.updateFields(
          'j1',
          JobsCompanion(
            status: const Value('running'),
            progress: const Value(0.5),
            attempts: const Value(1),
            checkpoint: const Value({'nextChunk': 3, 'paramsHash': 'abc'}),
            notBefore: Value(t0.add(const Duration(seconds: 30))),
            errorCode: const Value('retryable'),
          ),
        ),
      );
      final updated = expectOk(await repo.get('j1'));
      expect(updated.status, 'running');
      expect(updated.progress, 0.5);
      expect(updated.checkpoint, {'nextChunk': 3, 'paramsHash': 'abc'});
      expect(updated.notBefore, t0.add(const Duration(seconds: 30)));
      expect(updated.errorCode, 'retryable');

      expectErr(await repo.create(job('j1')), 'sqlite error');
      expectErr(await repo.create(job('j9', recordingId: 'nope')));
      expectOk(await repo.deleteById('j1'));
      expectErr(await repo.get('j1'), 'not found');
      expectErr(
        await repo.updateFields('j1', const JobsCompanion(status: Value('x'))),
        'not found',
      );
      expectErr(await repo.deleteById('j1'), 'not found');
    });

    test(
      '[FND-04/AC2] jobs stream in queue order (priority, then age)',
      () async {
        final repo = db.jobsRepository;
        await seedRecording(db, 'r2');
        final all = StreamProbe(
          repo.watchAll().map((r) => [for (final j in r) j.id]),
        );
        final forR2 = StreamProbe(
          repo.watchForRecording('r2').map((r) => [for (final j in r) j.id]),
        );
        final one = StreamProbe(repo.watch('old').map((j) => j?.status));
        expect(await all.settled, isEmpty);

        expectOk(await repo.create(job('old')));
        expectOk(
          await repo.create(job('new', age: const Duration(minutes: 1))),
        );
        expect(await all.settled, ['old', 'new']);
        expectOk(
          await repo.create(
            job(
              'urgent',
              recordingId: 'r2',
              priority: 10,
              age: const Duration(minutes: 2),
            ),
          ),
        );
        expect(await all.settled, ['urgent', 'old', 'new']);
        expect(await forR2.settled, ['urgent']);
        expect(await one.settled, 'queued');

        expectOk(
          await repo.updateFields(
            'old',
            const JobsCompanion(status: Value('failed')),
          ),
        );
        expect(await one.settled, 'failed');
        final queued = expectOk(await repo.findByStatus({'queued'}));
        expect([for (final j in queued) j.id], ['urgent', 'new']);
      },
    );
  });
}
