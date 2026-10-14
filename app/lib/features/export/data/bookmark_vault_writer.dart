import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';
import 'package:vaultvoice/features/export/data/pigeon/bookmark_api.g.dart';
import 'package:vaultvoice/features/export/data/vault_platform_errors.dart';
import 'package:vaultvoice/features/export/domain/vault_folder.dart';

/// Called when iOS re-created a stale bookmark: persist [updated] in place of
/// [previous] (`vault_targets.handle`, EXP-05) so access survives updates.
typedef BookmarkRefreshed = void Function(
  VaultFolder previous,
  VaultFolder updated,
);

/// [VaultWriter] for an iOS or macOS folder reached through a security-scoped
/// bookmark (EXP-04, EXP-09). The bytes are the UTF-8 of [NoteDraft.markdown].
///
/// Every call goes to the Swift host (`BookmarkHostApiImpl.swift`), which
/// resolves the bookmark, opens a short security-scoped access window and
/// writes through `NSFileCoordinator` (atomic, iCloud-safe). An iCloud note
/// that is not downloaded yet fails with `VaultAccess.unavailable` after the
/// host started its download, so the outbox (EXP-06) retries.
class BookmarkVaultWriter implements VaultWriter {
  BookmarkVaultWriter({
    required this._bookmark,
    BookmarkHostApi? api,
    this._onRefreshed,
  }) : _api = api ?? BookmarkHostApi();

  String _bookmark;
  final BookmarkHostApi _api;
  final void Function(String refreshed)? _onRefreshed;

  /// The current bookmark (base64); changes when a stale one is refreshed.
  String get bookmark => _bookmark;

  @override
  Future<VaultAccess> checkAccess() async {
    final (access, refreshed) = await bookmarkCheckAccess(_api, _bookmark);
    if (refreshed != null && refreshed != _bookmark) {
      _bookmark = refreshed;
      _onRefreshed?.call(refreshed);
    }
    return access;
  }

  @override
  Future<Result<WrittenNote>> write(NoteDraft note, {bool overwrite = false}) =>
      withVaultPath(note.relativePath, (path) async {
        final bytes = Uint8List.fromList(utf8.encode(note.markdown));
        return WrittenNote(
          await _api.writeFile(_bookmark, path, bytes, overwrite),
        );
      });

  @override
  Future<Result<bool>> exists(String relativePath) =>
      withVaultPath(relativePath, (path) => _api.exists(_bookmark, path));

  @override
  Future<Result<void>> mkdirs(String relativeDir) =>
      withVaultPath(relativeDir, (path) => _api.mkdirs(_bookmark, path));

  @override
  Future<Result<bool>> delete(String relativePath) =>
      withVaultPath(relativePath, (path) => _api.delete(_bookmark, path));

  @override
  Future<Result<List<VaultEntry>>> list(String relativeDir) => withVaultPath(
    relativeDir,
    allowRoot: true,
    (path) async => [
      for (final e in await _api.list(_bookmark, path))
        VaultEntry(name: e.name, isDirectory: e.isDirectory),
    ],
  );
}

/// Resolves [bookmark] on the host. Returns the access state and, when iOS
/// reported the bookmark stale, the refreshed bookmark. Host errors are
/// [VaultAccess.unavailable] (retry) — never `ok`.
Future<(VaultAccess, String?)> bookmarkCheckAccess(
  BookmarkHostApi api,
  String bookmark,
) async {
  try {
    final r = await api.checkAccess(bookmark);
    final access = switch (r.status) {
      BookmarkAccessStatus.ok => VaultAccess.ok,
      BookmarkAccessStatus.revoked => VaultAccess.revoked,
      BookmarkAccessStatus.unavailable => VaultAccess.unavailable,
    };
    return (access, r.refreshedBookmark);
  } on PlatformException catch (e) {
    final access =
        e.code == VaultErrorCodes.revoked || e.code == VaultErrorCodes.invalid
        ? VaultAccess.revoked
        : VaultAccess.unavailable;
    return (access, null);
  }
}

/// [VaultFolderAccess] backed by a security-scoped bookmark. iOS picks with
/// `UIDocumentPickerViewController`; macOS picks with `NSOpenPanel` and
/// `.withSecurityScope` (EXP-09). The stored handle is the bookmark blob.
/// It survives restarts and app updates, not app deletion (then: re-pick).
class BookmarkFolderAccess implements VaultFolderAccess {
  BookmarkFolderAccess({BookmarkHostApi? api, this._onRefreshed})
    : _api = api ?? BookmarkHostApi();

  final BookmarkHostApi _api;
  final BookmarkRefreshed? _onRefreshed;

  @override
  Future<Result<VaultFolder?>> pick({VaultFolder? previous}) async {
    // iOS has no "initial folder" for the picker and nothing to release:
    // a bookmark is just data owned by the app.
    final picked = await guardVaultCall(_api.pickFolder);
    return switch (picked) {
      Err(:final failure) => Err(failure),
      Ok(value: null) => const Ok(null),
      Ok(value: final BookmarkFolder f) => Ok(
        VaultFolder(
          kind: VaultTargetKind.bookmark,
          handle: f.bookmark,
          displayName: f.displayName,
        ),
      ),
    };
  }

  @override
  Future<VaultAccess> checkAccess(VaultFolder folder) async {
    // A handle from another platform can never be used here: re-pick.
    if (folder.kind != VaultTargetKind.bookmark) return VaultAccess.revoked;
    final (access, refreshed) = await bookmarkCheckAccess(_api, folder.handle);
    if (refreshed != null && refreshed != folder.handle) {
      _onRefreshed?.call(folder, folder.withHandle(refreshed));
    }
    return access;
  }

  @override
  VaultWriter writerFor(VaultFolder folder) {
    assert(folder.kind == VaultTargetKind.bookmark, 'not a bookmark folder');
    return BookmarkVaultWriter(
      bookmark: folder.handle,
      api: _api,
      onRefreshed: (b) => _onRefreshed?.call(folder, folder.withHandle(b)),
    );
  }

  @override
  Future<void> release(VaultFolder folder) async {
    // Nothing to release on iOS: deleting the stored handle is enough.
  }
}
