import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';

/// How a vault target is reached on this platform.
enum VaultTargetKind {
  /// Android Storage Access Framework tree URI (EXP-03).
  saf,

  /// iOS or macOS security-scoped bookmark (EXP-04, EXP-09).
  bookmark,

  /// The app's own folder (fallback / default target).
  appLocal,
}

/// A folder the user granted access to.
///
/// [handle] is what `vault_targets.handle` stores: the SAF tree URI on
/// Android, base64 bookmark data on iOS and macOS, an absolute path for
/// app-local. It may identify the folder's location, so it is never logged.
class VaultFolder {
  const VaultFolder({
    required this.kind,
    required this.handle,
    this.displayName,
  });

  final VaultTargetKind kind;
  final String handle;

  /// Folder name for the UI (null when the provider does not report one).
  final String? displayName;

  /// Copy with a refreshed [handle] (iOS re-creates stale bookmarks).
  VaultFolder withHandle(String handle) =>
      VaultFolder(kind: kind, handle: handle, displayName: displayName);

  // Never print the handle (location) or the name.
  @override
  String toString() => 'VaultFolder(${kind.name})';
}

/// Platform folder picking and persistent access for vault targets.
///
/// Implementations: `SafFolderAccess` (Android), `BookmarkFolderAccess`
/// (iOS). Persisting [VaultFolder.handle] is the caller's job
/// (`vault_targets`, EXP-05); the OS grant itself is persisted here.
abstract interface class VaultFolderAccess {
  /// Opens the system folder picker. [previous] (re-grant) pre-selects the
  /// old location; when the user picks a different folder the old grant is
  /// released. `Ok(null)` = the user cancelled.
  Future<Result<VaultFolder?>> pick({VaultFolder? previous});

  /// Checks that [folder] is still writable.
  Future<VaultAccess> checkAccess(VaultFolder folder);

  /// A writer for [folder].
  VaultWriter writerFor(VaultFolder folder);

  /// Drops the OS grant (target deleted by the user).
  Future<void> release(VaultFolder folder);
}
