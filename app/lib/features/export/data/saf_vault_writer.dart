import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';
import 'package:vaultvoice/features/export/data/pigeon/saf_api.g.dart';
import 'package:vaultvoice/features/export/data/vault_platform_errors.dart';
import 'package:vaultvoice/features/export/domain/vault_folder.dart';

/// [VaultWriter] for an Android Storage Access Framework tree (EXP-03).
///
/// `dart:io` cannot write `content://` URIs, so every operation goes through
/// the Kotlin host API (`SafHostApiImpl.kt`), which uses `DocumentsContract`
/// directly, overwrites with mode `"wt"` and checks the persisted grant on
/// every call.
class SafVaultWriter implements VaultWriter {
  SafVaultWriter({required this.treeUri, SafHostApi? api})
    : _api = api ?? SafHostApi();

  /// Persisted tree URI (`vault_targets.handle`).
  final String treeUri;
  final SafHostApi _api;

  @override
  Future<VaultAccess> checkAccess() => safCheckAccess(_api, treeUri);

  @override
  Future<Result<WrittenNote>> write(NoteDraft note, {bool overwrite = false}) =>
      writeBytes(
        note.relativePath,
        Uint8List.fromList(utf8.encode(note.markdown)),
        overwrite: overwrite,
      );

  @override
  Future<Result<WrittenNote>> writeBytes(
    String relativePath,
    Uint8List bytes, {
    bool overwrite = false,
  }) => withVaultPath(
    relativePath,
    (path) async =>
        WrittenNote(await _api.writeFile(treeUri, path, bytes, overwrite)),
  );

  @override
  Future<Result<Uint8List?>> read(String relativePath) =>
      withVaultPath(relativePath, (path) => _api.readFile(treeUri, path));

  @override
  Future<Result<bool>> exists(String relativePath) =>
      withVaultPath(relativePath, (path) => _api.exists(treeUri, path));

  @override
  Future<Result<void>> mkdirs(String relativeDir) =>
      withVaultPath(relativeDir, (path) => _api.mkdirs(treeUri, path));

  @override
  Future<Result<bool>> delete(String relativePath) =>
      withVaultPath(relativePath, (path) => _api.delete(treeUri, path));

  @override
  Future<Result<List<VaultEntry>>> list(String relativeDir) => withVaultPath(
    relativeDir,
    allowRoot: true,
    (path) async => [
      for (final e in await _api.list(treeUri, path))
        VaultEntry(name: e.name, isDirectory: e.isDirectory),
    ],
  );
}

/// Access check shared by [SafVaultWriter] and [SafFolderAccess]. A host
/// error is treated as [VaultAccess.unavailable] (retry), never as `ok`.
Future<VaultAccess> safCheckAccess(SafHostApi api, String treeUri) async {
  try {
    return switch (await api.checkAccess(treeUri)) {
      SafAccessStatus.ok => VaultAccess.ok,
      SafAccessStatus.revoked => VaultAccess.revoked,
      SafAccessStatus.unavailable => VaultAccess.unavailable,
    };
  } on PlatformException catch (e) {
    return e.code == VaultErrorCodes.revoked
        ? VaultAccess.revoked
        : VaultAccess.unavailable;
  }
}

/// [VaultFolderAccess] backed by `ACTION_OPEN_DOCUMENT_TREE` with persisted
/// URI permissions (they survive app restarts and reboots).
class SafFolderAccess implements VaultFolderAccess {
  SafFolderAccess({SafHostApi? api}) : _api = api ?? SafHostApi();

  final SafHostApi _api;

  @override
  Future<Result<VaultFolder?>> pick({VaultFolder? previous}) async {
    final initial = previous?.kind == VaultTargetKind.saf
        ? previous!.handle
        : null;
    final picked = await guardVaultCall(() => _api.pickTree(initial));
    switch (picked) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: null):
        return const Ok(null);
      case Ok(value: final SafTree tree):
        // Re-grant to a different folder: free the old grant (the OS caps
        // persisted grants at 128/512 per app).
        if (initial != null && initial != tree.treeUri) {
          await _releaseUri(initial);
        }
        return Ok(
          VaultFolder(
            kind: VaultTargetKind.saf,
            handle: tree.treeUri,
            displayName: tree.displayName,
          ),
        );
    }
  }

  @override
  Future<VaultAccess> checkAccess(VaultFolder folder) =>
      folder.kind == VaultTargetKind.saf
      ? safCheckAccess(_api, folder.handle)
      // A handle from another platform can never be used here: re-pick.
      : Future.value(VaultAccess.revoked);

  @override
  VaultWriter writerFor(VaultFolder folder) {
    assert(folder.kind == VaultTargetKind.saf, 'not a SAF folder');
    return SafVaultWriter(treeUri: folder.handle, api: _api);
  }

  @override
  Future<void> release(VaultFolder folder) async {
    if (folder.kind == VaultTargetKind.saf) await _releaseUri(folder.handle);
  }

  /// Tree URIs whose read/write grant the OS still holds (reboot-safe).
  Future<Result<List<String>>> persistedTrees() =>
      guardVaultCall(_api.persistedTrees);

  Future<void> _releaseUri(String uri) async {
    // Best effort: a grant that is already gone needs no release.
    await guardVaultCall(() => _api.releaseTree(uri));
  }
}
