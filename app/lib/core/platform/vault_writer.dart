import 'package:vaultvoice/core/errors/result.dart';

/// Whether a vault folder can be written right now.
///
/// - [ok]: the grant/bookmark is valid and the folder is reachable.
/// - [revoked]: the user (or OS) withdrew access, or the folder was moved or
///   deleted — the user must re-pick the folder (re-grant).
/// - [unavailable]: access is still granted but the storage is temporarily
///   unreachable (SD card removed, iCloud offline, provider not running) —
///   retry later (export outbox, EXP-06).
enum VaultAccess { ok, revoked, unavailable }

/// A Markdown note to write into the user's vault.
class NoteDraft {
  const NoteDraft({required this.relativePath, required this.markdown});

  /// Path relative to the vault root, `/`-separated (`Meetings/note.md`).
  final String relativePath;
  final String markdown;
}

/// Where a note ended up (opaque token, e.g. a SAF URI or bookmark path).
class WrittenNote {
  const WrittenNote(this.location);

  final String location;
}

/// A direct child of a vault directory.
class VaultEntry {
  const VaultEntry({required this.name, required this.isDirectory});

  final String name;
  final bool isDirectory;

  @override
  String toString() => 'VaultEntry(${isDirectory ? 'dir' : 'file'})';
}

/// Writes notes into one user-chosen vault folder (a "vault target").
///
/// All paths are relative to the target root and validated with
/// `VaultPath` — absolute paths, `.`/`..` segments and backslashes are
/// rejected. Implementations: `SafVaultWriter` (Android),
/// `BookmarkVaultWriter` (iOS), `AppLocalVaultWriter` (fallback).
/// Failures are content-free (`vv-privacy-security`).
abstract interface class VaultWriter {
  /// Checks the folder grant and reachability without writing.
  Future<VaultAccess> checkAccess();

  /// Writes [note], creating missing sub-folders. An existing file is
  /// replaced only when [overwrite] is true; otherwise the result is a
  /// `VaultFileExistsFailure`.
  Future<Result<WrittenNote>> write(NoteDraft note, {bool overwrite = false});

  /// Whether a file or folder exists at [relativePath].
  Future<Result<bool>> exists(String relativePath);

  /// Creates [relativeDir] and all missing parents.
  Future<Result<void>> mkdirs(String relativeDir);

  /// Deletes the file at [relativePath]; `Ok(false)` when it did not exist.
  Future<Result<bool>> delete(String relativePath);

  /// Direct children of [relativeDir] (`''` = vault root).
  Future<Result<List<VaultEntry>>> list(String relativeDir);
}
