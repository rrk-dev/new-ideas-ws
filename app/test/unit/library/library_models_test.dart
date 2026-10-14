import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/features/library/data/library_providers.dart';
import 'package:vaultvoice/features/library/domain/extraction_summary.dart';
import 'package:vaultvoice/features/library/domain/library_models.dart';
import 'package:vaultvoice/features/library/domain/recording_detail.dart';
import 'package:vaultvoice/features/library/presentation/transcript_lines_screen.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';

import '../../db/db_test_utils.dart';

JobSnapshot _job(JobState state, {String recordingId = 'r'}) => JobSnapshot(
  id: 'j-$recordingId-${state.name}',
  recordingId: recordingId,
  state: state,
  step: PipelineStepId.transcribe,
  createdAt: t0,
  updatedAt: t0,
);

ExportInfo _export({bool written = true, bool failed = false}) => ExportInfo(
  targetId: 'v1',
  targetName: 'Vault',
  relPath: 'a.md',
  written: written,
  failed: failed,
  updatedAt: t0,
);

LibraryItem _item(
  String id, {
  String title = '',
  int day = 1,
  int seconds = 60,
  String? profileId,
  List<String> tags = const [],
  LibraryStatus status = LibraryStatus.exported,
}) => LibraryItem(
  id: id,
  title: title,
  createdAt: DateTime(2026, 10, day, 12),
  duration: Duration(seconds: seconds),
  status: status,
  profileId: profileId,
  tags: tags,
);

