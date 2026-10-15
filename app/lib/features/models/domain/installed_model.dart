import 'package:flutter/foundation.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart'
    show ModelType;

/// A model file on disk (`models_installed` row), as the UI sees it.
@immutable
final class InstalledModel {
  const InstalledModel({
    required this.id,
    required this.version,
    required this.size,
    required this.relativePath,
    required this.installedAt,
    this.type,
  });

  final String id;
  final String version;
  final int size;

  /// Relative to `<appSupport>/vv/` (`models/<id>/<file>`).
  final String relativePath;
  final DateTime installedAt;

  /// Kind of model; lets sideloaded files the catalog does not list appear
  /// in the management list.
  final ModelType? type;
}
