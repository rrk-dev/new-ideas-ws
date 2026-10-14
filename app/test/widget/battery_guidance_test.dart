import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/recording/data/method_channel_recording_indicator.dart';
import 'package:vaultvoice/features/recording/data/recording_providers.dart';
import 'package:vaultvoice/features/recording/presentation/battery_guidance.dart';

void main() {
  Future<void> pump(WidgetTester t, BatteryStatus? status) => t.pumpWidget(
    ProviderScope(
      overrides: [batteryStatusProvider.overrideWith((ref) async => status)],
      child: const MaterialApp(
        home: BatteryGuidance(child: Scaffold(body: Text('content'))),
      ),
    ),
  );

  testWidgets('Samsung without exemption: guidance + settings link', (t) async {
    await pump(
      t,
      const BatteryStatus(
        manufacturer: 'samsung',
        ignoringOptimizations: false,
      ),
    );
    await t.pumpAndSettle();
    expect(find.textContaining('Never sleeping apps'), findsOneWidget);
    expect(find.text('Open battery settings'), findsOneWidget);
    expect(find.text('content'), findsOneWidget);
    await t.tap(find.text('Open battery settings'));
    await t.pump();
  });

  testWidgets('exempt or stock Android: content only', (t) async {
    await pump(
      t,
      const BatteryStatus(manufacturer: 'samsung', ignoringOptimizations: true),
    );
    await t.pumpAndSettle();
    expect(find.text('Open battery settings'), findsNothing);
    await pump(t, null);
    await t.pumpAndSettle();
    expect(find.text('Open battery settings'), findsNothing);
    expect(find.text('content'), findsOneWidget);
  });
}
