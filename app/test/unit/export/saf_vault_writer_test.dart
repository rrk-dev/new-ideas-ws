import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';
import 'package:vaultvoice/features/export/data/pigeon/saf_api.g.dart';
import 'package:vaultvoice/features/export/data/saf_vault_writer.dart';
import 'package:vaultvoice/features/export/data/vault_platform_errors.dart';
import 'package:vaultvoice/features/export/domain/vault_access_guard.dart';
import 'package:vaultvoice/features/export/domain/vault_folder.dart';

import '../../fakes/fake_saf_host_api.dart';

const _vault =
    'content://com.android.externalstorage.documents/tree/primary%3ADocuments%2FObsidian%2FWork';
const _other =
    'content://com.android.externalstorage.documents/tree/1234-ABCD%3AVault';

const _note = NoteDraft(
  relativePath: 'Meetings/2026-10-12-meeting-standup.md',
  markdown: '---\ntitle: "Standup ✅"\n---\n\n# Standup\n',
);

void main() {
  late FakeSafHostApi host;

  setUp(() => host = FakeSafHostApi());

  group('persistent access', () {
    test('[EXP-03/AC1] a picked folder stays writable after an app restart '
        'without re-picking', () async {
      host.nextPick = SafTree(treeUri: _vault, displayName: 'Work');
      final folder = (await SafFolderAccess(api: host).pick()).valueOrNull!;
      expect(folder.kind, VaultTargetKind.saf);
      expect(folder.handle, _vault);
      expect(folder.displayName, 'Work');

      // "Restart": every Dart object is gone; only the stored handle and the
      // OS grant table (the fake host) survive.
      final restarted = SafFolderAccess(api: host);
      expect((await restarted.persistedTrees()).valueOrNull, [_vault]);
      expect(await restarted.checkAccess(folder), VaultAccess.ok);
      final written = await restarted.writerFor(folder).write(_note);
      expect(written.isOk, isTrue);
      expect(host.pickCalls, hasLength(1), reason: 'no second picker');
    });

    test('[EXP-03/AC1] a revoked grant is detected and re-granted at the '
        'previous location', () async {
      host.grant(_vault);
      const folder = VaultFolder(kind: VaultTargetKind.saf, handle: _vault);
      final access = SafFolderAccess(api: host);
      final guard = VaultAccessGuard(access);
      expect(await guard.check(folder), VaultAccessAction.none);

      host.persisted.remove(_vault); // user revoked in system settings
      expect(await access.checkAccess(folder), VaultAccess.revoked);
      expect(await guard.check(folder), VaultAccessAction.promptRegrant);
      final denied = await access.writerFor(folder).write(_note);
      expect(denied.failureOrNull, isA<VaultAccessFailure>());
      expect(
        (denied.failureOrNull! as VaultAccessFailure).access,
        VaultAccess.revoked,
      );

      host.nextPick = SafTree(treeUri: _vault, displayName: 'Work');
      final regranted = await guard.regrant(folder);
      expect(host.pickCalls.last, _vault, reason: 'picker opens at old folder');
      expect(regranted.valueOrNull?.handle, _vault);
      expect(host.released, isEmpty, reason: 'same folder keeps its grant');
      expect((await access.writerFor(folder).write(_note)).isOk, isTrue);
    });

    test('[EXP-03/AC1] re-granting to a different folder releases the old '
        'grant', () async {
      host.grant(_vault);
      const folder = VaultFolder(kind: VaultTargetKind.saf, handle: _vault);
      host.nextPick = SafTree(treeUri: _other);
      final next = await SafFolderAccess(api: host).pick(previous: folder);
      expect(next.valueOrNull?.handle, _other);
      expect(host.released, [_vault]);
      expect(host.persisted, {_other});
    });

    test('cancelling the picker is not an error', () async {
      host.nextPick = null;
      final r = await VaultAccessGuard(
        SafFolderAccess(api: host),
      ).regrant(const VaultFolder(kind: VaultTargetKind.saf, handle: _vault));
      expect(r.isOk, isTrue);
      expect(r.valueOrNull, isNull);
    });

    test('a removed SD card is unavailable (retry), not revoked', () async {
      host
        ..grant(_other)
        ..unmounted.add(_other);
      const folder = VaultFolder(kind: VaultTargetKind.saf, handle: _other);
      final access = SafFolderAccess(api: host);
      expect(await access.checkAccess(folder), VaultAccess.unavailable);
      expect(
        await VaultAccessGuard(access).check(folder),
        VaultAccessAction.retryLater,
      );
      final r = await access.writerFor(folder).write(_note);
      expect(
        (r.failureOrNull! as VaultAccessFailure).access,
        VaultAccess.unavailable,
      );
    });

    test('a bookmark handle is never used as a tree URI', () async {
      const ios = VaultFolder(kind: VaultTargetKind.bookmark, handle: 'AAAA');
      final access = SafFolderAccess(api: host);
      expect(await access.checkAccess(ios), VaultAccess.revoked);
      expect(host.calls, 0);
    });

    test('host errors during the access check never report ok', () async {
      final throwing = _ThrowingCheckApi('io');
      expect(
        await SafVaultWriter(treeUri: _vault, api: throwing).checkAccess(),
        VaultAccess.unavailable,
      );
      expect(
        await SafVaultWriter(
          treeUri: _vault,
          api: _ThrowingCheckApi('revoked'),
        ).checkAccess(),
        VaultAccess.revoked,
      );
    });
  });

  group('writes', () {
    setUp(() => host.grant(_vault));

    test('[EXP-03/AC2] the note is written at the exact path with the exact '
        'UTF-8 bytes (what Obsidian indexes)', () async {
      final w = SafVaultWriter(treeUri: _vault, api: host);
      final r = await w.write(_note);
      expect(r.valueOrNull?.location, startsWith(_vault));
      final sent = host.lastWrite!;
      expect(sent.tree, _vault);
      expect(sent.path, _note.relativePath);
      expect(utf8.decode(sent.bytes), _note.markdown);
      expect(sent.overwrite, isFalse);
      expect((await w.exists(_note.relativePath)).valueOrNull, isTrue);
      expect((await w.list('Meetings')).valueOrNull!.map((e) => e.name), [
        '2026-10-12-meeting-standup.md',
      ]);
    });

    test('[EXP-03/AC2] overwrite replaces the whole file (no stale bytes); '
        'without overwrite an existing note is kept', () async {
      final w = SafVaultWriter(treeUri: _vault, api: host);
      await w.write(_note);
      final kept = await w.write(
        const NoteDraft(
          relativePath: 'Meetings/2026-10-12-meeting-standup.md',
          markdown: 'x',
        ),
      );
      expect(kept.failureOrNull, isA<VaultFileExistsFailure>());
      expect(
        utf8.decode(host.files[_vault]![_note.relativePath]!),
        _note.markdown,
      );

      final replaced = await w.write(
        const NoteDraft(
          relativePath: 'Meetings/2026-10-12-meeting-standup.md',
          markdown: 'x',
        ),
        overwrite: true,
      );
      expect(replaced.isOk, isTrue);
      expect(host.lastWrite!.overwrite, isTrue);
      expect(utf8.decode(host.files[_vault]![_note.relativePath]!), 'x');
    });

    test('mkdirs, list root, delete', () async {
      final w = SafVaultWriter(treeUri: _vault, api: host);
      expect((await w.mkdirs('Inbox/2026')).isOk, isTrue);
      await w.write(const NoteDraft(relativePath: 'a.md', markdown: 'a'));
      final root = (await w.list('')).valueOrNull!;
      expect(
        {for (final e in root) e.name: e.isDirectory},
        {'Inbox': true, 'a.md': false},
      );
      expect((await w.delete('a.md')).valueOrNull, isTrue);
      expect((await w.delete('a.md')).valueOrNull, isFalse);
      expect((await w.exists('a.md')).valueOrNull, isFalse);
      expect((await w.list('Nope')).failureOrNull, isA<StorageFailure>());
    });

    test(
      'unsafe relative paths are rejected before reaching the host',
      () async {
        final w = SafVaultWriter(treeUri: _vault, api: host);
        for (final bad in [
          '',
          '/abs.md',
          '../escape.md',
          'a/../b.md',
          'a//b.md',
          './a.md',
          r'a\b.md',
          'a/\u0000.md',
        ]) {
          final r = await w.write(NoteDraft(relativePath: bad, markdown: ''));
          expect(r.failureOrNull, isA<StorageFailure>(), reason: bad);
          expect((await w.exists(bad)).isOk, isFalse, reason: bad);
          expect((await w.delete(bad)).isOk, isFalse, reason: bad);
          expect((await w.mkdirs(bad)).isOk, isFalse, reason: bad);
        }
        expect((await w.list('../x')).isOk, isFalse);
        expect(host.calls, 0);
      },
    );
  });

  group('error mapping', () {
    test('every host error code maps to a content-free failure', () {
      Failure f(String code) => vaultFailureFrom(
        PlatformException(code: code, message: 'secret-name.md'),
      );
      expect(
        (f(VaultErrorCodes.revoked) as VaultAccessFailure).access,
        VaultAccess.revoked,
      );
      expect(
        (f(VaultErrorCodes.unavailable) as VaultAccessFailure).access,
        VaultAccess.unavailable,
      );
      expect(f(VaultErrorCodes.exists), isA<VaultFileExistsFailure>());
      for (final code in [
        VaultErrorCodes.notFound,
        VaultErrorCodes.invalid,
        VaultErrorCodes.busy,
        VaultErrorCodes.io,
      ]) {
        expect(f(code), isA<StorageFailure>(), reason: code);
      }
      expect(f('channel-error'), isA<UnexpectedFailure>());
      for (final code in [
        VaultErrorCodes.revoked,
        VaultErrorCodes.unavailable,
        VaultErrorCodes.exists,
        VaultErrorCodes.notFound,
        VaultErrorCodes.invalid,
        VaultErrorCodes.busy,
        VaultErrorCodes.io,
        'channel-error',
      ]) {
        expect(f(code).message, isNot(contains('secret')), reason: code);
      }
    });

    test('a picker error is returned, not thrown', () async {
      final r = await SafFolderAccess(api: _BusyPickApi()).pick();
      expect(r.failureOrNull, isA<StorageFailure>());
    });
  });

  group('platform contract (EXP-03 scope)', () {
    test('no broad storage permission is requested (Play policy)', () {
      final manifests = Directory('android/app/src')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('AndroidManifest.xml'));
      expect(manifests, isNotEmpty);
      for (final m in manifests) {
        final xml = m.readAsStringSync();
        expect(xml, isNot(contains('MANAGE_EXTERNAL_STORAGE')), reason: m.path);
        expect(xml, isNot(contains('WRITE_EXTERNAL_STORAGE')), reason: m.path);
        expect(xml, isNot(contains('READ_EXTERNAL_STORAGE')), reason: m.path);
      }
    });

    test('Kotlin host uses DocumentsContract, persisted grants and "wt"', () {
      final kt = File(
        'android/app/src/main/kotlin/com/vaultvoice/vaultvoice/saf/SafHostApiImpl.kt',
      ).readAsStringSync();
      expect(kt, contains('ACTION_OPEN_DOCUMENT_TREE'));
      expect(kt, contains('takePersistableUriPermission'));
      expect(kt, contains('persistedUriPermissions'));
      expect(kt, contains('buildChildDocumentsUriUsingTree'));
      expect(kt, contains('openOutputStream(uri, "wt")'));
      expect(kt, isNot(contains('openOutputStream(uri, "w")')));
      expect(kt, isNot(contains('androidx.documentfile')));
      for (final code in [
        VaultErrorCodes.revoked,
        VaultErrorCodes.unavailable,
        VaultErrorCodes.exists,
        VaultErrorCodes.notFound,
        VaultErrorCodes.invalid,
        VaultErrorCodes.busy,
        VaultErrorCodes.io,
      ]) {
        expect(kt, contains('err("$code"'), reason: code);
      }
      final main = File(
        'android/app/src/main/kotlin/com/vaultvoice/vaultvoice/MainActivity.kt',
      ).readAsStringSync();
      expect(main, contains('SafHostApi.setUp('));
      expect(main, contains('onActivityResult'));
    });
  });
}

class _ThrowingCheckApi extends FakeSafHostApi {
  _ThrowingCheckApi(this.code);

  final String code;

  @override
  Future<SafAccessStatus> checkAccess(String treeUri) async =>
      throw PlatformException(code: code);
}

class _BusyPickApi extends FakeSafHostApi {
  @override
  Future<SafTree?> pickTree(String? initialTreeUri) async =>
      throw PlatformException(code: VaultErrorCodes.busy);
}
