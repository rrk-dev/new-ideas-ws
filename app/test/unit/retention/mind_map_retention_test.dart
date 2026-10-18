import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/features/retention/data/recording_purger.dart';

import '../../db/db_test_utils.dart';
import 'retention_fixtures.dart';

void main() {
  late Directory tmp;
  late StoragePaths paths;
  late VaultVoiceDatabase db;
  late RecordingPurger purger;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('vv_map01_');
    paths = StoragePaths(p.join(tmp.path, 'vv'));
    db = memoryDb();
    purger = RecordingPurger(db, paths);
  });
  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  Future<int> maps(String id) async =>
      (await db
              .customSelect(
                'SELECT count(*) AS n FROM mind_maps WHERE recording_id = ?',
                variables: [Variable(id)],
              )
              .getSingle())
          .read<int>('n');

  test('[MAP-01/AC6] deleting a recording removes its mind map and leaves '
      'the others', () async {
    await seedFullRecording(db, paths, 'r1');
    await seedFullRecording(db, paths, 'r2');
    expect(await maps('r1'), 1);
    expectOk(await purger.purge('r1'));
    expect(await maps('r1'), 0);
    expect(await maps('r2'), 1);
  });

  test('[MAP-01/AC6] expiring the transcript while keeping the audio '
      'removes the mind map', () async {
    await seedFullRecording(db, paths, 'r1');
    expectOk(await purger.purge('r1', scope: PurgeScope.transcripts));
    expect(await maps('r1'), 0);
    expect((await rowsReferencing(db, 'r1'))['audio_chunks'], greaterThan(0));
  });

  test(
    '[MAP-01/AC6] the map is not searchable (not in search_index)',
    () async {
      await seedFullRecording(db, paths, 'r1');
      await createSearchIndex(db);
      await indexRecording(db, 'r1');
      final kinds = await db
          .customSelect('SELECT DISTINCT kind FROM search_index')
          .get();
      expect(
        kinds.map((r) => r.read<String>('kind')),
        isNot(contains('mind_map')),
      );
    },
  );
}
