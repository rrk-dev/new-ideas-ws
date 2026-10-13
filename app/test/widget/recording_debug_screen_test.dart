import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/flavor.dart';
import 'package:vaultvoice/core/flavor_provider.dart';
import 'package:vaultvoice/features/recording/data/recording_providers.dart';
import 'package:vaultvoice/features/recording/domain/audio_format.dart';
import 'package:vaultvoice/features/recording/presentation/recording_debug_screen.dart';
import 'package:vaultvoice/features/recording/presentation/recording_screen.dart';

import '../fakes/fake_call_guard.dart';
import '../fakes/fake_capture_backend.dart';

final selected = <AudioInputDevice?>[];

void main() {
  Future<(FakeCaptureBackend, FakeCallGuard)> pump(
    WidgetTester t, {
    Flavor flavor = Flavor.dev,
  }) async {
    final capture = FakeCaptureBackend();
    final guard = FakeCallGuard();
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          captureBackendProvider.overrideWithValue(capture),
          callGuardProvider.overrideWithValue(guard),
          flavorProvider.overrideWithValue(flavor),
          recordingInputDevicesProvider.overrideWith(
            (ref) async => const [
              AudioInputDevice(
                id: 'bt',
                label: 'Headset',
                kind: AudioInputKind.bluetooth,
              ),
            ],
          ),
          recordingInputSelectorProvider.overrideWithValue(selected.add),
        ],
        child: const MaterialApp(home: RecordScreen()),
      ),
    );
    return (capture, guard);
  }

  testWidgets('dev debug screen drives start/pause/resume/stop by taps', (
    t,
  ) async {
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final (capture, _) = await pump(t);
    await t.tap(find.byTooltip('Recording debug'));
    await t.pumpAndSettle();
    expect(find.byType(RecordingDebugScreen), findsOneWidget);
    expect(capture.calls, isEmpty, reason: 'opening the screen never records');

    await t.tap(find.text('Start'));
    await t.pump();
    expect(find.textContaining('RECORDING'), findsOneWidget);
    expect(capture.micOpen, isTrue);

    await t.tap(find.text('Pause'));
    await t.pump();
    expect(find.textContaining('PAUSED'), findsOneWidget);
    await t.tap(find.text('Resume'));
    await t.pump();
    await t.tap(find.text('Stop'));
    await t.pump();
    expect(find.textContaining('STOPPED'), findsOneWidget);
    expect(find.textContaining('stopped:'), findsOneWidget);
    expect(capture.micOpen, isFalse);

    await t.tap(find.text('List inputs'));
    await t.pumpAndSettle();
    await t.tap(find.text('Default input').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Headset (bluetooth)').last);
    await t.pumpAndSettle();
    expect(selected.single?.id, 'bt');
    // Leave the screen so its ticker is disposed.
    await t.pageBack();
    await t.pumpAndSettle();
  });

  testWidgets('the recording debug entry is hidden in prod', (t) async {
    await pump(t, flavor: Flavor.prod);
    expect(find.byTooltip('Recording debug'), findsNothing);
  });
}
