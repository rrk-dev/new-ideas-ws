import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/export/domain/filename_pattern.dart';
import 'package:vaultvoice/features/export/domain/filename_sanitizer.dart';

/// What to do when the note path is already taken by a file that is not
/// this recording's unchanged note.
enum CollisionMode {
  /// Write next to it as `<name>-2.md`, `-3`, … (default; never loses data).
  suffix,

  /// Replace it — but only when it is the note we wrote for this recording
  /// (`exports.rel_path`), e.g. after the user edited it. A foreign file is
  /// never replaced: it falls back to [suffix].
  overwrite,

  /// Leave the existing file and do not write.
  skip,
}

/// The `exports` row of this recording × target (stable identity).
class PriorExport {
  const PriorExport({required this.relPath, required this.contentHash});

  final String relPath;

  /// Hash of the content we last wrote there.
  final String contentHash;
}

/// Why a plan was chosen (for the export log; content-free).
enum PlanReason {
  /// No file at the path: create it.
  newFile,

  /// Re-export: our previous note is replaced in place.
  updateOwn,

  /// Re-export with identical content: nothing to write.
  unchanged,

  /// The path was taken; a `-N` suffix was added.
  suffixed,

  /// Our previous note was edited by the user and is replaced
  /// ([CollisionMode.overwrite]).
  overwroteEdited,

  /// The path was taken and [CollisionMode.skip] left it alone.
  skippedCollision,
}

/// Outcome of [planExport].
sealed class ExportPlan {
  const ExportPlan(this.relPath, this.reason);

  final String relPath;
  final PlanReason reason;
}

/// Write the note to [relPath]; [overwrite] is passed to
/// `VaultWriter.write`.
final class WritePlan extends ExportPlan {
  const WritePlan(super.relPath, super.reason, {required this.overwrite});

  final bool overwrite;
}

/// Do not write. [relPath] is the existing note (for [PlanReason.unchanged]
/// it stays the recording's export path).
final class SkipPlan extends ExportPlan {
  const SkipPlan(super.relPath, super.reason);
}

/// Picks where a note goes in one vault target (EXP-02).
///
/// Stable identity first: when [prior] (this recording's `exports` row)
/// exists, its `rel_path` is the note's path for good — re-exports update
/// that file instead of creating a duplicate, even if the title/pattern
/// changed. [currentHash] (optional, needs a vault read) detects a user
/// edit of that file; then [mode] decides. Otherwise [desired] (the
/// rendered pattern) is used, and a taken path — an existing file, or a
/// path another recording's export claims ([claimedByOthers], compared
/// case-insensitively after NFC) — is a collision for [mode].
Future<Result<ExportPlan>> planExport({
  required NotePath desired,
  required String contentHash,
  required CollisionMode mode,
  required Future<Result<bool>> Function(String relPath) exists,
  PriorExport? prior,
  Set<String> claimedByOthers = const {},
  Future<String?> Function(String relPath)? currentHash,
  int maxSuffix = 9999,
}) async {
  final claimed = {for (final c in claimedByOthers) pathKey(c)};

  Future<Result<bool>> taken(String relPath) async =>
      claimed.contains(pathKey(relPath))
      ? const Ok(true)
      : await exists(relPath);

  Future<Result<ExportPlan>> suffixed({bool tryBase = false}) async {
    for (var n = tryBase ? 1 : 2; n <= maxSuffix; n++) {
      final candidate = n == 1 ? desired.path : desired.withSuffix(n);
      if (prior != null && pathKey(candidate) == pathKey(prior.relPath)) {
        continue; // our edited note keeps its place
      }
      switch (await taken(candidate)) {
        case Err(:final failure):
          return Err(failure);
        case Ok(value: false):
          return Ok(
            WritePlan(
              candidate,
              n == 1 ? PlanReason.newFile : PlanReason.suffixed,
              overwrite: false,
            ),
          );
        case Ok():
          continue;
      }
    }
    return const Err(StorageFailure('no free note name'));
  }

  if (prior != null) {
    final own = prior.relPath;
    switch (await exists(own)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: false):
        // Deleted or moved by the user: re-create it at the same path.
        return Ok(WritePlan(own, PlanReason.newFile, overwrite: false));
      case Ok():
        break;
    }
    final onDisk = currentHash == null ? null : await currentHash(own);
    final edited = onDisk != null && onDisk != prior.contentHash;
    if (!edited) {
      return Ok(
        prior.contentHash == contentHash
            ? SkipPlan(own, PlanReason.unchanged)
            : WritePlan(own, PlanReason.updateOwn, overwrite: true),
      );
    }
    return switch (mode) {
      CollisionMode.overwrite => Ok(
        WritePlan(own, PlanReason.overwroteEdited, overwrite: true),
      ),
      CollisionMode.skip => Ok(SkipPlan(own, PlanReason.skippedCollision)),
      // Keep the user's edited note; the new export gets its own file.
      CollisionMode.suffix => await suffixed(tryBase: true),
    };
  }

  switch (await taken(desired.path)) {
    case Err(:final failure):
      return Err(failure);
    case Ok(value: false):
      return Ok(WritePlan(desired.path, PlanReason.newFile, overwrite: false));
    case Ok():
      break;
  }
  return switch (mode) {
    CollisionMode.skip => Ok(
      SkipPlan(desired.path, PlanReason.skippedCollision),
    ),
    // Never replace a file we did not write for this recording.
    CollisionMode.overwrite || CollisionMode.suffix => await suffixed(),
  };
}
