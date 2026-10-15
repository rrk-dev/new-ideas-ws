import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';

/// Unpacks a **verified** (size + SHA-256) Core ML encoder zip from the
/// Hugging Face whisper.cpp repo (`ggml-<name>-encoder.mlmodelc.zip`) into
/// `<targetDir>/<dirName>/`, next to the STT model file, which is where
/// whisper.cpp looks for it (ADR-STT-01; `vv-native-build` → Core ML).
///
/// Only entries under `<dirName>/` are written. macOS resource-fork entries
/// (`__MACOSX/`, `._*`), symlinks and anything that would escape the target
/// (absolute paths, `..`) are skipped or rejected. Extraction goes to a
/// temporary sibling first and is renamed into place, so a kill mid-unzip
/// never leaves a half-written `.mlmodelc` that Core ML would try to load.
/// Runs on a background isolate (the large-v3-turbo encoder is 1.2 GB).
Future<Result<void>> installCoreMlEncoderZip({
  required String zipPath,
  required String targetDir,
  required String dirName,
}) => Isolate.run(() => extractCoreMlEncoderZip(zipPath, targetDir, dirName));

/// Synchronous core of [installCoreMlEncoderZip] (tests call it directly).
Result<void> extractCoreMlEncoderZip(
  String zipPath,
  String targetDir,
  String dirName,
) {
  if (dirName.isEmpty ||
      dirName.contains('/') ||
      dirName.contains(r'\') ||
      !dirName.endsWith('.mlmodelc')) {
    return const Err(StorageFailure('coreml: bad encoder directory name'));
  }
  final tmp = Directory(p.join(targetDir, '.$dirName.tmp'));
  final dest = Directory(p.join(targetDir, dirName));
  InputFileStream? input;
  try {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    tmp.createSync(recursive: true);
    input = InputFileStream(zipPath);
    final archive = ZipDecoder().decodeStream(input);
    var written = 0;
    for (final entry in archive) {
      final name = entry.name.replaceAll(r'\', '/');
      if (name.startsWith('__MACOSX/') ||
          p.posix.basename(name).startsWith('._')) {
        continue;
      }
      if (!name.startsWith('$dirName/')) continue;
      final rel = name.substring(dirName.length + 1);
      if (rel.isEmpty) continue;
      final parts = p.posix.split(rel);
      if (p.posix.isAbsolute(rel) ||
          parts.contains('..') ||
          parts.contains('.')) {
        throw const _Unsafe();
      }
      if (entry.isSymbolicLink) throw const _Unsafe();
      final out = p.joinAll([tmp.path, ...parts]);
      if (!p.isWithin(tmp.path, out)) throw const _Unsafe();
      if (!entry.isFile) {
        Directory(out).createSync(recursive: true);
        continue;
      }
      Directory(p.dirname(out)).createSync(recursive: true);
      final sink = OutputFileStream(out);
      try {
        entry.writeContent(sink);
      } finally {
        sink.closeSync();
      }
      written++;
    }
    if (written == 0) throw const _Unsafe();
    if (dest.existsSync()) dest.deleteSync(recursive: true);
    tmp.renameSync(dest.path);
    return const Ok(null);
  } on _Unsafe {
    _cleanup(tmp);
    return const Err(StorageFailure('coreml: unexpected zip layout'));
  } on ArchiveException {
    _cleanup(tmp);
    return const Err(StorageFailure('coreml: unreadable zip'));
  } on FileSystemException catch (e) {
    _cleanup(tmp);
    return Err(StorageFailure('coreml unzip io: ${e.osError?.errorCode ?? 0}'));
  } finally {
    input?.closeSync();
  }
}

void _cleanup(Directory d) {
  try {
    if (d.existsSync()) d.deleteSync(recursive: true);
  } on FileSystemException {
    // Left for the next attempt (it deletes the temp dir first).
  }
}

class _Unsafe implements Exception {
  const _Unsafe();
}
