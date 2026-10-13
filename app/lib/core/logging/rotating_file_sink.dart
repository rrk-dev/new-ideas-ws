import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:vaultvoice/core/logging/logger.dart';

/// Size cap for the on-device log (`vv-privacy-security`: 5 × 2 MB).
@immutable
final class LogRotationConfig {
  const LogRotationConfig({
    this.maxFileBytes = 2 * 1024 * 1024,
    this.maxFiles = 5,
  }) : assert(maxFileBytes > 0, 'maxFileBytes must be positive'),
       assert(maxFiles >= 1, 'keep at least the current file');

  /// A file is rotated before a write would make it larger than this.
  final int maxFileBytes;

  /// Total number of files kept, including the current one.
  final int maxFiles;
}

/// JSON-lines log file in app-private storage with size-based rotation:
/// `vv.log` (current), `vv.1.log` (newest rotated) … `vv.<maxFiles-1>.log`.
///
/// Writes are synchronous and append-only so the last lines before a crash
/// are on disk. Use one sink per isolate and directory.
class RotatingFileSink implements LogSink {
  RotatingFileSink(
    this.directory, {
    this.config = const LogRotationConfig(),
    this.baseName = 'vv',
  });

  final Directory directory;
  final LogRotationConfig config;
  final String baseName;

  RandomAccessFile? _file;
  int _size = 0;

  File get currentFile => _fileAt(0);

  File _fileAt(int index) => File(
    '${directory.path}${Platform.pathSeparator}'
    '$baseName${index == 0 ? '' : '.$index'}.log',
  );

  /// Existing log files, oldest first (the order to read them in).
  List<File> get files =>
      [for (var i = config.maxFiles - 1; i >= 0; i--) _fileAt(i)]
          .where((f) => f.existsSync())
          .toList();

  @override
  void write(LogRecord record) {
    final bytes = utf8.encode('${record.toJsonLine()}\n');
    _file ??= _open();
    if (_size > 0 && _size + bytes.length > config.maxFileBytes) _rotate();
    _file!.writeFromSync(bytes);
    _size += bytes.length;
  }

  RandomAccessFile _open() {
    directory.createSync(recursive: true);
    final raf = currentFile.openSync(mode: FileMode.append);
    _size = raf.lengthSync();
    return raf;
  }

  void _rotate() {
    _file?.closeSync();
    _file = null;
    // Drop the oldest, shift the rest up by one (with maxFiles == 1 the
    // current file itself is the oldest and is simply truncated).
    final oldest = _fileAt(config.maxFiles - 1);
    if (oldest.existsSync()) oldest.deleteSync();
    for (var i = config.maxFiles - 2; i >= 0; i--) {
      final f = _fileAt(i);
      if (f.existsSync()) f.renameSync(_fileAt(i + 1).path);
    }
    _file = _open();
  }

  @override
  Future<void> close() async {
    _file?.closeSync();
    _file = null;
  }
}
