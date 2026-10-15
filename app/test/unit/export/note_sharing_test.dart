import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/features/export/data/note_sharing.dart';
import 'package:vaultvoice/features/templates/domain/builtin_templates.dart';

import '../../db/db_test_utils.dart';
import '../pipeline/pipeline_test_utils.dart' show tempPaths;
import '../templates/alternate_outputs_test.dart' show logseqProblems;
import '../templates/template_fixtures.dart';

void main() {
  late VaultVoiceDatabase db;
  late StoragePaths paths;
  late NoteSharing sharing;

  Future<void> seed(
    String id, {
    String profileId = 'meeting',
    Map<String, Object?>? json,
  }) async {
    await seedRecording(db, id, createdAt: DateTime(2026, 10, 13, 14, 5));
    expectOk(
      await db.extractionsRepository.upsert(
        ExtractionsCompanion.insert(
          id: 'x-$id',
          recordingId: id,
          profileId: profileId,
          profileVersion: 1,
          modelId: 'llm',
          json: json ?? meetingFull(),
          valid: true,
          createdAt: DateTime(2026, 10, 13, 15),
        ),
      ),
    );
  }

  setUp(() {
    db = memoryDb();
    paths = tempPaths();
    sharing = NoteSharing(
      db: db,
      paths: paths,
      profiles: builtinProfiles,
      templates: builtinTemplates,
      appVersion: '1.0.0',
    );
  });

  test('no note yet → nothing to share', () async {
    await seedRecording(db, 'empty');
    expect(await sharing.available('empty'), isEmpty);
  });

  test('[EXP-08/AC1] a meeting note renders as a valid Logseq page and as '
      'plain Markdown', () async {
    await seed('r1');
    expect(await sharing.available('r1'), TemplateFlavor.values.toSet());

    final logseq = expectOk(await sharing.render('r1', TemplateFlavor.logseq));
    expect(logseqProblems(logseq.markdown), isEmpty);
    expect(logseq.markdown, contains('title:: Q4 Planning Sync'));
    expect(logseq.markdown, contains('  - TODO Update the client SDK'));
    expect(logseq.fileName, '2026-10-13-meeting-q4-planning-sync.md');

    final plain = expectOk(await sharing.render('r1', TemplateFlavor.plain));
    expect(plain.markdown, startsWith('# Q4 Planning Sync\n'));
    expect(plain.markdown, isNot(contains('[[')));
  });

  test('Obsidian = the exported vault note when it exists', () async {
    await seed('r2');
    final rendered = File(paths.renderedFile('r2'));
    await rendered.parent.create(recursive: true);
    await rendered.writeAsString('---\ntitle: "x"\n---\n\n# As exported\n');
    final note = expectOk(await sharing.render('r2', TemplateFlavor.obsidian));
    expect(note.markdown, '---\ntitle: "x"\n---\n\n# As exported\n');
    // Re-rendered from the extraction when the file is missing.
    await rendered.delete();
    final fresh = expectOk(await sharing.render('r2', TemplateFlavor.obsidian));
    expect(fresh.markdown, startsWith('---\ntitle: "Q4 Planning Sync"'));
  });

  test('custom profile: no Logseq variant; plain = vault note without '
      'front-matter', () async {
    await seed('r3', profileId: 'site-visit', json: const {'title': 'Site'});
    final rendered = File(paths.renderedFile('r3'));
    await rendered.parent.create(recursive: true);
    await rendered.writeAsString('---\na: "b"\n---\n\n# Site\n');
    expect(await sharing.available('r3'), {
      TemplateFlavor.obsidian,
      TemplateFlavor.plain,
    });
    expect(
      expectOk(await sharing.render('r3', TemplateFlavor.plain)).markdown,
      '# Site\n',
    );
    expect((await sharing.render('r3', TemplateFlavor.logseq)).isOk, isFalse);
  });

  test('share file goes to a fresh temp folder', () async {
    final tmp = Directory.systemTemp.createTempSync('vv_share_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final a = await NoteSharing.writeShareFile(
      tmp,
      const ShareableNote(markdown: 'A', fileName: 'a.md'),
    );
    final b = await NoteSharing.writeShareFile(
      tmp,
      const ShareableNote(markdown: 'B', fileName: 'b.md'),
    );
    expect(File(a).existsSync(), isFalse, reason: 'previous share removed');
    expect(File(b).readAsStringSync(), 'B');
    expect(p.basename(b), 'b.md');
  });

  test('stripFrontMatter', () {
    expect(stripFrontMatter('---\na: 1\n---\n\n# T\n'), '# T\n');
    expect(stripFrontMatter('# T\n'), '# T\n');
    expect(stripFrontMatter('---\nunclosed'), '---\nunclosed');
  });
}