void main() {
  test('[APP-02] FTS terms quote everything, prefix the last term', () {
    expect(ftsTerms(''), isEmpty);
    expect(ftsTerms('   "  '), isEmpty);
    expect(ftsTerms('budget'), ['"budget"*']);
    expect(ftsTerms('call  sam'), ['"call"', '"sam"*']);
    expect(ftsTerms('a"b -x AND'), ['"a""b"', '"-x"', '"AND"*']);
  });

  test('[APP-02] status: capturing › job state › exports', () {
    LibraryStatus s(JobState? j, [List<ExportInfo> e = const []]) =>
        libraryStatus(
          capturing: false,
          job: j == null ? null : _job(j),
          exports: e,
        );
    expect(
      libraryStatus(capturing: true, job: null, exports: const []),
      LibraryStatus.recording,
    );
    expect(s(null), LibraryStatus.recorded);
    expect(s(JobState.queued), LibraryStatus.processing);
    expect(s(JobState.extracting), LibraryStatus.processing);
    expect(s(JobState.paused), LibraryStatus.processing);
    expect(s(JobState.waiting), LibraryStatus.waiting);
    expect(s(JobState.failed), LibraryStatus.failed);
    expect(s(JobState.done), LibraryStatus.processed);
    expect(s(JobState.done, [_export()]), LibraryStatus.exported);
    expect(
      s(JobState.done, [_export(written: false, failed: true)]),
      LibraryStatus.failed,
    );
    expect(s(JobState.cancelled), LibraryStatus.recorded);
  });

  group('[APP-02] filters and sort', () {
    final items = [
      _item('a', title: 'beta', seconds: 30, profileId: 'meeting'),
      _item(
        'b',
        title: 'Alpha',
        day: 5,
        seconds: 300,
        tags: ['work'],
        status: LibraryStatus.failed,
      ),
      _item('c', title: 'gamma', day: 9, seconds: 120, profileId: 'meeting'),
    ];
    List<String> ids(LibraryFilter f, {Map<String, double>? m}) => [
      for (final i in applyLibraryFilter(items, f, matches: m)) i.id,
    ];

    test('sort options', () {
      expect(ids(const LibraryFilter()), ['c', 'b', 'a']);
      expect(ids(const LibraryFilter(sort: LibrarySort.oldest)), [
        'a',
        'b',
        'c',
      ]);
      expect(ids(const LibraryFilter(sort: LibrarySort.longest)), [
        'b',
        'c',
        'a',
      ]);
      expect(ids(const LibraryFilter(sort: LibrarySort.title)), [
        'b',
        'a',
        'c',
      ]);
    });

    test('profile, tag, status and inclusive date range', () {
      expect(ids(const LibraryFilter(profileId: 'meeting')), ['c', 'a']);
      expect(ids(const LibraryFilter(tag: 'work')), ['b']);
      expect(ids(const LibraryFilter(statuses: {LibraryStatus.failed})), ['b']);
      expect(
        ids(
          LibraryFilter(from: DateTime(2026, 10, 5), to: DateTime(2026, 10, 9)),
        ),
        ['c', 'b'],
      );
    });

    test('search keeps only hits, in relevance order', () {
      expect(ids(const LibraryFilter(), m: {'a': -3, 'c': -1}), ['a', 'c']);
      expect(
        ids(
          const LibraryFilter(sort: LibrarySort.title),
          m: {'a': -3, 'c': -1},
        ),
        ['a', 'c'],
      );
    });
  });

  test('[APP-02] extraction summary follows the schema order', () {
    final rows = summarizeExtraction(
      {
        'summary': 'Short',
        'attendees': ['Priya', 'Sam'],
        'action_items': [
          {'task': 'Ship it', 'owner': 'Sam', 'due': null},
        ],
        'empty': <Object?>[],
        'count': 3,
      },
      order: ['attendees', 'summary'],
    );
    expect(
      [for (final r in rows) r.key],
      ['attendees', 'summary', 'action_items', 'empty', 'count'],
    );
    expect(rows[0].values, ['Priya', 'Sam']);
    expect(rows[2].values, ['Ship it · Sam']);
    expect(rows[3].values, isEmpty);
    expect(rows[4].values, ['3']);
    expect(humanizeFieldName('action_items'), 'Action items');
  });

  test('[APP-02] transcript position helpers', () {
    const lines = [
      TranscriptLine(startMs: 0, endMs: 900, text: 'a'),
      TranscriptLine(startMs: 5000, endMs: 9000, text: 'b'),
      TranscriptLine(startMs: 12000, endMs: 15000, text: 'c'),
    ];
    expect(lineIndexAt(lines, 0), 0);
    expect(lineIndexAt(lines, 4999), 0);
    expect(lineIndexAt(lines, 5000), 1);
    expect(lineIndexAt(lines, 99999), 2);
    expect(lineIndexAt(const [], 10), -1);
    expect(formatTimestamp(65000), '01:05');
    expect(formatTimestamp(3723000), '1:02:03');
  });

  test('[APP-02] library items join jobs, exports, targets and the newest '
      'extraction profile', () async {
    final db = memoryDb();
    await seedRecording(db, 'r1');
    await seedRecording(
      db,
      'r2',
      createdAt: t0.add(const Duration(hours: 1)),
      status: RecordingStatus.inProgress,
    );
    await db
        .into(db.jobs)
        .insert(
          JobsCompanion.insert(
            id: 'j1',
            recordingId: 'r1',
            kind: 'process',
            step: 'write',
            status: 'done',
            createdAt: t0,
            updatedAt: t0,
          ),
        );
    await db
        .into(db.extractions)
        .insert(
          ExtractionsCompanion.insert(
            id: 'e1',
            recordingId: 'r1',
            profileId: 'warranty',
            profileVersion: 1,
            modelId: 'm',
            json: const {},
            valid: true,
            createdAt: t0,
          ),
        );
    await db.vaultRepository.upsertTarget(
      VaultTargetsCompanion.insert(
        id: 'v1',
        platform: VaultPlatform.appLocal,
        displayName: 'Obsidian',
        handle: '/x',
        createdAt: t0,
      ),
    );
    await db.vaultRepository.upsertExport(
      ExportsCompanion.insert(
        id: 'r1.v1',
        recordingId: 'r1',
        targetId: 'v1',
        relPath: 'r1.md',
        contentHash: 'h',
        status: ExportStatus.written,
        updatedAt: t0,
      ),
    );
    final items = await loadLibraryItems(db);
    expect([for (final i in items) i.id], ['r2', 'r1']);
    expect(items[0].status, LibraryStatus.recording);
    expect(items[1].status, LibraryStatus.exported);
    expect(items[1].profileId, 'warranty');
    expect(items[1].exportedTo, ['Obsidian']);
    expect(items[1].job?.id, 'j1');
  });
}
