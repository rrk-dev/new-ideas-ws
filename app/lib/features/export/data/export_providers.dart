import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';
import 'package:vaultvoice/features/export/data/app_local_vault_writer.dart';
import 'package:vaultvoice/features/export/data/bookmark_vault_writer.dart';
import 'package:vaultvoice/features/export/data/pigeon/bookmark_api.g.dart';
import 'package:vaultvoice/features/export/data/pigeon/saf_api.g.dart';
import 'package:vaultvoice/features/export/data/saf_vault_writer.dart';
import 'package:vaultvoice/features/export/domain/vault_access_guard.dart';
import 'package:vaultvoice/features/export/domain/vault_folder.dart';

part 'export_providers.g.dart';

/// Folder picking + persistent access for the current platform.
///
/// iOS and macOS: refreshed (stale) bookmarks are handed to `onRefreshed`;
/// persisting them in `vault_targets` is EXP-05's job once that table exists.
/// macOS uses the same [BookmarkFolderAccess] as EXP-04. The panel is
/// `NSOpenPanel` (`packages/vv_native/macos/MacBookmarkPanel.swift`).
@Riverpod(keepAlive: true)
VaultFolderAccess vaultFolderAccess(Ref ref) => switch (defaultTargetPlatform) {
  TargetPlatform.android => SafFolderAccess(),
  TargetPlatform.iOS => BookmarkFolderAccess(),
  TargetPlatform.macOS => BookmarkFolderAccess(),
  _ => throw UnsupportedError('no vault folder access on this platform'),
};

/// Detects revoked access and drives the re-grant flow.
@Riverpod(keepAlive: true)
VaultAccessGuard vaultAccessGuard(Ref ref) =>
    VaultAccessGuard(ref.watch(vaultFolderAccessProvider));

/// The app's own folder: default/fallback vault target. Android:
/// app-private `filesDir/vault`; iOS: `Documents/`, visible in Files under
/// "On My iPhone › VaultVoice" (`UIFileSharingEnabled`).
@Riverpod(keepAlive: true)
VaultWriter appLocalVaultWriter(Ref ref) => switch (defaultTargetPlatform) {
  TargetPlatform.android => AppLocalVaultWriter(
    () async => Directory(await SafHostApi().appLocalVaultPath()),
  ),
  TargetPlatform.iOS => AppLocalVaultWriter(
    () async => Directory(await BookmarkHostApi().appDocumentsPath()),
  ),
  _ => throw UnsupportedError('no app-local vault on this platform'),
};
