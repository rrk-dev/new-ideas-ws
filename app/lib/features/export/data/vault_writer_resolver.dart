import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/repositories/vault_repository.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';
import 'package:vaultvoice/features/export/data/bookmark_vault_writer.dart';
import 'package:vaultvoice/features/export/data/pigeon/bookmark_api.g.dart';
import 'package:vaultvoice/features/export/data/pigeon/saf_api.g.dart';
import 'package:vaultvoice/features/export/data/saf_vault_writer.dart';
import 'package:vaultvoice/features/export/data/vault_exporter.dart';

/// The `VaultTarget` abstraction (EXP-05): one stored `vault_targets` row →
/// the platform [VaultWriter] for it.
///
/// - `androidSaf` → [SafVaultWriter] over the persisted tree URI (EXP-03)
/// - `iosBookmark` → [BookmarkVaultWriter]; a refreshed (stale) bookmark is
///   persisted back into `vault_targets.handle` through [repo] (EXP-04)
/// - `appLocal` → [appLocal] (the app's own folder)
///
/// Host APIs are created per call: Pigeon channels work from the pipeline
/// isolate once it has a `BackgroundIsolateBinaryMessenger` (FND-11 wiring).
VaultWriterResolver platformVaultWriterResolver({
  required VaultWriter appLocal,
  VaultRepository? repo,
  SafHostApi? safApi,
  BookmarkHostApi? bookmarkApi,
}) =>
    (target) => switch (target.platform) {
      VaultPlatform.androidSaf => SafVaultWriter(
        treeUri: target.handle,
        api: safApi,
      ),
      VaultPlatform.iosBookmark => BookmarkVaultWriter(
        bookmark: target.handle,
        api: bookmarkApi,
        onRefreshed: repo == null
            ? null
            : (refreshed) => _persistRefreshed(repo, target, refreshed),
      ),
      VaultPlatform.appLocal => appLocal,
    };

void _persistRefreshed(
  VaultRepository repo,
  VaultTargetRow target,
  String refreshed,
) {
  // Fire and forget: a failed update only means iOS refreshes it again.
  repo
      .upsertTarget(target.copyWith(handle: refreshed).toCompanion(true))
      .ignore();
}
