import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/vault_path.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';

/// [VaultWriter] for the app's own folder — the fallback target when no
/// folder was picked or every routed target failed (EXP-05).
///
/// Root: Android `filesDir/vault` (app-private), iOS `Documents/` (visible in
/// Files under "On My iPhone › VaultVoice", EXP-04). Writes are atomic: the
/// note goes to `.<timestamp>.vvtmp` first and is renamed over the target.
class AppLocalVaultWriter implements VaultWriter {
  /// The resolver returns the vault directory lazily (from a host API).
  AppLocalVaultWriter(this._resolveRoot);

  /// Writer over a known directory (tests, iOS Documents).
  AppLocalVaultWriter.at(Directory root) : this(() async => root);

  final Future<Directory> Function() _resolveRoot;
  Directory? _root;

  Future<Directory> _rootDir() async => _root ??= await _resolveRoot();

  @override
  Future<VaultAccess> checkAccess() async {
    try {
      final root = await _rootDir();
      if (!root.existsSync()) await root.create(recursive: true);
      return VaultAccess.ok;
    } on Exception {
      return VaultAccess.unavailable;
    }
  }

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
  }) => _io(relativePath, (root, path) async {
    final target = _fileAt(root, path.segments);
    final type = FileSystemEntity.typeSync(target.path, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      return const Err(StorageFailure('invalid vault path'));
    }
    if (type != FileSystemEntityType.notFound && !overwrite) {
      return const Err(VaultFileExistsFailure());
    }
    await target.parent.create(recursive: true);
    final tmp = File(
      '${target.parent.path}${Platform.pathSeparator}'
      '.${DateTime.now().microsecondsSinceEpoch}.vvtmp',
    );
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(target.path);
    return Ok(WrittenNote(target.uri.toString()));
  });

  @override
  Future<Result<Uint8List?>> read(String relativePath) =>
      _io(relativePath, (root, path) async {
        final f = _fileAt(root, path.segments);
        final type = FileSystemEntity.typeSync(f.path, followLinks: false);
        if (type == FileSystemEntityType.notFound) return const Ok(null);
        if (type == FileSystemEntityType.directory) {
          return const Err(StorageFailure('invalid vault path'));
        }
        return Ok(await f.readAsBytes());
      });

  @override
  Future<Result<bool>> exists(String relativePath) =>
      _io(relativePath, (root, path) async {
        final p = _fileAt(root, path.segments).path;
        return Ok(
          FileSystemEntity.typeSync(p, followLinks: false) !=
              FileSystemEntityType.notFound,
        );
      });

  @override
  Future<Result<void>> mkdirs(String relativeDir) =>
      _io(relativeDir, (root, path) async {
        await Directory(_fileAt(root, path.segments).path)
            .create(recursive: true);
        return const Ok(null);
      });

  @override
  Future<Result<bool>> delete(String relativePath) =>
      _io(relativePath, (root, path) async {
        final f = _fileAt(root, path.segments);
        final type = FileSystemEntity.typeSync(f.path, followLinks: false);
        if (type == FileSystemEntityType.notFound) return const Ok(false);
        if (type == FileSystemEntityType.directory) {
          return const Err(StorageFailure('invalid vault path'));
        }
        await f.delete();
        return const Ok(true);
      });

  @override
  Future<Result<List<VaultEntry>>> list(String relativeDir) =>
      _io(relativeDir, allowRoot: true, (root, path) async {
        final dir = Directory(_fileAt(root, path.segments).path);
        if (!dir.existsSync()) {
          return const Err(StorageFailure('vault path not found'));
        }
        final entries = <VaultEntry>[];
        await for (final e in dir.list(followLinks: false)) {
          final name = e.path.split(Platform.pathSeparator).last;
          // Hide our own in-flight temp files.
          if (name.endsWith('.vvtmp')) continue;
          entries.add(VaultEntry(name: name, isDirectory: e is Directory));
        }
        entries.sort((a, b) => a.name.compareTo(b.name));
        return Ok(entries);
      });

  File _fileAt(Directory root, List<String> segments) =>
      File([root.path, ...segments].join(Platform.pathSeparator));

  Future<Result<T>> _io<T>(
    String relativePath,
    Future<Result<T>> Function(Directory root, VaultPath path) body, {
    bool allowRoot = false,
  }) async {
    switch (VaultPath.parse(relativePath, allowRoot: allowRoot)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final path):
        try {
          return await body(await _rootDir(), path);
        } on FileSystemException catch (e) {
          // OS error codes only — the message/path may contain a file name.
          return Err(StorageFailure('vault io error ${e.osError?.errorCode}'));
        }
    }
  }
}
