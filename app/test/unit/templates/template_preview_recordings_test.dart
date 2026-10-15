import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/features/templates/data/template_editor_providers.dart';

import '../../db/db_test_utils.dart';

void main() {
  test(
    '[EXP-07] one preview entry per recording (latest extraction)',
    () async {
      final db = memoryDb();
      await seedRecording(db, 'r1');
      for (final (id, minutes) in [('e1', 0), ('e2', 5)]) {
        await db
            .into(db.extractions)
            .insert(
              ExtractionsCompanion.insert(
                id: id,
                recordingId: 'r1',
                profileId: 'meeting',
                profileVersion: 1,
                modelId: 'm',
                json: {'summary': id},
                valid: true,
                createdAt: t0.add(Duration(minutes: minutes)),
              ),
            );
      }
      final c = ProviderContainer(
        overrides: [vaultVoiceDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(c.dispose);
      final list = await c.read(
        templatePreviewRecordingsProvider('meeting').future,
      );
      expect(list.map((p) => p.recordingId), ['r1']);
      expect(list.single.data['summary'], 'e2');
    },
  );
}
