import 'package:characters/characters.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';
import 'package:vaultvoice/core/utils/ids.dart';
import 'package:vaultvoice/features/export/data/export_identity.dart';
import 'package:vaultvoice/features/export/domain/export_collision.dart';
import 'package:vaultvoice/features/export/domain/filename_pattern.dart';
import 'package:vaultvoice/features/export/domain/filename_sanitizer.dart';

import '../../db/db_test_utils.dart';
import '../../fakes/fake_vault_writer.dart';

String ch(int code) => String.fromCharCode(code);

final values = FilenameValues(
  recordingId: '0f8d2c1e-7a5b-4c3d-9e1f-2a3b4c5d6e7f',
  createdAt: DateTime(2026, 10, 3, 9, 7, 5),
  profileId: 'meeting',
  title: 'Q4 Planning Sync',
);

FilenamePattern pattern(String source) =>
    FilenamePattern.parse(source).valueOrNull!;

String failure(String source) =>
    FilenamePattern.parse(source).failureOrNull!.message;

void main() {
  group('[EXP-02/AC1] sanitization edge cases', () {
    test('reserved characters, controls and bidi marks are removed', () {
      expect(sanitizeSegment(r'a\b/c:d*e?f"g<h>i|j'), 'abcdefghij');
      expect(sanitizeSegment('C# [draft] ^1'), 'C draft 1');
      expect(
        sanitizeSegment('a${ch(0)}b${ch(0x1F)}c${ch(0x7F)}d${ch(0x85)}'),
        'abcd',
      );
      // RLO would display "note<RLO>dm.exe" as "noteexe.md".
      expect(sanitizeSegment('note${ch(0x202E)}dm.exe'), 'notedm.exe');
      expect(
        sanitizeSegment('x${ch(0x2066)}y${ch(0x200F)}z${ch(0xFEFF)}'),
        'xyz',
      );
      expect(sanitizeSegment('lone${ch(0xD800)}surrogate'), 'lonesurrogate');
    });

    test('whitespace collapses; leading/trailing dots and spaces trimmed', () {
      expect(sanitizeSegment('  a   b\tc  '), 'a b c');
      expect(sanitizeSegment('name. . .'), 'name');
      expect(sanitizeSegment('..hidden'), 'hidden');
      expect(sanitizeSegment('a\nb\r\nc'), 'a b c');
    });

    test('empty, "." and ".." become untitled', () {
      for (final s in ['', '   ', '.', '..', '...', '???', ' . ']) {
        expect(sanitizeSegment(s), kUntitled, reason: '"$s"');
      }
      expect(VaultFileName.parse('').name, 'untitled.md');
      expect(VaultFileName.parse('.md').name, 'untitled.md');
    });

    test('Windows device names are avoided', () {
      for (final n in ['CON', 'con', 'PRN', 'AUX', 'NUL', 'COM1', 'LPT9']) {
        expect(sanitizeSegment(n), '${n}_');
      }
      expect(sanitizeSegment('nul.txt'), 'nul_.txt');
      expect(VaultFileName.parse('CON.md').name, 'CON_.md');
      expect(VaultFileName.parse('aux.backup.md').name, 'aux_.backup.md');
      expect(sanitizeSegment('console'), 'console');
      expect(sanitizeSegment('COM10'), 'COM10');
    });

    test('NFC normalization', () {
      final decomposed = 'Cafe${ch(0x0301)}';
      expect(sanitizeSegment(decomposed), 'Caf${ch(0xE9)}');
      expect(pathKey('A/Cafe${ch(0x0301)}.md'), pathKey('a/caf${ch(0xE9)}.MD'));
    });

    test('≤ 255 UTF-8 bytes per segment, never splitting a grapheme', () {
      final ascii = VaultFileName.parse('a' * 300);
      expect(utf8Length(ascii.name), 255);
      expect(ascii.name, endsWith('.md'));

      final two = sanitizeSegment(ch(0xE9) * 200);
      expect(utf8Length(two), 254);
      expect(two.characters.length, 127);

      const family = '👩\u200D👩\u200D👧\u200D👦'; // 25 bytes, one grapheme
      expect(utf8Length(family), 25);
      final fam = VaultFileName.parse(family * 20);
      expect(utf8Length(fam.name), lessThanOrEqualTo(255));
      expect(fam.stem.characters.every((g) => g == family), isTrue);
      expect(fam.stem.characters.length, 10); // 250 bytes + ".md"

      final flags = sanitizeSegment('🇩🇪' * 40); // 8 bytes each
      expect(utf8Length(flags), 248);
      expect(flags.characters.every((g) => g == '🇩🇪'), isTrue);

      // Truncation never leaves a trailing dot/space.
      expect(sanitizeSegment('${'a' * 253} .b'), 'a' * 253);
      expect(truncateUtf8('abc', 0), '');
    });

    test('collision suffix keeps the byte limit and the extension', () {
      final long = VaultFileName.parse('${'é' * 200}.md');
      for (final n in [2, 10, 9999]) {
        final name = long.withSuffix(n);
        expect(utf8Length(name), lessThanOrEqualTo(255));
        expect(name, endsWith('-$n.md'));
      }
      expect(VaultFileName.parse('x.md').withSuffix(2), 'x-2.md');
    });

    test('emoji are allowed', () {
      expect(sanitizeSegment('Launch 🚀 plan'), 'Launch 🚀 plan');
    });
  });

  group('[EXP-02/AC1] pattern tokens', () {
    test('default pattern', () {
      expect(
        pattern(kDefaultFilenamePattern).render(values),
        '2026-10-03-meeting-q4-planning-sync.md',
      );
    });

    test('date formats, time, profile, id and sub-folders', () {
      expect(
        pattern(
          '{{date:YYYY}}/{{date:MM}}/{{date:YYYY-MM-DD_HH.mm.ss}} '
          '{{time}} {{profile}} {{id}}.md',
        ).render(values),
        '2026/10/2026-10-03_09.07.05 0907 meeting 0f8d2c1e.md',
      );
      expect(pattern('{{date}}').render(values), '2026-10-03.md');
      expect(
        pattern('Notes/{{title}}').render(values),
        'Notes/Q4 Planning Sync.md',
      );
    });

    test('token values never create folders or break the path', () {
      final v = FilenameValues(
        recordingId: 'r',
        createdAt: DateTime(2026),
        profileId: 'meeting',
        title: '../../etc/passwd: "x" <y>',
      );
      expect(pattern('{{title}}.md').render(v), 'etcpasswd x y.md');
      expect(pattern('{{title}}/n.md').render(v), 'etcpasswd x y/n.md');
      final con = FilenameValues(
        recordingId: 'r',
        createdAt: DateTime(2026),
        profileId: 'p',
        title: 'CON',
      );
      expect(pattern('{{title}}/{{title}}.md').render(con), 'CON_/CON_.md');
    });

    test('empty tokens drop one adjacent joiner; empty name → untitled', () {
      final noTitle = FilenameValues(
        recordingId: 'r1',
        createdAt: DateTime(2026, 1, 2),
        profileId: 'meeting',
      );
      expect(
        pattern(kDefaultFilenamePattern).render(noTitle),
        '2026-01-02-meeting.md',
      );
      expect(pattern('{{slug}}-{{date}}.md').render(noTitle), '2026-01-02.md');
      expect(pattern('{{slug}}').render(noTitle), 'untitled.md');
      expect(pattern('{{title}}/x').render(noTitle), 'untitled/x.md');
    });

    test('slug is ≤ 60 characters', () {
      final v = FilenameValues(
        recordingId: 'r',
        createdAt: DateTime(2026),
        profileId: 'p',
        title: 'word ' * 40,
      );
      final slug = pattern('{{slug}}').render(v);
      expect(slug.length - 3, lessThanOrEqualTo(60));
      expect(slug, isNot(contains('-.md')));
    });

    test('.md is enforced', () {
      expect(pattern('{{date}}.MD').render(values), '2026-10-03.md');
      expect(pattern('{{date}}.txt').render(values), '2026-10-03.txt.md');
    });

    test('invalid patterns are rejected with a column', () {
      expect(failure('x-{{nope}}.md'), contains(':3: unknown token "nope"'));
      expect(failure('{{date:YYYY'), contains(':1:'));
      expect(failure('{{date:YYYY/MM}}'), contains('for folders'));
      expect(failure('{{date:Q}}'), contains('YYYY MM DD'));
      expect(failure('{{date:}}'), contains('empty'));
      expect(failure('{{time:HH}}'), contains('no argument'));
      expect(failure('/abs.md'), contains('must not start'));
      expect(failure('dir/'), contains('must end with a file name'));
      expect(failure('a//b.md'), contains('folder names'));
      expect(failure('../x.md'), contains('folder names'));
      expect(failure('a/..'), contains('not file names'));
      expect(failure(' '), contains('empty'));
      expect(
        FilenamePattern.parse('{{x}}').failureOrNull,
        isA<FilenamePatternFailure>().having((f) => f.column, 'column', 1),
      );
    });
  });

  group('[EXP-02/AC1] collision modes', () {
    late FakeVaultWriter vault;
    setUp(() => vault = FakeVaultWriter());

    final desired = pattern('Notes/{{title}}.md').renderPath(values);

    Future<ExportPlan> plan(
      CollisionMode mode, {
      PriorExport? prior,
      Set<String> claimed = const {},
      String hash = 'h-new',
      String? onDisk,
      NotePath? want,
    }) async {
      final r = await planExport(
        desired: want ?? desired,
        contentHash: hash,
        mode: mode,
        exists: vault.exists,
        prior: prior,
        claimedByOthers: claimed,
        currentHash: onDisk == null ? null : (_) async => onDisk,
      );
      return r.valueOrNull!;
    }

    void occupy(String path) => vault.notes[path] = 'someone else';

    test('free path → new file in every mode', () async {
      for (final m in CollisionMode.values) {
        final p = await plan(m);
        expect(p, isA<WritePlan>());
        expect(p.relPath, 'Notes/Q4 Planning Sync.md');
        expect(p.reason, PlanReason.newFile);
        expect((p as WritePlan).overwrite, isFalse);
      }
    });

    test('suffix: -2, -3 … skipping taken and claimed paths', () async {
      occupy('Notes/Q4 Planning Sync.md');
      expect(
        (await plan(CollisionMode.suffix)).relPath,
        'Notes/Q4 Planning Sync-2.md',
      );
      occupy('Notes/Q4 Planning Sync-2.md');
      final p = await plan(
        CollisionMode.suffix,
        claimed: {'notes/q4 planning sync-3.MD'},
      );
      expect(p.relPath, 'Notes/Q4 Planning Sync-4.md');
      expect(p.reason, PlanReason.suffixed);
    });

    test('a path claimed by another recording is a collision even when '
        'its file is gone', () async {
      final p = await plan(
        CollisionMode.suffix,
        claimed: {'Notes/Q4 Planning Sync.md'},
      );
      expect(p.relPath, 'Notes/Q4 Planning Sync-2.md');
    });

    test(
      'overwrite never replaces a foreign file (falls back to suffix)',
      () async {
        occupy('Notes/Q4 Planning Sync.md');
        final p = await plan(CollisionMode.overwrite);
        expect(p.relPath, 'Notes/Q4 Planning Sync-2.md');
        expect((p as WritePlan).overwrite, isFalse);
        expect(vault.notes['Notes/Q4 Planning Sync.md'], 'someone else');
      },
    );

    test('skip leaves a foreign file alone', () async {
      occupy('Notes/Q4 Planning Sync.md');
      final p = await plan(CollisionMode.skip);
      expect(p, isA<SkipPlan>());
      expect(p.reason, PlanReason.skippedCollision);
    });

    group('re-export of the same recording (stable identity)', () {
      const prior = PriorExport(relPath: 'Old/Name.md', contentHash: 'h-old');

      test('updates our note in place in every mode, even if the pattern '
          'now renders another path', () async {
        vault.notes['Old/Name.md'] = 'ours';
        for (final m in CollisionMode.values) {
          final p = await plan(m, prior: prior);
          expect(p, isA<WritePlan>(), reason: m.name);
          expect(p.relPath, 'Old/Name.md');
          expect(p.reason, PlanReason.updateOwn);
          expect((p as WritePlan).overwrite, isTrue);
        }
      });

      test('identical content → nothing to write', () async {
        vault.notes['Old/Name.md'] = 'ours';
        final p = await plan(CollisionMode.suffix, prior: prior, hash: 'h-old');
        expect(p, isA<SkipPlan>());
        expect(p.reason, PlanReason.unchanged);
      });

      test('our note was deleted → re-created at the same path', () async {
        final p = await plan(CollisionMode.skip, prior: prior);
        expect(p.relPath, 'Old/Name.md');
        expect(p.reason, PlanReason.newFile);
      });

      test('user-edited note: overwrite replaces it, skip keeps it, suffix '
          'writes a new file', () async {
        vault.notes['Old/Name.md'] = 'edited by user';
        final o = await plan(
          CollisionMode.overwrite,
          prior: prior,
          onDisk: 'x',
        );
        expect(o.reason, PlanReason.overwroteEdited);
        expect((o as WritePlan).overwrite, isTrue);
        expect(o.relPath, 'Old/Name.md');

        final s = await plan(CollisionMode.skip, prior: prior, onDisk: 'x');
        expect(s, isA<SkipPlan>());
        expect(s.relPath, 'Old/Name.md');

        final n = await plan(CollisionMode.suffix, prior: prior, onDisk: 'x');
        expect(n.relPath, 'Notes/Q4 Planning Sync.md');
        expect(n.reason, PlanReason.newFile);

        final same = PriorExport(relPath: desired.path, contentHash: 'h-old');
        vault.notes[desired.path] = 'edited';
        final n2 = await plan(CollisionMode.suffix, prior: same, onDisk: 'x');
        expect(n2.relPath, 'Notes/Q4 Planning Sync-2.md');

        // Hash equal to what we wrote → not edited → normal update.
        final u = await plan(CollisionMode.skip, prior: prior, onDisk: 'h-old');
        expect(u.reason, PlanReason.updateOwn);
      });
    });

    test('vault errors propagate; exhausted suffixes fail', () async {
      vault.failWith(const VaultAccessFailure.revoked());
      final r = await planExport(
        desired: desired,
        contentHash: 'h',
        mode: CollisionMode.suffix,
        exists: vault.exists,
      );
      expect(r.failureOrNull, isA<VaultAccessFailure>());

      final full = await planExport(
        desired: desired,
        contentHash: 'h',
        mode: CollisionMode.suffix,
        exists: (_) async => const Ok(true),
        maxSuffix: 5,
      );
      expect(full.failureOrNull, isA<StorageFailure>());
    });
  });

  group('[EXP-02/AC1] stable identity via exports.rel_path', () {
    test('re-export updates the same file instead of duplicating', () async {
      final db = memoryDb();
      await seedRecording(db, 'rec-1');
      await seedRecording(db, 'rec-2');
      expectOk(
        await db.vaultRepository.upsertTarget(
          VaultTargetsCompanion.insert(
            id: 't1',
            platform: VaultPlatform.appLocal,
            displayName: 'Vault',
            handle: '/vault',
            createdAt: t0,
          ),
        ),
      );
      final vault = FakeVaultWriter();

      Future<String> export(String recordingId, FilenameValues v, String md) =>
          _export(db, vault, recordingId, v, md);

      final first = await export('rec-1', values, 'v1');
      expect(first, 'Notes/Q4 Planning Sync.md');

      // Another recording with the same title gets its own file.
      final other = await export(
        'rec-2',
        FilenameValues(
          recordingId: 'rec-2',
          createdAt: DateTime(2026, 10, 4),
          profileId: 'meeting',
          title: 'Q4 planning sync',
        ),
        'other',
      );
      expect(other, 'Notes/Q4 planning sync-2.md');

      // Re-extracted with a new title: same file, updated content.
      final again = await export(
        'rec-1',
        FilenameValues(
          recordingId: 'rec-1',
          createdAt: values.createdAt,
          profileId: 'meeting',
          title: 'Renamed',
        ),
        'v2',
      );
      expect(again, first);
      expect(vault.notes, {
        'Notes/Q4 Planning Sync.md': 'v2',
        'Notes/Q4 planning sync-2.md': 'other',
      });

      final id = await ExportIdentity.load(
        db.vaultRepository,
        recordingId: 'rec-1',
        targetId: 't1',
      );
      expect(id.prior!.relPath, first);
      expect(id.prior!.contentHash, fnv1a32('v2'));
      expect(id.claimedByOthers, {'Notes/Q4 planning sync-2.md'});
    });
  });
}

