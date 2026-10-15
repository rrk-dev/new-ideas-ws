import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/platform/vault_path.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';
import 'package:vaultvoice/features/export/data/app_local_vault_writer.dart';

void main() {
  late Directory tmp;
  late Directory root;
  late AppLocalVaultWriter w;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('vv_vault_');
    root = Directory('${tmp.path}/vault');
    w = AppLocalVaultWriter.at(root);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  String read(String rel) => File('${root.path}/$rel').readAsStringSync();

  test('fallback target: access ok, writes create folders', () async {
    expect(await w.checkAccess(), VaultAccess.ok);
    final r = await w.write(
      const NoteDraft(relativePath: 'Meetings/n.md', markdown: '# Ü ✅'),
    );
    expect(r.isOk, isTrue);
    expect(r.valueOrNull!.location, startsWith('file://'));
    expect(read('Meetings/n.md'), '# Ü ✅');
    expect((await w.exists('Meetings/n.md')).valueOrNull, isTrue);
    expect((await w.exists('Meetings')).valueOrNull, isTrue);
    expect((await w.exists('nope.md')).valueOrNull, isFalse);
  });

  test(
    'no overwrite by default; overwrite truncates; no temp file left',
    () async {
      await w.write(
        const NoteDraft(relativePath: 'n.md', markdown: 'long text'),
      );
      final kept = await w.write(
        const NoteDraft(relativePath: 'n.md', markdown: 'x'),
      );
      expect(kept.failureOrNull, isA<VaultFileExistsFailure>());
      expect(read('n.md'), 'long text');

      final r = await w.write(
        const NoteDraft(relativePath: 'n.md', markdown: 'x'),
        overwrite: true,
      );
      expect(r.isOk, isTrue);
      expect(read('n.md'), 'x');
      expect(root.listSync().map((e) => e.path.split('/').last), [
        'n.md',
      ], reason: 'atomic temp file renamed away');
    },
  );

  test(
    '[EXP-05] a maximum-length (255-byte) filename can be written',
    () async {
      final name = '${'a' * 252}.md';
      final r = await w.write(NoteDraft(relativePath: name, markdown: 'x'));
      expect(r.isOk, isTrue);
      expect(read(name), 'x');
    },
  );

  test('list hides temp files, sorts, marks folders; delete', () async {
    await w.mkdirs('B');
    await w.write(const NoteDraft(relativePath: 'a.md', markdown: 'a'));
    File('${root.path}/.a.md.vvtmp').writeAsStringSync('partial');
    final entries = (await w.list('')).valueOrNull!;
    expect(
      [for (final e in entries) '${e.name}:${e.isDirectory}'],
      ['B:true', 'a.md:false'],
    );
    expect((await w.list('missing')).failureOrNull, isA<StorageFailure>());
    expect((await w.delete('a.md')).valueOrNull, isTrue);
    expect((await w.delete('a.md')).valueOrNull, isFalse);
    expect((await w.delete('B')).failureOrNull, isA<StorageFailure>());
    expect(
      (await w.write(const NoteDraft(relativePath: 'B', markdown: '')))
          .failureOrNull,
      isA<StorageFailure>(),
    );
  });

  test('paths cannot escape the vault root', () async {
    final r = await w.write(
      const NoteDraft(relativePath: '../outside.md', markdown: 'x'),
    );
    expect(r.failureOrNull, isA<StorageFailure>());
    expect(File('${tmp.path}/outside.md').existsSync(), isFalse);
    expect((await w.exists('/etc/passwd')).isOk, isFalse);
    expect((await w.mkdirs('a/../..')).isOk, isFalse);
    expect((await w.delete('..')).isOk, isFalse);
    expect((await w.list('..')).isOk, isFalse);
  });

  test(
    'unwritable root reports unavailable and content-free IO errors',
    () async {
      final file = File('${tmp.path}/blocker')..writeAsStringSync('');
      final blocked = AppLocalVaultWriter.at(Directory('${file.path}/vault'));
      expect(await blocked.checkAccess(), VaultAccess.unavailable);
      final r = await blocked.write(
        const NoteDraft(relativePath: 'secret-name.md', markdown: 'x'),
      );
      expect(r.failureOrNull, isA<StorageFailure>());
      expect(r.failureOrNull!.message, isNot(contains('secret')));
    },
  );

  test('root resolver is called once', () async {
    var calls = 0;
    final lazy = AppLocalVaultWriter(() async {
      calls++;
      return root;
    });
    await lazy.checkAccess();
    await lazy.write(const NoteDraft(relativePath: 'a.md', markdown: ''));
    expect(calls, 1);
  });

  group('VaultPath', () {
    test('accepts nested relative paths and exposes parts', () {
      final p = VaultPath.parse('A/B/c.md').valueOrNull!;
      expect(p.segments, ['A', 'B', 'c.md']);
      expect(p.name, 'c.md');
      expect(p.parent, ['A', 'B']);
      expect(p.value, 'A/B/c.md');
      expect(p.isRoot, isFalse);
      expect(p.toString(), isNot(contains('c.md')));
    });

    test('root only when allowed', () {
      expect(VaultPath.parse('').isOk, isFalse);
      final root = VaultPath.parse('', allowRoot: true).valueOrNull!;
      expect(root.isRoot, isTrue);
      expect(root.name, '');
      expect(root.parent, isEmpty);
    });

    test('rejects traversal and malformed paths', () {
      for (final bad in [
        '/a',
        'a/',
        '..',
        'a/./b',
        r'a\b',
        'a\nb',
        'a\u007Fb',
      ]) {
        expect(VaultPath.parse(bad).isOk, isFalse, reason: bad);
      }
    });
  });
}
