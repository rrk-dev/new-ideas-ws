import 'package:flutter/foundation.dart';

/// A model file on disk (`models_installed` row), as the UI sees it.
@immutable
final class InstalledModel {
  const InstalledModel({
    required this.id,
    required this.version,
    required this.size,
    required this.relativePath,
    required this.installedAt,
  });

  final String id;
  final String version;
  final int size;

  /// Relative to `<appSupport>/vv/` (`models/<id>/<file>`).
  final String relativePath;
  final DateTime installedAt;
}
