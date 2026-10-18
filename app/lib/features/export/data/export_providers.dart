import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';
import 'package:vaultvoice/features/export/data/app_local_vault_writer.dart';
import 'package:vaultvoice/features/export/data/bookmark_vault_writer.dart';
import 'package:vaultvoice/features/export/data/managed_vault_folder_access.dart';
import 'package:vaultvoice/features/export/data/pigeon/bookmark_api.g.dart';
import 'package:vaultvoice/features/export/data/pigeon/saf_api.g.dart';
import 'package:vaultvoice/features/export/data/saf_vault_writer.dart';
import 'package:vaultvoice/features/export/domain/vault_access_guard.dart';
import 'package:vaultvoice/features/export/domain/vault_folder.dart';
import 'package:vaultvoice/features/licensing/data/managed_config_providers.dart';
import 'package:vaultvoice/features/licensing/domain/managed_config.dart';

part 'export_providers.g.dart';

/// Folder picking + persistent access for the current platform.
///
/// iOS and macOS: refreshed (stale) bookmarks are handed to `onRefreshed`;
/// persisting them in `vault_targets` is EXP-05's job once that table exists.
/// macOS uses the same [BookmarkFolderAccess] as EXP-04. The panel is
/// `NSOpenPanel` (`packages/vv_native/macos/MacBookmarkPanel.swift`).
@Riverpod(keepAlive: true)
VaultFolderAccess vaultFolderAccess(Ref ref) {
  final (access, kind) = switch (defaultTargetPlatform) {
    TargetPlatform.android => (SafFolderAccess(), VaultTargetKind.saf),
    TargetPlatform.iOS => (BookmarkFolderAccess(), VaultTargetKind.bookmark),
    TargetPlatform.macOS => (BookmarkFolderAccess(), VaultTargetKind.bookmark),
    _ => throw UnsupportedError('no vault folder access on this platform'),
  };
  // MDM `allowed_target_kinds` (LIC-04); the policy is read at every call.
  final config = ref.watch(managedConfigProvider);
  return ManagedVaultFolderAccess(
    access,
    pickKind: kind,
    policy: () => config.value ?? ManagedConfig.none,
  );
}

/// Detects revoked access and drives the re-grant flow.
@Riverpod(keepAlive: true)
VaultAccessGuard vaultAccessGuard(Ref ref) =>
    VaultAccessGuard(ref.watch(vaultFolderAccessProvider));

/// The app's own folder: default/fallback vault target. Android:
/// app-private `filesDir/vault`; iOS: `Documents/`, visible in Files under
/// "On My iPhone › Lumen" (`UIFileSharingEnabled`).
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
