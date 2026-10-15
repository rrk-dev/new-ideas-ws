import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/app_settings_launcher.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';
import 'package:vaultvoice/features/export/domain/vault_folder.dart';

import 'fake_vault_writer.dart';

/// Records "Open settings" taps; [opens] decides the platform answer.
class FakeAppSettingsLauncher implements AppSettingsLauncher {
  FakeAppSettingsLauncher({this.opens = true});

  bool opens;
  int calls = 0;

  @override
  Future<bool> openAppSettings() async {
    calls++;
    return opens;
  }
}

/// Folder picker whose answer the test scripts: a folder, null (cancelled)
/// or a failure (access refused / picker unavailable).
class FakeVaultFolderAccess implements VaultFolderAccess {
  FakeVaultFolderAccess(this.answer);

  Result<VaultFolder?> answer;
  int picks = 0;

  @override
  Future<Result<VaultFolder?>> pick({VaultFolder? previous}) async {
    picks++;
    return answer;
  }

  @override
  Future<VaultAccess> checkAccess(VaultFolder folder) async => VaultAccess.ok;

  @override
  VaultWriter writerFor(VaultFolder folder) => FakeVaultWriter();

  @override
  Future<void> release(VaultFolder folder) async {}
}

const Result<VaultFolder?> kFolderRefused = Err(
  PermissionFailure('vault folder'),
);
