import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';
import 'package:vaultvoice/features/export/data/app_local_vault_writer.dart';
import 'package:vaultvoice/features/export/data/bookmark_vault_writer.dart';
import 'package:vaultvoice/features/export/data/export_providers.dart';
import 'package:vaultvoice/features/export/data/managed_vault_folder_access.dart';
import 'package:vaultvoice/features/export/data/pigeon/bookmark_api.g.dart';
import 'package:vaultvoice/features/export/data/vault_platform_errors.dart';
import 'package:vaultvoice/features/export/domain/vault_access_guard.dart';
import 'package:vaultvoice/features/export/domain/vault_folder.dart';

import '../../fakes/fake_bookmark_host_api.dart';
import '../../helpers/test_container.dart';

const _local = 'bm-local'; // On My iPhone › Obsidian › Work
const _icloud = 'bm-icloud'; // iCloud Drive › Obsidian › Personal

const _note = NoteDraft(
  relativePath: 'Meetings/2026-10-12-meeting-standup.md',
  markdown: '---\ntitle: "Standup ✅"\n---\n\n# Standup\n',
);

void main() {
  late FakeBookmarkHostApi host;

  setUp(() {
    host = FakeBookmarkHostApi()
      ..addFolder(_local, 'local-vault')
      ..addFolder(_icloud, 'icloud-vault');
  });

  group('persistent access', () {
    test('[EXP-04/AC1] a picked folder stays writable after a restart '
        'without re-picking', () async {
      host.nextPick = BookmarkFolder(bookmark: _local, displayName: 'Work');
      final folder = (await BookmarkFolderAccess(
        api: host,
      ).pick()).valueOrNull!;
      expect(folder.kind, VaultTargetKind.bookmark);
      expect(folder.handle, _local);
      expect(folder.displayName, 'Work');

      // "Restart": only the stored handle survives.
      final restarted = BookmarkFolderAccess(api: host);
      expect(await restarted.checkAccess(folder), VaultAccess.ok);
      expect((await restarted.writerFor(folder).write(_note)).isOk, isTrue);
      expect(host.picks, 1, reason: 'no second picker');
    });

    test('[EXP-04/AC1] a stale bookmark (app update, folder moved) is '
        'refreshed and reported for persistence', () async {
      host.stale.add(_local);
      const folder = VaultFolder(
        kind: VaultTargetKind.bookmark,
        handle: _local,
        displayName: 'Work',
      );
      final refreshed = <(VaultFolder, VaultFolder)>[];
      final access = BookmarkFolderAccess(
        api: host,
        onRefreshed: (a, b) => refreshed.add((a, b)),
      );
      expect(await access.checkAccess(folder), VaultAccess.ok);
      expect(refreshed.single.$1.handle, _local);
      expect(refreshed.single.$2.handle, '$_local+fresh');
      expect(refreshed.single.$2.displayName, 'Work');

      // The writer switches to the refreshed bookmark: it keeps working
      // after the old data stops resolving.
      final seen = <String>[];
      final w = BookmarkVaultWriter(
        bookmark: _local,
        api: host,
        onRefreshed: seen.add,
      );
      expect(await w.checkAccess(), VaultAccess.ok);
      expect(w.bookmark, '$_local+fresh');
      expect(seen, ['$_local+fresh']);
      host.bookmarks.remove(_local);
      expect((await w.write(_note)).isOk, isTrue);

      final viaFolder = access.writerFor(folder) as BookmarkVaultWriter;
      host.bookmarks[_local] = 'local-vault';
      await viaFolder.checkAccess();
      expect(refreshed, hasLength(2));
    });

    test('[EXP-04/AC1] an unresolvable bookmark (app reinstalled, folder '
        'deleted) is revoked and re-granted via the picker', () async {
      const folder = VaultFolder(
        kind: VaultTargetKind.bookmark,
        handle: 'bm-gone',
      );
      final access = BookmarkFolderAccess(api: host);
      final guard = VaultAccessGuard(access);
      expect(await guard.check(folder), VaultAccessAction.promptRegrant);
      final denied = await access.writerFor(folder).write(_note);
      expect(
        (denied.failureOrNull! as VaultAccessFailure).access,
        VaultAccess.revoked,
      );

      host.nextPick = BookmarkFolder(bookmark: _local);
      final regranted = await guard.regrant(folder);
      expect(regranted.valueOrNull?.handle, _local);
      expect(regranted.valueOrNull?.kind, VaultTargetKind.bookmark);
      await access.release(folder); // no-op on iOS, must not throw
    });

    test('an offline provider is unavailable (retry), not revoked', () async {
      host.unreachable.add('icloud-vault');
      const folder = VaultFolder(
        kind: VaultTargetKind.bookmark,
        handle: _icloud,
      );
      final access = BookmarkFolderAccess(api: host);
      expect(await access.checkAccess(folder), VaultAccess.unavailable);
      final r = await access.writerFor(folder).write(_note);
      expect(
        (r.failureOrNull! as VaultAccessFailure).access,
        VaultAccess.unavailable,
      );
    });

    test('host errors in the access check never report ok', () async {
      Future<VaultAccess> check(String code) async =>
          (await bookmarkCheckAccess(_ThrowingCheck(code), 'x')).$1;
      expect(await check(VaultErrorCodes.io), VaultAccess.unavailable);
      expect(await check(VaultErrorCodes.invalid), VaultAccess.revoked);
      expect(await check(VaultErrorCodes.revoked), VaultAccess.revoked);
      const saf = VaultFolder(kind: VaultTargetKind.saf, handle: 'content://');
      expect(
        await BookmarkFolderAccess(api: host).checkAccess(saf),
        VaultAccess.revoked,
      );
    });

    test('cancelling or failing the picker is returned, not thrown', () async {
      host.nextPick = null;
      final cancelled = await BookmarkFolderAccess(api: host).pick();
      expect(cancelled.isOk, isTrue);
      expect(cancelled.valueOrNull, isNull);
      final busy = await BookmarkFolderAccess(api: _BusyPick()).pick();
      expect(busy.failureOrNull, isA<StorageFailure>());
    });
  });

  group('writes', () {
    test('[EXP-04/AC2] notes land at the exact path with the exact bytes in '
        'local and iCloud vaults', () async {
      for (final (bm, id) in [
        (_local, 'local-vault'),
        (_icloud, 'icloud-vault'),
      ]) {
        final w = BookmarkVaultWriter(bookmark: bm, api: host);
        final r = await w.write(_note);
        expect(r.isOk, isTrue, reason: bm);
        expect(
          utf8.decode(host.files[id]![_note.relativePath]!),
          _note.markdown,
        );
        expect((await w.exists(_note.relativePath)).valueOrNull, isTrue);
        expect((await w.list('Meetings')).valueOrNull!.map((e) => e.name), [
          '2026-10-12-meeting-standup.md',
        ]);
      }
    });

    test('[EXP-04/AC2] an iCloud placeholder is never overwritten blindly: '
        'download starts, the write is retried, exactly one note', () async {
      host.notDownloaded.add('icloud-vault/${_note.relativePath}');
      final w = BookmarkVaultWriter(bookmark: _icloud, api: host);
      expect((await w.exists(_note.relativePath)).valueOrNull, isTrue);
      expect(
        (await w.write(_note)).failureOrNull,
        isA<VaultFileExistsFailure>(),
      );

      final first = await w.write(_note, overwrite: true);
      expect(
        (first.failureOrNull! as VaultAccessFailure).access,
        VaultAccess.unavailable,
        reason: 'retry via outbox',
      );
      expect(host.downloadsStarted, ['icloud-vault/${_note.relativePath}']);
      expect(host.files['icloud-vault'], isEmpty);

      host.notDownloaded.clear(); // iCloud finished downloading
      final retry = await w.write(_note, overwrite: true);
      expect(retry.isOk, isTrue);
      expect(host.files['icloud-vault']!.keys, [_note.relativePath]);
    });

    test('mkdirs, delete, list root, unsafe paths', () async {
      final w = BookmarkVaultWriter(bookmark: _local, api: host);
      expect((await w.mkdirs('Inbox')).isOk, isTrue);
      await w.write(const NoteDraft(relativePath: 'a.md', markdown: 'a'));
      final root = (await w.list('')).valueOrNull!;
      expect(
        {for (final e in root) e.name: e.isDirectory},
        {'Inbox': true, 'a.md': false},
      );
      expect((await w.delete('a.md')).valueOrNull, isTrue);
      expect((await w.delete('a.md')).valueOrNull, isFalse);
      expect((await w.list('Nope')).failureOrNull, isA<StorageFailure>());
      final before = host.calls;
      for (final bad in ['', '/x.md', '../x.md', 'a//b.md', r'a\b']) {
        expect(
          (await w.write(NoteDraft(relativePath: bad, markdown: ''))).isOk,
          isFalse,
          reason: bad,
        );
      }
      expect(host.calls, before);
    });
  });

  group('platform contract (EXP-04 scope)', () {
    String read(String p) => File(p).readAsStringSync();

    test('Info.plist exposes Documents in Files (default target)', () {
      final plist = read('ios/Runner/Info.plist');
      for (final key in [
        'UIFileSharingEnabled',
        'LSSupportsOpeningDocumentsInPlace',
      ]) {
        expect(
          RegExp('<key>$key</key>\\s*<true/>').hasMatch(plist),
          isTrue,
          reason: key,
        );
      }
    });

    test(
      'Swift host: folder picker, bookmarks, coordination, placeholders',
      () {
        final swift = read('ios/Runner/BookmarkHostApiImpl.swift');
        for (final needle in [
          'UIDocumentPickerViewController(forOpeningContentTypes: [.folder]',
          'asCopy: false)',
          'bookmarkData(options: [], includingResourceValuesForKeys: nil',
          'resolvingBookmarkData',
          'bookmarkDataIsStale',
          'startAccessingSecurityScopedResource()',
          'stopAccessingSecurityScopedResource()',
          'NSFileCoordinator(filePresenter: nil)',
          'options: .forReplacing',
          'data.write(to: dst, options: .atomic)',
          '.immediatelyAvailableMetadataOnly',
          '.ubiquitousItemDownloadingStatusKey',
          'startDownloadingUbiquitousItem',
        ]) {
          expect(swift, contains(needle), reason: needle);
        }
        for (final code in [
          VaultErrorCodes.revoked,
          VaultErrorCodes.unavailable,
          VaultErrorCodes.exists,
          VaultErrorCodes.notFound,
          VaultErrorCodes.invalid,
          VaultErrorCodes.busy,
          VaultErrorCodes.io,
        ]) {
          expect(swift, contains('"$code"'), reason: code);
        }
        expect(
          read('ios/Runner/AppDelegate.swift'),
          contains('BookmarkHostApiSetup.setUp('),
        );
        final pbx = read('ios/Runner.xcodeproj/project.pbxproj');
        for (final f in ['BookmarkApi.g.swift', 'BookmarkHostApiImpl.swift']) {
          expect(pbx, contains('/* $f in Sources */,'), reason: f);
        }
      },
    );
  });

  group('providers', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('pick the platform implementation', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      var c = createContainer();
      expect(
        c.read(vaultFolderAccessProvider),
        isA<ManagedVaultFolderAccess>(),
      );
      expect(c.read(appLocalVaultWriterProvider), isA<AppLocalVaultWriter>());
      expect(c.read(vaultAccessGuardProvider), isA<VaultAccessGuard>());

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      c = createContainer();
      expect(
        c.read(vaultFolderAccessProvider),
        isA<ManagedVaultFolderAccess>(),
      );
      expect(c.read(appLocalVaultWriterProvider), isA<AppLocalVaultWriter>());

      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      c = createContainer();
      expect(() => c.read(vaultFolderAccessProvider), throwsA(anything));
      expect(() => c.read(appLocalVaultWriterProvider), throwsA(anything));
    });
  });
}

class _ThrowingCheck extends FakeBookmarkHostApi {
  _ThrowingCheck(this.code);

  final String code;

  @override
  Future<BookmarkAccess> checkAccess(String bookmark) async =>
      throw PlatformException(code: code);
}

class _BusyPick extends FakeBookmarkHostApi {
  @override
  Future<BookmarkFolder?> pickFolder() async =>
      throw PlatformException(code: VaultErrorCodes.busy);
}
