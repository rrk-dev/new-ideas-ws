import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/flavor.dart';
import 'package:vaultvoice/core/flavor_provider.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/features/extraction/presentation/llm_debug_screen.dart';

import '../fakes/fake_llm_engine.dart';

void main() {
  List<Override> overrides(
    FakeLlmEngine engine, {
    Flavor flavor = Flavor.dev,
  }) => [
    llmEngineProvider.overrideWithValue(engine),
    flavorProvider.overrideWithValue(flavor),
  ];
  const screen = MaterialApp(home: LlmDebugScreen());

  String output(WidgetTester t) =>
      t.widget<SelectableText>(find.byKey(const Key('llm-debug-output'))).data!;
  String status(WidgetTester t) =>
      t.widget<Text>(find.byKey(const Key('llm-debug-status'))).data!;

  testWidgets('[LLM-04/AC1] streaming output appears in the debug screen', (
    t,
  ) async {
    final engine = FakeLlmEngine(
      tokens: const ['Red', ', green', ', blue'],
      perToken: const Duration(milliseconds: 100),
    );
    await t.pumpWidget(
      ProviderScope(overrides: overrides(engine), child: screen),
    );
    await t.tap(find.byKey(const Key('llm-debug-generate')));
    await t.pump(const Duration(milliseconds: 150));
    expect(output(t), 'Red'); // partial: streamed, not all at once
    expect(status(t), 'generating');
    await t.pump(const Duration(milliseconds: 250));
    await t.pumpAndSettle();
    expect(output(t), 'Red, green, blue');
    expect(status(t), startsWith('done'));
  });

  testWidgets('[LLM-04/AC1] cancel stops the stream', (t) async {
    final engine = FakeLlmEngine(
      tokens: List.filled(50, 'x'),
      perToken: const Duration(milliseconds: 50),
    );
    await t.pumpWidget(
      ProviderScope(overrides: overrides(engine), child: screen),
    );
    await t.tap(find.byKey(const Key('llm-debug-generate')));
    await t.pump(const Duration(milliseconds: 120));
    await t.tap(find.byKey(const Key('llm-debug-cancel')));
    await t.pump(const Duration(milliseconds: 200));
    await t.pumpAndSettle();
    expect(status(t), 'cancelled');
    expect(output(t).length, lessThan(10));
  });

  testWidgets('debug tile is hidden in prod', (t) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [flavorProvider.overrideWithValue(Flavor.prod)],
        child: const MaterialApp(home: Scaffold(body: LlmDebugTile())),
      ),
    );
    expect(find.text('LLM debug (dev)'), findsNothing);
  });
}
