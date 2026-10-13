import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// On-disk layout under `<appSupport>/vv/` (vv-local-database → Files on
/// disk). Application Support on iOS and `filesDir` on Android are
/// app-private and not exposed to the Files app — never Documents.
///
/// The DB stores paths **relative** to [root] because absolute container
/// paths change on iOS reinstall/update; use [resolve] / [relativize].
class StoragePaths {
  StoragePaths(String root) : root = p.normalize(root);

  final String root;

  /// Resolves the platform location (`<appSupport>/vv`).
  static Future<StoragePaths> fromPlatform({
    Future<Directory> Function() appSupport = getApplicationSupportDirectory,
  }) async => StoragePaths(p.join((await appSupport()).path, 'vv'));

  String get dbFile => p.join(root, 'db', 'vaultvoice.sqlite');

  String audioDir(String recordingId) =>
      p.join(root, 'audio', _segment(recordingId));

  String workDir(String jobId) => p.join(root, 'work', _segment(jobId));

  String renderedFile(String recordingId) =>
      p.join(root, 'rendered', '${_segment(recordingId)}.md');

  String get modelsDir => p.join(root, 'models');

  String get logsDir => p.join(root, 'logs');

  /// Absolute path for a stored relative path. Rejects absolute paths and
  /// paths escaping [root] (`..`).
  String resolve(String relative) {
    if (p.isAbsolute(relative)) {
      throw ArgumentError.value(relative, 'relative', 'must be relative');
    }
    final full = p.normalize(p.join(root, relative));
    if (!p.isWithin(root, full)) {
      throw ArgumentError.value(relative, 'relative', 'escapes storage root');
    }
    return full;
  }

  /// Relative path to persist for an absolute path inside [root].
  String relativize(String absolute) {
    final full = p.normalize(absolute);
    if (!p.isWithin(root, full)) {
      throw ArgumentError.value(absolute, 'absolute', 'outside storage root');
    }
    return p.relative(full, from: root);
  }

  static String _segment(String id) {
    if (id.isEmpty || id.contains('/') || id.contains(r'\') || id == '..') {
      throw ArgumentError.value(id, 'id', 'not a single path segment');
    }
    return id;
  }
}
