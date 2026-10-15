import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/recording/data/recording_providers.dart';
import 'package:vaultvoice/features/recording/domain/level_meter.dart';
import 'package:vaultvoice/features/recording/presentation/level_meter_bar.dart';

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
  testWidgets('[AUD-02/AC3] meter repaints every 50 ms reading (20 Hz) '
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
              child: const LevelMeterBar(),
            ),
          ),
        ),
      ),
    );
    double value() => t
        .widget<LinearProgressIndicator>(
          find.byKey(const ValueKey('level-meter')),
        )
        .value!;
    expect(value(), 0);
    final buildsBefore = outerBuilds;
    var updates = 0;
    var last = value();
    // One second of readings at the meter's 20 Hz cadence.
    for (var i = 0; i < 20; i++) {
      levels.add(AudioLevel(rmsDbfs: -50.0 + i * 2, peakDbfs: -40.0 + i));
      await t.pump(const Duration(milliseconds: 50));
      final v = value();
      if (v != last) updates++;
      last = v;
    }
    expect(updates, greaterThanOrEqualTo(15));
    expect(outerBuilds, buildsBefore, reason: 'only the meter rebuilds');
    expect(find.byKey(const ValueKey('clipping-hint')), findsNothing);
  });

  testWidgets('[AUD-02/AC1] clipping shows the "move the phone further away" '
      'hint', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LevelMeterView(
            level: AudioLevel(rmsDbfs: -3, peakDbfs: 0, clipping: true),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('clipping-hint')), findsOneWidget);
    expect(find.textContaining('further away'), findsOneWidget);
  });
}
