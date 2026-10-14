import 'dart:convert';
import 'dart:io';

import 'package:vaultvoice/features/extraction/domain/gpu_backend_guard.dart';

/// [BackendHealthStore] in one small JSON file under the app-private root
/// (`AppPaths.root/llm_backend_health.json`). Writes are synchronous and
/// flushed so the pending marker survives a native crash right after
/// [writePending]. Contains only backend/GPU identifiers — no content.
final class FileBackendHealthStore implements BackendHealthStore {
  FileBackendHealthStore(this.file);

  final File file;

  Map<String, Object?> _read() {
    try {
      if (!file.existsSync()) return {};
      final v = jsonDecode(file.readAsStringSync());
      return v is Map<String, Object?> ? v : {};
    } on FormatException {
      return {}; // corrupt file: start clean rather than crash the app
    } on FileSystemException {
      return {};
    }
  }

  void _write(Map<String, Object?> v) {
    file.parent.createSync(recursive: true);
    File('${file.path}.tmp')
      ..writeAsStringSync(jsonEncode(v), flush: true)
      ..renameSync(file.path);
  }

  @override
  Set<String> readDisabled() {
    final d = _read()['disabled'];
    return d is List ? d.whereType<String>().toSet() : <String>{};
  }

  @override
  void writeDisabled(Set<String> keys) =>
      _write({..._read(), 'disabled': (keys.toList()..sort())});

  @override
  String? readPending() {
    final p = _read()['pending'];
    return p is String ? p : null;
  }

  @override
  void writePending(String? key) => _write({..._read(), 'pending': key});
}
