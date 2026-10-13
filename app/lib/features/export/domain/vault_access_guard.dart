import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';
import 'package:vaultvoice/features/export/domain/vault_folder.dart';

/// What the UI should do about a vault target before exporting.
enum VaultAccessAction {
  /// Writable: export now.
  none,

  /// Access was revoked / folder moved: prompt the user to re-pick it.
  promptRegrant,

  /// Storage temporarily unreachable: keep the export queued and retry.
  retryLater,
}

/// Detects lost folder access and drives the re-grant flow.
///
/// The settings/export UI (APP-03, EXP-06) calls [check] and, on
/// [VaultAccessAction.promptRegrant], shows a prompt whose "Choose folder"
/// button calls [regrant].
class VaultAccessGuard {
  const VaultAccessGuard(this._access);

  final VaultFolderAccess _access;

  /// Maps the current access state of [folder] to a UI action.
  Future<VaultAccessAction> check(VaultFolder folder) async =>
      actionFor(await _access.checkAccess(folder));

  /// Pure mapping from [VaultAccess] to the UI action.
  static VaultAccessAction actionFor(VaultAccess access) => switch (access) {
    VaultAccess.ok => VaultAccessAction.none,
    VaultAccess.revoked => VaultAccessAction.promptRegrant,
    VaultAccess.unavailable => VaultAccessAction.retryLater,
  };

  /// Re-opens the picker at [folder]'s location. Returns the (possibly
  /// different) folder once it is verified writable, `Ok(null)` when the user
  /// cancels, or a [VaultAccessFailure] when the new pick is not writable.
  Future<Result<VaultFolder?>> regrant(VaultFolder folder) async {
    final picked = await _access.pick(previous: folder);
    switch (picked) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: null):
        return const Ok(null);
      case Ok(value: final VaultFolder next):
        return switch (await _access.checkAccess(next)) {
          VaultAccess.ok => Ok(next),
          VaultAccess.revoked => const Err(VaultAccessFailure.revoked()),
          VaultAccess.unavailable => const Err(
            VaultAccessFailure.unavailable(),
          ),
        };
    }
  }
}
