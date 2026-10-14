import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/features/library/data/search_repository.dart';
import 'package:vaultvoice/features/library/domain/library_models.dart';

import 'db_test_utils.dart';

Future<void> _recording(
  VaultVoiceDatabase db,
  String id, {
  String title = '',
  List<String> tags = const [],
}) => db
    .into(db.recordings)
    .insert(
      RecordingsCompanion.insert(
        id: id,
        title: Value(title),
        tags: Value(tags),
        createdAt: t0,
        status: RecordingStatus.recorded,
        source: RecordingSource.mic,
      ),
    );

Future<void> _transcript(
  VaultVoiceDatabase db,
  String recordingId,
  List<String> lines, {
  String? id,
}) async {
  final tid = id ?? 't-$recordingId';
  await db
      .into(db.transcripts)
      .insert(
        TranscriptsCompanion.insert(
          id: tid,
          recordingId: recordingId,
          modelId: 'm',
          language: 'en',
          createdAt: t0,
        ),
      );
  await db.batch(
    (b) => b.insertAll(db.transcriptSegments, [
      for (final (i, l) in lines.indexed)
        TranscriptSegmentsCompanion.insert(
          transcriptId: tid,
          seq: i,
          startMs: i * 1000,
          endMs: i * 1000 + 900,
          body: l,
        ),
    ]),
  );
}

Future<void> _extraction(
  VaultVoiceDatabase db,
  String recordingId,
  Map<String, Object?> json, {
  String? id,
  DateTime? at,
}) => db
    .into(db.extractions)
    .insertOnConflictUpdate(
      ExtractionsCompanion.insert(
        id: id ?? 'e-$recordingId',
        recordingId: recordingId,
        profileId: 'meeting',
        profileVersion: 1,
        modelId: 'm',
        json: json,
        valid: true,
        createdAt: at ?? t0,
      ),
    );

