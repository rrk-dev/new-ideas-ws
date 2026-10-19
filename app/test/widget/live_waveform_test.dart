import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/theme/app_theme.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/features/onboarding/domain/onboarding_keys.dart';
import 'package:vaultvoice/features/recording/data/recording_providers.dart';
import 'package:vaultvoice/features/recording/data/recording_screen_providers.dart';
import 'package:vaultvoice/features/recording/domain/level_meter.dart';
import 'package:vaultvoice/features/recording/presentation/live_waveform.dart';
import 'package:vaultvoice/features/recording/presentation/recording_screen.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

import '../fakes/fake_call_guard.dart';
import '../fakes/fake_capture_backend.dart';
import '../fakes/fake_recording_indicator.dart';
import '../fakes/fake_settings_store.dart';

AudioLevel _lv(double db, {bool clipping = false}) =>
    AudioLevel(rmsDbfs: db, peakDbfs: db, clipping: clipping);

CustomPaint _paint(WidgetTester t) =>
    t.widget<CustomPaint>(find.byKey(const ValueKey('waveform-paint')));

PaintPattern _drawsBar(Color color) => paints
  ..something(
    (method, args) =>
        method == #drawRRect &&
        (args[1] as Paint).color.toARGB32() == color.toARGB32(),
  );

class _BuildCounter extends StatelessWidget {
  const _BuildCounter(this.onBuild, {required this.child});

  final VoidCallback onBuild;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    onBuild();
    return child;
  }
}

