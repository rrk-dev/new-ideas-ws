import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';
import 'package:vaultvoice/features/export/data/managed_vault_folder_access.dart';
import 'package:vaultvoice/features/export/domain/vault_folder.dart';
import 'package:vaultvoice/features/licensing/data/managed_config_source.dart';
import 'package:vaultvoice/features/licensing/domain/managed_config.dart';
import 'package:vaultvoice/features/retention/domain/retention_policy.dart';
import 'package:vaultvoice/features/settings/domain/setting_definitions.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';

class _Inner implements VaultFolderAccess {
  int picks = 0;

  @override
  Future<Result<VaultFolder?>> pick({VaultFolder? previous}) async {
    picks++;
    return const Ok(null);
  }

  @override
  Future<VaultAccess> checkAccess(VaultFolder folder) async => VaultAccess.ok;

  @override
  VaultWriter writerFor(VaultFolder folder) => throw UnimplementedError();

  @override
  Future<void> release(VaultFolder folder) async {}
}

void main() {
  group('[LIC-04/AC1] ManagedConfig.parse', () {
    test('valid dictionary is applied', () {
      final c = ManagedConfig.parse({
        'audio_retention_days': 30,
        'network_disabled': true,
        'force_app_lock': 'true',
        'max_recording_minutes': 60,
        'allowed_target_kinds': ['saf'],
        'lock_settings': ['ask.enabled', 'nope.unknown'],
      });
      expect(c.audioRetentionDays, 30);
      expect(c.networkDisabled, isTrue);
      expect(c.forceAppLock, isTrue);
      expect(c.maxRecordingMinutes, 60);
      expect(c.allowsTargetKind('saf'), isTrue);
      expect(c.allowsTargetKind('app_local'), isTrue);
      expect(c.allowsTargetKind('bookmark'), isFalse);
      expect(c.lockSettings, {'ask.enabled'});
    });

    test('invalid values and unknown keys are dropped, names only', () {
      final c = ManagedConfig.parse({
        'audio_retention_days': 0,
        'max_recording_minutes': 100000,
        'network_disabled': 'maybe',
        'surprise': 'secret-value',
      });
      expect(c.audioRetentionDays, isNull);
      expect(c.maxRecordingMinutes, isNull);
      expect(c.networkDisabled, isFalse);
      expect(
        c.ignoredKeys,
        containsAll(['audio_retention_days', 'max_recording_minutes']),
      );
      expect(c.ignoredKeys, contains('surprise'));
      expect(c.ignoredKeys.join(), isNot(contains('secret-value')));
    });

    test('profile packs never accept URLs', () {
      final c = ManagedConfig.parse({
        'profile_packs': ['https://example.com/a.vvprofile', 'QUJD'],
      });
      expect(c.profilePacks, isEmpty);
      expect(c.ignoredKeys, contains('profile_packs'));
      expect(
        ManagedConfig.parse({
          'profile_packs': ['QUJD'],
        }).profilePacks,
        ['QUJD'],
      );
    });

    test('nothing can loosen: false flags and empty input change nothing', () {
      final c = ManagedConfig.parse({
        'force_app_lock': false,
        'network_disabled': false,
        'disable_custom_models': false,
        'force_consent_confirmation': false,
      });
      expect(c.forceAppLock, isFalse);
      expect(
        c.toManagedSettings().values.containsKey('security.app_lock'),
        isFalse,
      );
      expect(ManagedConfig.parse({}).isEmpty, isTrue);
    });

    test('maps to forced and locked settings', () {
      final s = ManagedConfig.parse({
        'force_app_lock': true,
        'network_disabled': true,
        'audio_retention_days': 14,
      }).toManagedSettings();
      expect(s.values[SettingKeys.securityAppLock], isTrue);
      expect(s.values[SettingKeys.networkOffline], isTrue);
      expect(s.values[SettingKeys.audioRetention], 'days_14');
      expect(s.isManaged(SettingKeys.audioRetention), isTrue);
    });

    test('managed days_N retention is understood', () {
      expect(RetentionOption.daysOf('days_14'), 14);
      expect((RetentionPolicy.parse('days_14') as DeleteAfterDays).days, 14);
      expect(RetentionPolicy.parse('days_0'), isA<KeepForever>());
    });
  });

  group('[LIC-04/AC1] PlatformManagedConfigSource', () {
    const channel = MethodChannel('test/managed_config');
    TestWidgetsFlutterBinding.ensureInitialized();

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('reads the JSON the platform returns', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => '{"network_disabled": true}',
          );
      final source = PlatformManagedConfigSource(channel);
      expect((await source.read()).networkDisabled, isTrue);
      source.dispose();
    });

    test(
      'missing plugin, null or malformed text means nothing managed',
      () async {
        final source = PlatformManagedConfigSource(channel);
        expect((await source.read()).isEmpty, isTrue);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (_) async => '[1,2');
        expect((await source.read()).isEmpty, isTrue);
        source.dispose();
      },
    );
  });

  group('[LIC-04/AC1] ManagedVaultFolderAccess', () {
    test('blocks picking and writing a disallowed kind', () async {
      final inner = _Inner();
      final access = ManagedVaultFolderAccess(
        inner,
        pickKind: VaultTargetKind.saf,
        policy: () => ManagedConfig.parse({
          'allowed_target_kinds': ['bookmark'],
        }),
      );
      final r = await access.pick();
      expect(r, isA<Err<VaultFolder?>>());
      expect(inner.picks, 0);
      const folder = VaultFolder(kind: VaultTargetKind.saf, handle: 'h');
      expect(await access.checkAccess(folder), VaultAccess.unavailable);
      final w = await access.writerFor(folder).checkAccess();
      expect(w, VaultAccess.unavailable);
    });

    test('allows everything without a policy', () async {
      final inner = _Inner();
      final access = ManagedVaultFolderAccess(
        inner,
        pickKind: VaultTargetKind.saf,
        policy: () => ManagedConfig.none,
      );
      expect(await access.pick(), isA<Ok<VaultFolder?>>());
      expect(inner.picks, 1);
    });
  });
}
