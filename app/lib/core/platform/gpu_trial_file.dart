import 'dart:convert';
import 'dart:io';

import 'package:vaultvoice/core/platform/backend_policy.dart';

/// Durable persistence for the shared [GpuTrialGuard] in one small JSON file
/// under the app-private root (e.g. `AppPaths.root/gpu_trials.json`).
///
/// Writes are flushed and atomically renamed **before** the caller starts
/// native GPU init, so a driver crash right after [GpuTrialGuard.begin]
/// leaves the `running` marker behind (LLM-03 AC2 / STT-02). Holds backend
/// family names only — no content. A corrupt or unreadable file reads as
/// empty (start clean rather than crash).
GpuTrialGuard fileGpuTrialGuard(File file) {
  Map<String, Object?> load() {
    try {
      if (!file.existsSync()) return {};
      final v = jsonDecode(file.readAsStringSync());
      return v is Map<String, Object?> ? v : {};
    } on FormatException {
      return {};
    } on FileSystemException {
      return {};
    }
  }

  return GpuTrialGuard(
    read: (key) async {
      final v = load()[key];
      return v is String ? v : null;
    },
    write: (key, value) async {
      final m = load();
      if (value == null) {
        m.remove(key);
      } else {
        m[key] = value;
      }
      file.parent.createSync(recursive: true);
      File('${file.path}.tmp')
        ..writeAsStringSync(jsonEncode(m), flush: true)
        ..renameSync(file.path);
    },
  );
}
