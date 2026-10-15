// failWith mirrors the vv-testing fake contract; a setter reads poorly.
// ignore_for_file: use_setters_to_change_properties

import 'dart:convert';
import 'dart:typed_data';

import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/vault_path.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';

/// In-memory [VaultWriter]; written notes are kept in [notes], raw sidecar
/// bytes ([writeBytes]) in [binaries].
class FakeVaultWriter implements VaultWriter {
  final Map<String, String> notes = {};
  final Map<String, Uint8List> binaries = {};

  /// Number of successful [write] / [writeBytes] calls.
  int writes = 0;
  final Set<String> dirs = {};
  Failure? _failure;

  /// What [checkAccess] reports; anything but `ok` also fails writes.
  VaultAccess access = VaultAccess.ok;

  void failWith(Failure failure) => _failure = failure;

  void clearFailure() => _failure = null;

  /// When set, only [read] fails with it.
  Failure? readFailure;

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
        if (_isFile(path.value) && !overwrite) {
          return const Err(VaultFileExistsFailure());
        }
        binaries.remove(path.value);
        notes[path.value] = note.markdown;
        writes++;
        return Ok(WrittenNote('fake://${path.value}'));
    }
  }

  bool _isFile(String p) => notes.containsKey(p) || binaries.containsKey(p);

  @override
  Future<Result<WrittenNote>> writeBytes(
    String relativePath,
    Uint8List bytes, {
    bool overwrite = false,
  }) async {
    switch (_guard(relativePath)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final path):
        if (_isFile(path.value) && !overwrite) {
          return const Err(VaultFileExistsFailure());
        }
        notes.remove(path.value);
        binaries[path.value] = Uint8List.fromList(bytes);
        writes++;
        return Ok(WrittenNote('fake://${path.value}'));
    }
  }

  @override
  Future<Result<Uint8List?>> read(String relativePath) async {
    if (readFailure case final failure?) return Err(failure);
    switch (_guard(relativePath)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final path):
        if (notes[path.value] case final md?) {
          return Ok(Uint8List.fromList(utf8.encode(md)));
        }
        return Ok(binaries[path.value]);
    }
  }

  @override
  Future<Result<bool>> exists(String relativePath) async =>
      switch (_guard(relativePath)) {
        Err(:final failure) => Err(failure),
        Ok(value: final p) => Ok(_isFile(p.value) || dirs.contains(p.value)),
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
        Ok(value: final p) => Ok(
          (notes.remove(p.value) ?? binaries.remove(p.value)) != null,
        ),
      };

  @override
  Future<Result<List<VaultEntry>>> list(String relativeDir) async {
    switch (_guard(relativeDir, allowRoot: true)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final p):
        final prefix = p.isRoot ? '' : '${p.value}/';
        final entries = <VaultEntry>{};
        for (final key in [...notes.keys, ...binaries.keys, ...dirs]) {
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
