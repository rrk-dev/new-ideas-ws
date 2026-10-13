import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/flavor.dart';
import 'package:vaultvoice/core/flavor_provider.dart';
import 'package:vaultvoice/core/platform/call_guard.dart';
import 'package:vaultvoice/features/recording/data/recording_providers.dart';
import 'package:vaultvoice/features/recording/presentation/call_guard_debug_screen.dart';
import 'package:vaultvoice/features/recording/presentation/recording_screen.dart';

import '../fakes/fake_call_guard.dart';

void main() {
  Future<FakeCallGuard> pump(
    WidgetTester t, {
    Flavor flavor = Flavor.dev,
  }) async {
    final guard = FakeCallGuard();
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          callGuardProvider.overrideWithValue(guard),
          flavorProvider.overrideWithValue(flavor),
        ],
        child: const MaterialApp(home: RecordScreen()),
      ),
    );
    return guard;
  }

  testWidgets('[SEC-09/AC2] debug screen shows the live call state and that '
      'start is refused during a call', (t) async {
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final guard = await pump(t);
    await t.tap(find.byTooltip('CallGuard debug'));
    await t.pumpAndSettle();
    expect(find.byType(CallGuardDebugScreen), findsOneWidget);
    expect(find.text('Call state: no call'), findsOneWidget);

    guard.emit(CallGuardSignal.callActive, DateTime.now().toUtc());
    await t.pump();
    expect(find.text('Call state: IN CALL'), findsOneWidget);
    expect(find.textContaining('callActive'), findsOneWidget);

    await t.tap(find.text('Try start'));
    await t.pumpAndSettle();
    expect(
      find.text(
        'Last start attempt: refused: Recording is unavailable during calls',
      ),
      findsOneWidget,
    );

    guard.emit(CallGuardSignal.callEnded, DateTime.now().toUtc());
    await t.pump();
    expect(find.text('Call state: no call'), findsOneWidget);
  });

  testWidgets('the debug entry is hidden in the prod flavor', (t) async {
    await pump(t, flavor: Flavor.prod);
    expect(find.byTooltip('CallGuard debug'), findsNothing);
  });
}
