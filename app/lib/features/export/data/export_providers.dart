import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';
import 'package:vaultvoice/features/export/data/app_local_vault_writer.dart';
import 'package:vaultvoice/features/export/data/pigeon/saf_api.g.dart';
import 'package:vaultvoice/features/export/data/saf_vault_writer.dart';
import 'package:vaultvoice/features/export/domain/vault_access_guard.dart';
import 'package:vaultvoice/features/export/domain/vault_folder.dart';

part 'export_providers.g.dart';

/// Folder picking + persistent access for the current platform.
@Riverpod(keepAlive: true)
VaultFolderAccess vaultFolderAccess(Ref ref) => switch (defaultTargetPlatform) {
  TargetPlatform.android => SafFolderAccess(),
  // iOS: BookmarkFolderAccess (EXP-04).
  _ => throw UnsupportedError('no vault folder access on this platform'),
};

/// Detects revoked access and drives the re-grant flow.
@Riverpod(keepAlive: true)
VaultAccessGuard vaultAccessGuard(Ref ref) =>
    VaultAccessGuard(ref.watch(vaultFolderAccessProvider));

/// The app's own folder: default/fallback vault target.
@Riverpod(keepAlive: true)
VaultWriter appLocalVaultWriter(Ref ref) => switch (defaultTargetPlatform) {
  TargetPlatform.android => AppLocalVaultWriter(
    () async => Directory(await SafHostApi().appLocalVaultPath()),
  ),
  // iOS: Documents/ via the bookmark host API (EXP-04).
  _ => throw UnsupportedError('no app-local vault on this platform'),
};
