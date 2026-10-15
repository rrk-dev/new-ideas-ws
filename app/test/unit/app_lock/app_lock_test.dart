import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/app_lock/data/platform_app_lock.dart';
import 'package:vaultvoice/features/app_lock/domain/app_lock.dart';
import 'package:vaultvoice/features/app_lock/presentation/app_lock_providers.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

void main() {
  test('[SEC-03/AC1] a failed settings read keeps the app locked', () async {
    final c = ProviderContainer(
      overrides: [
        settingStateProvider.overrideWith(
          (ref, key) => throw StateError('settings unreadable'),
        ),
      ],
    );
    addTearDown(c.dispose);
    c.listen(appLockProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    expect(c.read(appLockProvider).locked, isTrue);
  });

  final t0 = DateTime.utc(2026, 10, 14, 9);

  group('[SEC-03/AC1] lock timeout', () {
    test('maps every Settings option; unknown ids lock immediately', () {
      expect(lockTimeoutFor('immediately'), Duration.zero);
      expect(lockTimeoutFor('minutes_1'), const Duration(minutes: 1));
      expect(lockTimeoutFor('minutes_5'), const Duration(minutes: 5));
      expect(lockTimeoutFor('minutes_15'), const Duration(minutes: 15));
      expect(lockTimeoutFor('bogus'), Duration.zero);
    });

    test('locked on launch, unlocked only by success', () {
      final m = AppLockMachine(enabled: true, timeout: Duration.zero);
      expect(m.locked, isTrue);
      m.authenticated(AuthOutcome.failed);
      expect(m.locked, isTrue);
      m.authenticated(AuthOutcome.success);
      expect(m.locked, isFalse);
    });

    test('re-locks only after the timeout in the background', () {
      final m =
          AppLockMachine(enabled: true, timeout: const Duration(minutes: 5))
            ..authenticated(AuthOutcome.success)
            ..backgrounded(t0)
            ..resumed(t0.add(const Duration(minutes: 4, seconds: 59)));
      expect(m.locked, isFalse, reason: 'within the timeout');
      m
        ..backgrounded(t0)
        // A second background event (hidden → paused) keeps the first time.
        ..backgrounded(t0.add(const Duration(minutes: 1)))
        ..resumed(t0.add(const Duration(minutes: 5)));
      expect(m.locked, isTrue, reason: 'timeout reached');
    });

    test('"immediately" locks on every return from the background', () {
      final m = AppLockMachine(enabled: true, timeout: Duration.zero)
        ..authenticated(AuthOutcome.success)
        ..resumed(t0);
      expect(m.locked, isFalse, reason: 'resume without background');
      m
        ..backgrounded(t0)
        ..resumed(t0);
      expect(m.locked, isTrue);
    });

    test('disabled lock never locks; turning it off unlocks', () {
      final m = AppLockMachine(enabled: false, timeout: Duration.zero)
        ..backgrounded(t0)
        ..resumed(t0.add(const Duration(hours: 1)));
      expect(m.locked, isFalse);
      final on = AppLockMachine(enabled: true, timeout: Duration.zero)
        ..enabled = false;
      expect(on.locked, isFalse);
      on.enabled = true;
      expect(on.locked, isFalse, reason: 'enabling does not lock the session');
    });

    test('no device credentials: the lock cannot be enforced', () {
      final m = AppLockMachine(enabled: true, timeout: Duration.zero)
        ..authenticated(AuthOutcome.unavailable);
      expect(m.locked, isFalse);
    });
  });

  group('platform channels', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    tearDown(() {
      messenger
        ..setMockMethodCallHandler(
          const MethodChannel(MethodChannelDeviceAuthenticator.channelName),
          null,
        )
        ..setMockMethodCallHandler(
          const MethodChannel(MethodChannelPrivacyScreen.channelName),
          null,
        );
    });

    test('device auth maps replies and errors', () async {
      Object? reply;
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(
        const MethodChannel(MethodChannelDeviceAuthenticator.channelName),
        (call) async {
          calls.add(call);
          if (reply case final Exception e) throw e;
          return reply;
        },
      );
      const auth = MethodChannelDeviceAuthenticator();
      for (final (r, expected) in [
        ('success', AuthOutcome.success),
        ('failed', AuthOutcome.failed),
        ('unavailable', AuthOutcome.unavailable),
        (null, AuthOutcome.failed),
      ]) {
        reply = r;
        expect(await auth.authenticate('Unlock'), expected);
      }
      reply = PlatformException(code: 'in_progress');
      expect(await auth.authenticate('Unlock'), AuthOutcome.failed);
      expect(calls.first.arguments, {'reason': 'Unlock'});
    });

    test('without a platform implementation auth is unavailable', () async {
      expect(
        await const MethodChannelDeviceAuthenticator().authenticate('x'),
        AuthOutcome.unavailable,
      );
      await const MethodChannelPrivacyScreen().setEnabled(enabled: true);
    });

    test('privacy screen forwards the flag and swallows errors', () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(
        const MethodChannel(MethodChannelPrivacyScreen.channelName),
        (call) async {
          calls.add(call);
          if (calls.length > 1) throw PlatformException(code: 'x');
          return null;
        },
      );
      await const MethodChannelPrivacyScreen().setEnabled(enabled: true);
      await const MethodChannelPrivacyScreen().setEnabled(enabled: false);
      expect(calls.map((c) => c.arguments), [
        {'enabled': true},
        {'enabled': false},
      ]);
    });
  });

  group('[SEC-03/AC1] native app-switcher protection', () {
    test('Android sets FLAG_SECURE and uses the platform BiometricPrompt '
        'with device-credential fallback', () {
      final kt = File(
        'android/app/src/main/kotlin/com/vaultvoice/vaultvoice/security/'
        'AppLockPlugin.kt',
      ).readAsStringSync();
      expect(kt, contains('addFlags(WindowManager.LayoutParams.FLAG_SECURE)'));
      expect(kt, contains('DEVICE_CREDENTIAL'));
      expect(kt, contains('setDeviceCredentialAllowed(true)'));
      expect(kt, contains('createConfirmDeviceCredentialIntent'));
      expect(
        File(
          'android/app/src/main/kotlin/com/vaultvoice/vaultvoice/'
          'MainActivity.kt',
        ).readAsStringSync(),
        contains('AppLockPlugin()'),
      );
      expect(
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
        contains('android.permission.USE_BIOMETRIC'),
      );
    });

    test('iOS covers windows when the scene resigns active and uses '
        'deviceOwnerAuthentication (passcode fallback)', () {
      final swift = File('ios/Runner/AppLockPlugin.swift').readAsStringSync();
      expect(swift, contains('UIScene.willDeactivateNotification'));
      expect(swift, contains('UIScene.didActivateNotification'));
      expect(swift, contains('.deviceOwnerAuthentication'));
      expect(
        File('ios/Runner/AppDelegate.swift').readAsStringSync(),
        contains('AppLockPlugin.register'),
      );
      expect(
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync(),
        contains('AppLockPlugin.swift in Sources'),
      );
      expect(
        File('ios/Runner/Info.plist').readAsStringSync(),
        contains('NSFaceIDUsageDescription'),
      );
    });
  });
}
