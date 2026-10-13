// failWith mirrors the vv-testing fake contract; a setter reads poorly.
// ignore_for_file: use_setters_to_change_properties

import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/vault_path.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';

/// In-memory [VaultWriter]; written notes are kept in [notes].
class FakeVaultWriter implements VaultWriter {
  final Map<String, String> notes = {};
  final Set<String> dirs = {};
  Failure? _failure;

  /// What [checkAccess] reports; anything but `ok` also fails writes.
  VaultAccess access = VaultAccess.ok;

  void failWith(Failure failure) => _failure = failure;

  Result<VaultPath> _guard(String raw, {bool allowRoot = false}) {
    if (_failure case final failure?) return Err(failure);
    switch (access) {
      case VaultAccess.ok:
        break;
      case VaultAccess.revoked:
        return const Err(VaultAccessFailure.revoked());
      case VaultAccess.unavailable:
        return const Err(VaultAccessFailure.unavailable());
    }
    return VaultPath.parse(raw, allowRoot: allowRoot);
  }

  @override
  Future<VaultAccess> checkAccess() async => access;

  @override
  Future<Result<WrittenNote>> write(
    NoteDraft note, {
    bool overwrite = false,
  }) async {
    switch (_guard(note.relativePath)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final path):
        if (notes.containsKey(path.value) && !overwrite) {
          return const Err(VaultFileExistsFailure());
        }
        notes[path.value] = note.markdown;
        return Ok(WrittenNote('fake://${path.value}'));
    }
  }

  @override
  Future<Result<bool>> exists(String relativePath) async =>
      switch (_guard(relativePath)) {
        Err(:final failure) => Err(failure),
        Ok(value: final p) => Ok(
          notes.containsKey(p.value) || dirs.contains(p.value),
        ),
      };

  @override
  Future<Result<void>> mkdirs(String relativeDir) async {
    switch (_guard(relativeDir)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final p):
        dirs.add(p.value);
        return const Ok(null);
    }
  }

  @override
  Future<Result<bool>> delete(String relativePath) async =>
      switch (_guard(relativePath)) {
        Err(:final failure) => Err(failure),
        Ok(value: final p) => Ok(notes.remove(p.value) != null),
      };

  @override
  Future<Result<List<VaultEntry>>> list(String relativeDir) async {
    switch (_guard(relativeDir, allowRoot: true)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final p):
        final prefix = p.isRoot ? '' : '${p.value}/';
        final entries = <VaultEntry>{};
        for (final key in [...notes.keys, ...dirs]) {
          if (!key.startsWith(prefix)) continue;
          final rest = key.substring(prefix.length).split('/');
          entries.add(
            VaultEntry(
              name: rest.first,
              isDirectory: rest.length > 1 || dirs.contains(key),
            ),
          );
        }
        return Ok(entries.toList());
    }
  }
}