void main() {
  Future<void> pumpHost(
    WidgetTester t,
    Stream<AudioLevel> levels, {
    bool active = true,
    bool disableAnimations = false,
    Brightness brightness = Brightness.light,
  }) => t.pumpWidget(
    ProviderScope(
      overrides: [recordingLevelsProvider.overrideWith((ref) => levels)],
      child: MaterialApp(
        theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Scaffold(
            body: Center(child: LiveWaveform(active: active)),
          ),
        ),
      ),
    ),
  );

  test('[APP-09/AC1] ring buffer keeps the last N readings, newest at the '
      'right edge', () {
    final b = WaveformBuffer(4);
    expect(b.readings, everyElement(AudioLevel.silent));
    for (var i = 1; i <= 6; i++) {
      b.add(_lv(-60.0 + i));
    }
    expect(b.length, 4);
    expect(b.readings.map((l) => l.rmsDbfs), [-57.0, -56.0, -55.0, -54.0]);
    expect(b.latest.rmsDbfs, -54);

    final partial = WaveformBuffer(3)..add(_lv(-10));
    expect(partial.readings.last.rmsDbfs, -10);
    expect(partial.readings.first, AudioLevel.silent);

    final painter = WaveformPainter(
      buffer: b,
      color: Colors.teal,
      clippingColor: Colors.red,
      reduceMotion: false,
    );
    expect(painter.visibleLevels(2).map((l) => l.rmsDbfs), [-55.0, -54.0]);
    expect(WaveformPainter.barCount(0), 0);
  });

  testWidgets('[APP-09/AC2] clipping readings are drawn in the error colour', (
    t,
  ) async {
    final levels = StreamController<AudioLevel>();
    addTearDown(levels.close);
    await pumpHost(t, levels.stream);
    final scheme = Theme.of(t.element(find.byType(LiveWaveform))).colorScheme;
    final render = t.renderObject(find.byKey(const ValueKey('waveform-paint')));

    levels.add(_lv(-20));
    await t.pump(const Duration(milliseconds: 50));
    expect(render, _drawsBar(scheme.primary));

    levels.add(_lv(-3, clipping: true));
    await t.pump(const Duration(milliseconds: 50));
    expect(render, _drawsBar(scheme.error));
    expect(find.byKey(const ValueKey('clipping-hint')), findsOneWidget);
  });

  testWidgets('3 s of digital silence shows the no-input hint until a signal '
      'returns', (t) async {
    final levels = StreamController<AudioLevel>();
    addTearDown(levels.close);
    await pumpHost(t, levels.stream);
    const hint = ValueKey('no-input-hint');
    for (var i = 0; i < 59; i++) {
      levels.add(_lv(-90));
      await t.pump(const Duration(milliseconds: 1));
    }
    expect(find.byKey(hint), findsNothing);
    levels.add(_lv(-90));
    await t.pump(const Duration(milliseconds: 1));
    expect(find.byKey(hint), findsOneWidget);
    levels.add(_lv(-40));
    await t.pump(const Duration(milliseconds: 1));
    expect(find.byKey(hint), findsNothing);
  });

  testWidgets('[APP-09/AC3] with reduced motion the bars do not scroll', (
    t,
  ) async {
    final levels = StreamController<AudioLevel>();
    addTearDown(levels.close);
    await pumpHost(t, levels.stream, disableAnimations: true);
    for (final db in [-50.0, -40.0, -25.0]) {
      levels.add(_lv(db));
      await t.pump(const Duration(milliseconds: 50));
    }
    final painter = _paint(t).painter! as WaveformPainter;
    expect(painter.reduceMotion, isTrue);
    expect(painter.visibleLevels(10).map((l) => l.rmsDbfs).toSet(), {-25.0});
    expect(t.hasRunningAnimations, isFalse);
  });

  testWidgets(
    'idle ignores readings (flat low bars) and has one semantic label',
    (t) async {
      final levels = StreamController<AudioLevel>();
      addTearDown(levels.close);
      await pumpHost(t, levels.stream, active: false);
      levels.add(_lv(-10));
      await t.pump(const Duration(milliseconds: 50));
      final painter = _paint(t).painter! as WaveformPainter;
      expect(painter.buffer.length, 0);
      expect(find.bySemanticsLabel('Input level'), findsOneWidget);
      expect(find.byType(RepaintBoundary), findsWidgets);
    },
  );

  testWidgets('[APP-09/AC5] has a RepaintBoundary and a full buffer repaints '
      'without rebuilding the surrounding screen', (t) async {
    final levels = StreamController<AudioLevel>();
    addTearDown(levels.close);
    var outerBuilds = 0;
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          recordingLevelsProvider.overrideWith((ref) => levels.stream),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: _BuildCounter(
              () => outerBuilds++,
              child: const LiveWaveform(active: true),
            ),
          ),
        ),
      ),
    );
    expect(
      find.descendant(
        of: find.byType(LiveWaveform),
        matching: find.byType(RepaintBoundary),
      ),
      findsWidgets,
    );
    final before = outerBuilds;
    for (var i = 0; i < AppSizes.waveformCapacity + 10; i++) {
      levels.add(_lv(-50.0 + (i % 30)));
      await t.pump(const Duration(milliseconds: 50));
    }
    final painter = _paint(t).painter! as WaveformPainter;
    expect(painter.buffer.length, painter.buffer.capacity);
    expect(outerBuilds, before);
  });

  for (final brightness in Brightness.values) {
    testWidgets('[APP-09/AC4] Record screen with the waveform renders at text '
        'scale 2.0 without overflow (${brightness.name})', (t) async {
      final levels = StreamController<AudioLevel>();
      addTearDown(levels.close);
      t.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            captureBackendProvider.overrideWithValue(FakeCaptureBackend()),
            callGuardProvider.overrideWithValue(FakeCallGuard()),
            recordingIndicatorProvider.overrideWithValue(
              FakeRecordingIndicator(),
            ),
            profileChoicesProvider.overrideWith(
              (ref) => Stream.value(const []),
            ),
            destinationChoicesProvider.overrideWith((ref) async => const []),
            recoveredRecordingsProvider.overrideWith((ref) async => const []),
            batteryStatusProvider.overrideWith((ref) async => null),
            recordingLevelsProvider.overrideWith((ref) => levels.stream),
            settingsStoreProvider.overrideWithValue(
              FakeSettingsStore({OnboardingKeys.micPrimed: true}),
            ),
          ],
          child: MaterialApp(
            theme: brightness == Brightness.light
                ? AppTheme.light
                : AppTheme.dark,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const RecordScreen(),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('live-waveform')), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
