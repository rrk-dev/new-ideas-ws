import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';

/// A validated path relative to a vault root.
///
/// This is a safety check, not the filename sanitizer (EXP-02): it only
/// guarantees that a path cannot escape the vault root or confuse the
/// platform document APIs. Rejected: empty paths (unless `allowRoot`),
/// leading `/`, empty, `.` or `..` segments, backslashes, control characters.
class VaultPath {
  VaultPath._(this.segments);

  /// Parses [raw]; `''` is accepted only with [allowRoot] (the vault root).
  static Result<VaultPath> parse(String raw, {bool allowRoot = false}) {
    if (raw.isEmpty) {
      return allowRoot
          ? Ok(VaultPath._(const []))
          : const Err(StorageFailure('invalid vault path'));
    }
    if (raw.startsWith('/') || raw.contains(r'\')) {
      return const Err(StorageFailure('invalid vault path'));
    }
    final segments = raw.split('/');
    for (final s in segments) {
      if (s.isEmpty || s == '.' || s == '..' || _control.hasMatch(s)) {
        return const Err(StorageFailure('invalid vault path'));
      }
    }
    return Ok(VaultPath._(List.unmodifiable(segments)));
  }

  static final RegExp _control = RegExp(r'[\x00-\x1F\x7F]');

  /// The `/`-separated segments; empty for the vault root.
  final List<String> segments;

  /// Whether this is the vault root.
  bool get isRoot => segments.isEmpty;

  /// The last segment (file or folder name); empty for the root.
  String get name => isRoot ? '' : segments.last;

  /// The parent folder segments.
  List<String> get parent =>
      isRoot ? const [] : segments.sublist(0, segments.length - 1);

  /// Canonical `/`-joined form passed to the platform APIs.
  String get value => segments.join('/');

  @override
  String toString() => 'VaultPath(${segments.length} segments)';
}
