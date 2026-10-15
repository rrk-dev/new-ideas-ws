import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/features/export/data/note_sharing.dart';
import 'package:vaultvoice/features/export/data/note_sharing_providers.dart'
    hide builtinTemplates;

import '../../db/db_test_utils.dart';
import '../pipeline/pipeline_test_utils.dart' show tempPaths;
import '../templates/template_fixtures.dart';

void main() {
  test(
    '[EXP-08] share availability updates when the extraction lands',
    () async {
      final db = memoryDb();
      await seedRecording(db, 'r1');
      final sharing = NoteSharing(
        db: db,
        paths: tempPaths(),
        profiles: builtinProfiles,
        templates: builtinTemplates,
        appVersion: '1.0.0',
      );
      final c = ProviderContainer(
        overrides: [
          vaultVoiceDatabaseProvider.overrideWithValue(db),
          noteSharingProvider.overrideWith((ref) async => sharing),
        ],
      );
      addTearDown(c.dispose);
      final sub = c.listen(shareableFormatsProvider('r1'), (_, _) {});
      addTearDown(sub.close);
      expect(await c.read(shareableFormatsProvider('r1').future), isEmpty);

      expectOk(
        await db.extractionsRepository.upsert(
          ExtractionsCompanion.insert(
            id: 'x1',
            recordingId: 'r1',
            profileId: 'meeting',
            profileVersion: 1,
            modelId: 'llm',
            json: meetingFull(),
            valid: true,
            createdAt: t0,
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(await c.read(shareableFormatsProvider('r1').future), isNotEmpty);
    },
  );
}
