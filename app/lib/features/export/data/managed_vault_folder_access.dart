import 'dart:typed_data';

import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';
import 'package:vaultvoice/features/export/domain/vault_folder.dart';
import 'package:vaultvoice/features/licensing/domain/managed_config.dart';

/// [PermissionFailure.permission] of a folder kind the organisation forbids.
const kManagedTargetKindPermission = 'managed target kind';

/// MDM `allowed_target_kinds` (LIC-04) over a [VaultFolderAccess].
///
/// A kind the organisation does not allow cannot be picked, and an
/// existing target of that kind receives no writes (its exports stay queued
/// until the policy changes). The app's own folder is always allowed.
class ManagedVaultFolderAccess implements VaultFolderAccess {
  const ManagedVaultFolderAccess(
    this._inner, {
    required this.pickKind,
    required this.policy,
  });

  final VaultFolderAccess _inner;

  /// The kind of folder this platform's picker returns.
  final VaultTargetKind pickKind;

  /// The current policy (not cached by the caller).
  final ManagedConfig Function() policy;

  static String nameOf(VaultTargetKind kind) => switch (kind) {
    VaultTargetKind.saf => ManagedTargetKinds.saf,
    VaultTargetKind.bookmark => ManagedTargetKinds.bookmark,
    VaultTargetKind.appLocal => ManagedTargetKinds.appLocal,
  };

  bool _allows(VaultTargetKind kind) => policy().allowsTargetKind(nameOf(kind));

  @override
  Future<Result<VaultFolder?>> pick({VaultFolder? previous}) async {
    if (!_allows(pickKind)) {
      return const Err(PermissionFailure(kManagedTargetKindPermission));
    }
    return await _inner.pick(previous: previous);
  }

  @override
  Future<VaultAccess> checkAccess(VaultFolder folder) async =>
      _allows(folder.kind)
      ? await _inner.checkAccess(folder)
      : VaultAccess.unavailable;

  @override
  VaultWriter writerFor(VaultFolder folder) =>
      _allows(folder.kind) ? _inner.writerFor(folder) : const _BlockedWriter();

  @override
  Future<void> release(VaultFolder folder) => _inner.release(folder);
}

class _BlockedWriter implements VaultWriter {
  const _BlockedWriter();

  static const _blocked = PermissionFailure(kManagedTargetKindPermission);

  @override
  Future<VaultAccess> checkAccess() async => VaultAccess.unavailable;

  @override
  Future<Result<WrittenNote>> write(
    NoteDraft note, {
    bool overwrite = false,
  }) async => const Err(_blocked);

  @override
  Future<Result<WrittenNote>> writeBytes(
    String relativePath,
    Uint8List bytes, {
    bool overwrite = false,
  }) async => const Err(_blocked);

  @override
  Future<Result<Uint8List?>> read(String relativePath) async =>
      const Err(_blocked);

  @override
  Future<Result<bool>> exists(String relativePath) async => const Err(_blocked);

  @override
  Future<Result<void>> mkdirs(String relativeDir) async => const Err(_blocked);

  @override
  Future<Result<bool>> delete(String relativePath) async => const Err(_blocked);

  @override
  Future<Result<List<VaultEntry>>> list(String relativeDir) async =>
      const Err(_blocked);
}
