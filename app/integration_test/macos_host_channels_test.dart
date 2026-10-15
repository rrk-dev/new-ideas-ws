import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/security/key_vault.dart';
import 'package:vaultvoice/core/security/storage_protection.dart';
import 'package:vaultvoice/features/export/data/pigeon/bookmark_api.g.dart';
import 'package:vaultvoice/features/licensing/data/purchase_api.g.dart';
import 'package:vaultvoice/features/models/data/model_download_channel.dart';
import 'package:vaultvoice/features/recording/data/method_channel_call_guard.dart';
import 'package:vaultvoice/features/recording/data/method_channel_disk_space_probe.dart';
import 'package:vaultvoice/features/recording/data/method_channel_recording_indicator.dart';
import 'package:vaultvoice/features/recording/data/pigeon/audio_import_api.g.dart';
import 'package:vaultvoice/features/recording/domain/recording_indicator.dart';

/// FND-09 macOS host check: every platform channel the Dart side calls on
/// macOS is answered by `app/macos/Runner` (no `MissingPluginException`).
/// Does not open System Settings, Touch ID or the folder panel; those rows
/// are in docs/test-plans/device/FND-09.md.
///   cd app && fvm flutter test integration_test/macos_host_channels_test.dart \
///     -d macos --flavor dev
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final onMac = Platform.isMacOS;

  testWidgets('[FND-09/AC2] storage_info and model_download answer', (_) async {
    final dir = Directory.systemTemp.path;
    final free = await const MethodChannelDiskSpaceProbe().freeBytes(dir);
    expect(free, isA<Ok<int>>());
    expect((free as Ok<int>).value, greaterThan(0));

    const platform = MethodChannelDownloadPlatform();
    expect(await platform.freeBytes(dir), greaterThan(0));
    final net = await platform.networkStatus();
    expect(net.connected || !net.connected, isTrue);
    await platform.start('check');
    await platform.stop();
  }, skip: !onMac);

  testWidgets('[FND-09/AC2] call guard answers inCall=false', (_) async {
    final guard = MethodChannelCallGuard();
    final inCall = await guard.isInCall();
    expect(inCall, isA<Ok<bool>>());
    expect((inCall as Ok<bool>).value, isFalse);
  }, skip: !onMac);

  testWidgets('[FND-09/AC2] recording indicator acknowledges', (_) async {
    final indicator = MethodChannelRecordingIndicator();
    const content = IndicatorContent(
      recording: true,
      title: 'VaultVoice',
      text: 'Recording',
      actions: [IndicatorAction.stop],
    );
    expect(await indicator.show(content), isA<Ok<void>>());
    await indicator.hide();
  }, skip: !onMac);

  testWidgets('[FND-09/AC2] secure_storage and privacy_screen answer', (
    _,
  ) async {
    const vault = MethodChannelKeyVault();
    final key = await vault.getOrCreateKey('fnd09.check');
    expect(key, isA<Ok<VaultKey>>());
    final again = await vault.getOrCreateKey('fnd09.check');
    expect(
      Uint8List.fromList((again as Ok<VaultKey>).value.bytes),
      Uint8List.fromList((key as Ok<VaultKey>).value.bytes),
    );
    expect(await vault.deleteKey('fnd09.check'), isA<Ok<void>>());

    final info = await const MethodChannelStorageProtection().protectDirectory(
      '${Directory.systemTemp.path}/fnd09-protect',
    );
    expect(info, isA<Ok<StorageProtectionInfo>>());

    await const MethodChannel('vaultvoice/privacy_screen')
        .invokeMethod<void>('setEnabled', {'enabled': false});
  }, skip: !onMac);

  testWidgets('[FND-09/AC2] bookmark, import and purchase hosts answer', (
    _,
  ) async {
    final docs = await BookmarkHostApi().appDocumentsPath();
    expect(docs, isNotEmpty);
    await expectLater(
      BookmarkHostApi().checkAccess('not-base64!'),
      throwsA(isA<PlatformException>()),
    );
    expect(await AudioImportHostApi().takePendingShares(), isEmpty);
    await expectLater(
      AudioImportHostApi().decodeToPcm('/nonexistent.wav', '/nonexistent.pcm'),
      throwsA(isA<PlatformException>()),
    );
    await expectLater(
      PurchaseHostApi().products(),
      throwsA(
        isA<PlatformException>().having((e) => e.code, 'code', 'unavailable'),
      ),
    );
  }, skip: !onMac);
}