/// Minimal write flow (EXP-05 owns the real one): identity → plan → write
/// → record `exports` row.
Future<String> _export(
  VaultVoiceDatabase db,
  FakeVaultWriter vault,
  String recordingId,
  FilenameValues v,
  String markdown,
) async {
  final identity = await ExportIdentity.load(
    db.vaultRepository,
    recordingId: recordingId,
    targetId: 't1',
  );
  final hash = fnv1a32(markdown);
  final plan = (await planExport(
    desired: FilenamePattern.parse('Notes/{{title}}.md').valueOrNull!
        .renderPath(v),
    contentHash: hash,
    mode: CollisionMode.suffix,
    exists: vault.exists,
    prior: identity.prior,
    claimedByOthers: identity.claimedByOthers,
  )).valueOrNull!;
  if (plan is WritePlan) {
    expectOk(
      await vault.write(
        NoteDraft(relativePath: plan.relPath, markdown: markdown),
        overwrite: plan.overwrite,
      ),
    );
  }
  expectOk(
    await db.vaultRepository.upsertExport(
      ExportsCompanion.insert(
        id: '$recordingId.t1',
        recordingId: recordingId,
        targetId: 't1',
        relPath: plan.relPath,
        contentHash: hash,
        status: ExportStatus.written,
        attempts: const Value(1),
        updatedAt: t0,
      ),
    ),
  );
  return plan.relPath;
}
