import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/features/app_lock/domain/app_lock.dart';
import 'package:vaultvoice/features/app_lock/presentation/app_lock_gate.dart';
import 'package:vaultvoice/features/app_lock/presentation/app_lock_providers.dart';
import 'package:vaultvoice/features/recording/data/recording_providers.dart';
import 'package:vaultvoice/features/recording/domain/recording_controller.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';
import 'package:vaultvoice/features/settings/domain/settings_ports.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

import '../fakes/fake_call_guard.dart';
import '../fakes/fake_capture_backend.dart';
import '../fakes/fake_clock.dart';
import '../fakes/fake_settings_store.dart';

class _Auth implements DeviceAuthenticator {
  final outcomes = <AuthOutcome>[];
  final reasons = <String>[];

  @override
  Future<AuthOutcome> authenticate(String reason) async {
    reasons.add(reason);
    return outcomes.isEmpty ? AuthOutcome.failed : outcomes.removeAt(0);
  }
}

class _Privacy implements PrivacyScreen {
  final calls = <bool>[];

  @override
  Future<void> setEnabled({required bool enabled}) async => calls.add(enabled);
}

class _Managed implements ManagedSettingsSource {
  _Managed(this.values);

  final Map<String, Object?> values;

  @override
  Stream<ManagedSettings> watch() =>
      Stream.value(ManagedSettings(values: values));
}

const _secret = 'Board meeting transcript';

void main() {
  late _Auth auth;
  late _Privacy privacy;
  late FakeClock clock;
  late FakeCaptureBackend capture;
  late RecordingController recorder;

  setUp(() {
    auth = _Auth();
    privacy = _Privacy();
    clock = FakeClock(DateTime.utc(2026, 10, 14, 9));
    capture = FakeCaptureBackend();
    recorder = RecordingController(
      capture: capture,
      callGuard: FakeCallGuard(),
      clock: clock,
      isAppInForeground: () => true,
    );
  });

  Future<void> pump(
    WidgetTester t, {
    Map<String, Object?> settings = const {},
    List<Override> extra = const [],
  }) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          settingsStoreProvider.overrideWithValue(FakeSettingsStore(settings)),
          deviceAuthenticatorProvider.overrideWithValue(auth),
          privacyScreenProvider.overrideWithValue(privacy),
          clockProvider.overrideWithValue(clock),
          recordingControllerProvider.overrideWithValue(recorder),
          ...extra,
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => AppLockGate(child: child!),
          home: const Scaffold(body: Center(child: Text(_secret))),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> lifecycle(WidgetTester t, List<AppLifecycleState> states) async {
    states.forEach(t.binding.handleAppLifecycleStateChanged);
    await t.pumpAndSettle();
  }

  const background = [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ];
  const foreground = [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ];

  testWidgets('lock off: content visible, privacy screen off', (t) async {
    await pump(t);
    expect(find.text(_secret), findsOneWidget);
    expect(find.byType(LockScreen), findsNothing);
    expect(privacy.calls.last, isFalse);
  });

  testWidgets('[SEC-03/AC1] lock on: content hidden at launch and the '
      'app-switcher privacy screen is enabled', (t) async {
    await pump(t, settings: {SettingKeys.securityAppLock: true});
    expect(find.byType(LockScreen), findsOneWidget);
    expect(find.text(_secret), findsNothing);
    expect(privacy.calls.last, isTrue);
    // Excluded from semantics too (screen readers / accessibility snapshot).
    expect(find.bySemanticsLabel(_secret), findsNothing);

    await t.tap(find.byKey(const ValueKey('app-lock-unlock')));
    await t.pumpAndSettle();
    expect(find.text(_secret), findsNothing, reason: 'failed attempt');

    auth.outcomes.add(AuthOutcome.success);
    await t.tap(find.byKey(const ValueKey('app-lock-unlock')));
    await t.pumpAndSettle();
    expect(find.text(_secret), findsOneWidget);
    expect(auth.reasons, hasLength(2));
  });

  testWidgets('[SEC-03/AC1] lock timeout respected after backgrounding', (
    t,
  ) async {
    await pump(
      t,
      settings: {
        SettingKeys.securityAppLock: true,
        SettingKeys.securityLockTimeout: 'minutes_5',
      },
    );
    auth.outcomes.add(AuthOutcome.success);
    await t.tap(find.byKey(const ValueKey('app-lock-unlock')));
    await t.pumpAndSettle();
    expect(find.text(_secret), findsOneWidget);

    await lifecycle(t, background);
    clock.advance(const Duration(minutes: 4));
    await lifecycle(t, foreground);
    expect(find.text(_secret), findsOneWidget, reason: '4 min < 5 min');

    await lifecycle(t, background);
    clock.advance(const Duration(minutes: 5));
    await lifecycle(t, foreground);
    expect(find.byType(LockScreen), findsOneWidget);
    expect(find.text(_secret), findsNothing);
  });

  testWidgets('MDM-forced lock (managed security.app_lock) applies', (t) async {
    await pump(
      t,
      extra: [
        managedSettingsSourceProvider.overrideWithValue(
          _Managed({SettingKeys.securityAppLock: true}),
        ),
      ],
    );
    expect(find.byType(LockScreen), findsOneWidget);
  });

  testWidgets('a device without credentials cannot be locked', (t) async {
    await pump(t, settings: {SettingKeys.securityAppLock: true});
    auth.outcomes.add(AuthOutcome.unavailable);
    await t.tap(find.byKey(const ValueKey('app-lock-unlock')));
    await t.pumpAndSettle();
    expect(find.text(_secret), findsOneWidget);
  });

  testWidgets('[SEC-03] a recording can be started by a tap while locked; '
      'content stays hidden', (t) async {
    await pump(t, settings: {SettingKeys.securityAppLock: true});
    await t.tap(find.byKey(const ValueKey('app-lock-record')));
    await t.pumpAndSettle();
    expect(recorder.state.phase, RecordingPhase.recording);
    expect(capture.calls.whereType<OpenCall>(), hasLength(1));
    expect(find.byKey(const ValueKey('app-lock-recording')), findsOneWidget);
    expect(find.text(_secret), findsNothing);

    await t.tap(find.byKey(const ValueKey('app-lock-stop')));
    await t.pumpAndSettle();
    expect(recorder.state.phase, RecordingPhase.stopped);
    expect(find.byKey(const ValueKey('app-lock-record')), findsOneWidget);
    expect(find.text(_secret), findsNothing);
    await recorder.dispose();
  });
}
