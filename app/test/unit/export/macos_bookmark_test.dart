import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';
import 'package:vaultvoice/features/export/data/bookmark_vault_writer.dart';
import 'package:vaultvoice/features/export/data/export_providers.dart';
import 'package:vaultvoice/features/export/data/managed_vault_folder_access.dart';
import 'package:vaultvoice/features/export/data/pigeon/bookmark_api.g.dart';
import 'package:vaultvoice/features/export/domain/vault_folder.dart';

import '../../fakes/fake_bookmark_host_api.dart';
import '../../helpers/test_container.dart';

const _note = NoteDraft(
  relativePath: 'Meetings/2026-10-12-meeting-standup.md',
  markdown: '---\ntitle: "Standup ✅"\n---\n\n# Standup\n',
);

/// A relaunch keeps the OS bookmark table for [savedBookmark] only.
/// The panel URL is not copied. An unknown bookmark resolves to nothing.
FakeBookmarkHostApi _relaunch(FakeBookmarkHostApi live, String savedBookmark) {
  final id = live.bookmarks[savedBookmark];
  if (id == null) return FakeBookmarkHostApi();
  final next = FakeBookmarkHostApi()..addFolder(savedBookmark, id);
  next.files[id] = {
    for (final e in live.files[id]!.entries) e.key: Uint8List.fromList(e.value),
  };
  next.dirs[id] = Set.of(live.dirs[id]!);
  if (live.stale.contains(savedBookmark)) next.stale.add(savedBookmark);
  return next;
}

void main() {
  test('[EXP-09/AC1] a macOS security-scoped bookmark still resolves '
      'after a simulated restart', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(
      createContainer().read(vaultFolderAccessProvider),
      isA<ManagedVaultFolderAccess>(),
    );

    final swift = File('../packages/vv_native/macos/MacBookmarkPanel.swift')
        .readAsStringSync();
    expect(swift, contains('NSOpenPanel'));
    expect(swift, contains('.withSecurityScope'));
    expect(swift, contains('bookmarkDataIsStale'));
    expect(swift, isNot(contains('UIDocumentPickerViewController')));

    const bookmark = 'bm-notes';
    final live = FakeBookmarkHostApi()
      ..addFolder(bookmark, 'notes-vault')
      ..nextPick = BookmarkFolder(bookmark: bookmark, displayName: 'Notes');
    final folder = (await BookmarkFolderAccess(api: live).pick()).valueOrNull!;
    expect(folder.kind, VaultTargetKind.bookmark);
    expect(folder.handle, bookmark);

    final saved = folder.handle;
    final restartedHost = _relaunch(live, saved);
    final restarted = BookmarkFolderAccess(api: restartedHost);
    final restored = VaultFolder(
      kind: VaultTargetKind.bookmark,
      handle: saved,
      displayName: folder.displayName,
    );
    expect(await restarted.checkAccess(restored), VaultAccess.ok);
    expect(restarted.writerFor(restored), isA<BookmarkVaultWriter>());
    expect((await restarted.writerFor(restored).write(_note)).isOk, isTrue);
    expect(restartedHost.picks, 0);
    expect(live.picks, 1);
    expect(
      utf8.decode(restartedHost.files['notes-vault']![_note.relativePath]!),
      _note.markdown,
    );
    expect(
      restartedHost.files['notes-vault']![_note.relativePath],
      utf8.encode(_note.markdown),
    );
  });

  test('[EXP-09/AC1] a stale macOS bookmark is refreshed and the note '
      'bytes still match', () async {
    const bookmark = 'bm-notes';
    final live = FakeBookmarkHostApi()..addFolder(bookmark, 'notes-vault');
    live.stale.add(bookmark);
    final restartedHost = _relaunch(live, bookmark);
    final refreshed = <VaultFolder>[];
    final access = BookmarkFolderAccess(
      api: restartedHost,
      onRefreshed: (_, updated) => refreshed.add(updated),
    );
    const folder = VaultFolder(
      kind: VaultTargetKind.bookmark,
      handle: bookmark,
      displayName: 'Notes',
    );
    expect(await access.checkAccess(folder), VaultAccess.ok);
    expect(refreshed.single.handle, '$bookmark+fresh');

    final writer = access.writerFor(folder) as BookmarkVaultWriter;
    expect(await writer.checkAccess(), VaultAccess.ok);
    expect(writer.bookmark, '$bookmark+fresh');
    restartedHost.bookmarks.remove(bookmark);
    expect((await writer.write(_note)).isOk, isTrue);
    expect(
      restartedHost.files['notes-vault']![_note.relativePath],
      utf8.encode(_note.markdown),
    );
  });

  test('[EXP-09/AC3] macOS entitlements grant user-selected files only', () {
    final ents = Directory('../packages/vv_native/macos')
        .listSync()
        .where((e) => e.path.endsWith('.entitlements'))
        .toList();
    expect(ents, isNotEmpty);
    const forbidden = [
      'com.apple.security.files.downloads.read-write',
      'com.apple.security.files.all',
      'com.apple.security.temporary-exception.files.absolute-path.read-write',
    ];
    for (final entity in ents) {
      final text = File(entity.path).readAsStringSync();
      for (final key in forbidden) {
        expect(text, isNot(contains(key)), reason: entity.path);
      }
    }
    final vault = File('../packages/vv_native/macos/VaultFolder.entitlements')
        .readAsStringSync();
    expect(
      vault,
      contains('<key>com.apple.security.files.user-selected.read-write</key>'),
    );
    final keys = RegExp('<key>([^<]+)</key>')
        .allMatches(vault)
        .map((m) => m.group(1)!)
        .toSet();
    expect(keys, {
      'com.apple.security.app-sandbox',
      'com.apple.security.files.user-selected.read-write',
    });
  });
}
