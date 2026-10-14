import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// App-private directories under `<appSupport>/vv/` (never user-visible,
/// never a vault). Backup exclusion / file protection: SEC-01.
@immutable
final class AppPaths {
  const AppPaths({required this.root, required this.temp});

  /// Resolves the platform directories via `path_provider`.
  static Future<AppPaths> resolve() async {
    final support = await getApplicationSupportDirectory();
    final temp = await getTemporaryDirectory();
    return AppPaths(
      root: Directory(_join([support.path, 'vv'])),
      temp: Directory(_join([temp.path, 'vv'])),
    );
  }

  /// `<appSupport>/vv`.
  final Directory root;

  /// `<tmp>/vv`: scratch files such as the diagnostics zip being shared.
  final Directory temp;

  /// Rotating log files.
  Directory get logs => Directory(_join([root.path, 'logs']));

  /// Local crash reports (REL-02): `native-current.vvcrash` (pre-opened by
  /// the native signal handler) and harvested `*.vvcrash` / `*.vvdart`.
  Directory get crashReports => Directory(_join([root.path, 'crash']));

  /// Copies of crash reports handed to the share sheet.
  Directory get crashShare => Directory(_join([temp.path, 'crash-share']));

  /// Per-job performance metrics (JSON lines).
  File get metricsFile => File(_join([root.path, 'metrics', 'metrics.jsonl']));

  /// Where the diagnostics zip is written before it is handed to the share
  /// sheet (old exports are deleted on the next export).
  Directory get diagnosticsExport =>
      Directory(_join([temp.path, 'diagnostics']));

  static String _join(List<String> parts) => parts.join(Platform.pathSeparator);
}