void main() {
  late VaultVoiceDatabase db;
  late SearchRepository search;

  setUp(() {
    db = memoryDb();
    search = SearchRepository(db);
  });

  Future<Set<String>> ids(String q) async => {
    for (final h in expectOk(await search.search(q))) h.recordingId,
  };

  Future<int> indexRows(String recordingId) async =>
      (await db
              .customSelect(
                'SELECT count(*) AS n FROM search_index WHERE recording_id = ?',
                variables: [Variable(recordingId)],
              )
              .getSingle())
          .read<int>('n');

  test('[APP-02] titles, tags, transcripts and extracted fields are '
      'searchable; hits carry a snippet', () async {
    await _recording(db, 'r1', title: 'Weekly sync', tags: ['team']);
    await _transcript(db, 'r1', ['We reviewed the budget.', 'Ship Friday.']);
    await _recording(db, 'r2', title: 'Plumber');
    await _extraction(db, 'r2', {
      'summary': 'Leaking tap',
      'action_items': [
        {'task': 'Call the landlord', 'owner': 'Priya', 'due': null},
      ],
    });

    expect(await ids('weekly'), {'r1'});
    expect(await ids('team'), {'r1'});
    expect(await ids('budget'), {'r1'});
    expect(await ids('landlord'), {'r2'});
    expect(await ids('priya'), {'r2'});
    expect(await ids('leak'), {'r2'}, reason: 'prefix match while typing');
    expect(await ids('budget friday'), {'r1'}, reason: 'terms are ANDed');
    expect(await ids('budget landlord'), isEmpty);

    final hit = expectOk(await search.search('budget')).single;
    expect(hit.kind, 'transcript');
    expect(hit.snippet, contains('${kSnippetOpen}budget$kSnippetClose'));
  });

  test('[APP-02] the triggers keep the index in sync with edits, '
      're-extraction and deletion', () async {
    await _recording(db, 'r1', title: 'Old title');
    await _transcript(db, 'r1', ['alpha', 'beta']);
    await _extraction(db, 'r1', {'summary': 'first version'});

    await (db.update(db.recordings)..where((r) => r.id.equals('r1'))).write(
      const RecordingsCompanion(title: Value('New title')),
    );
    expect(await ids('old'), isEmpty);
    expect(await ids('new'), {'r1'});

    // STT-06 edit of a segment.
    await (db.update(db.transcriptSegments)..where((s) => s.seq.equals(1)))
        .write(const TranscriptSegmentsCompanion(body: Value('gamma')));
    expect(await ids('beta'), isEmpty);
    expect(await ids('gamma'), {'r1'});

    // A newer extraction replaces the indexed fields.
    await _extraction(
      db,
      'r1',
      {'summary': 'second version'},
      id: 'e2',
      at: t0.add(const Duration(minutes: 1)),
    );
    expect(await ids('first'), isEmpty);
    expect(await ids('second'), {'r1'});

    await (db.delete(
      db.transcriptSegments,
    )..where((s) => s.seq.equals(0))).go();
    expect(await ids('alpha'), isEmpty);

    expect(await indexRows('r1'), 3);
    await (db.delete(db.recordings)..where((r) => r.id.equals('r1'))).go();
    expect(await indexRows('r1'), 0, reason: 'no FTS residue');
  });

  test('[APP-02] user input never breaks the FTS query syntax', () async {
    await _recording(db, 'r1', title: 'C++ "quoted" AND-or NEAR(x) cafés');
    for (final q in [
      '"',
      '""',
      '*',
      '-',
      'AND',
      'NEAR(',
      'c++',
      '"quoted',
      'and-or',
      '(x)',
      '   ',
      "o'neil",
    ]) {
      final r = await search.search(q);
      expect(r.isOk, isTrue, reason: q);
    }
    expect(await ids('"quoted'), {'r1'});
    expect(await ids('AND'), {'r1'}, reason: 'operator taken literally');
    expect(await ids('cafes'), {'r1'}, reason: 'diacritics removed');
    expect(await ids('   '), isEmpty);
  });

  test(
    '[APP-02/AC1] search over 1,000 recordings returns in < 200 ms',
    () async {
      const words = [
        'budget',
        'roadmap',
        'hiring',
        'customer',
        'release',
        'design',
        'review',
        'backlog',
        'deadline',
        'invoice',
        'warranty',
        'kitchen',
        'sprint',
        'feedback',
        'pricing',
        'vendor',
        'contract',
        'security',
        'onboarding',
        'analytics',
      ];
      String line(int r, int s) => [
        for (var w = 0; w < 15; w++) words[(r * 7 + s * 3 + w) % words.length],
      ].join(' ');
      await db.transaction(() async {
        for (var r = 0; r < 1000; r++) {
          final id = 'rec-$r';
          await _recording(db, id, title: 'Meeting $r', tags: ['t${r % 10}']);
          await _transcript(db, id, [for (var s = 0; s < 20; s++) line(r, s)]);
          await _extraction(db, id, {
            'summary': line(r, 99),
            'action_items': [
              {'task': 'Follow up ${words[r % words.length]}', 'owner': 'Sam'},
            ],
          });
        }
        await _recording(db, 'needle', title: 'Zebra crossing');
      });
      expect(
        (await db
                .customSelect('SELECT count(*) AS n FROM search_index')
                .getSingle())
            .read<int>('n'),
        22001,
      );

      await search.search('budget'); // warm-up (statement cache, pages)
      final times = <int>[];
      for (final q in ['budget', 'road', 'customer release', 'zebra', 'sam']) {
        final sw = Stopwatch()..start();
        final r = expectOk(await search.search(q));
        sw.stop();
        times.add(sw.elapsedMilliseconds);
        expect(r, isNotEmpty, reason: q);
      }
      expect(await ids('zebra'), {'needle'});
      expect(
        times.reduce((a, b) => a > b ? a : b),
        lessThan(200),
        reason: 'per-query ms: $times',
      );
    },
  );
}
