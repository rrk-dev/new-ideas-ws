import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/features/export/data/routing_providers.dart';
import 'package:vaultvoice/features/export/domain/export_collision.dart';
import 'package:vaultvoice/features/export/domain/routing_engine.dart';
import 'package:vaultvoice/features/export/domain/routing_rule.dart';
import 'package:vaultvoice/features/export/domain/vault_target_options.dart';
import 'package:vaultvoice/features/export/presentation/routing_rule_editor_screen.dart';
import 'package:vaultvoice/features/export/presentation/vault_target_options_screen.dart';
import 'package:vaultvoice/features/licensing/data/licensing_providers.dart';
import 'package:vaultvoice/features/licensing/domain/feature_matrix.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';
import 'package:vaultvoice/features/settings/presentation/vault_settings_screens.dart';

import '../fakes/fake_clock.dart';
import '../fakes/fake_settings_store.dart';

class _MemoryRules implements RoutingRulesStore {
  _MemoryRules([List<RoutingRule> initial = const []]) : rules = [...initial];

  final List<RoutingRule> rules;
  final _changes = StreamController<void>.broadcast();

  List<RoutingRule> get _sorted =>
      [...rules]..sort((a, b) => a.priority.compareTo(b.priority));

  @override
  Stream<List<RoutingRule>> watch() async* {
    yield _sorted;
    yield* _changes.stream.map((_) => _sorted);
  }

  @override
  Future<Result<void>> save(RoutingRule rule) async {
    rules
      ..removeWhere((r) => r.id == rule.id)
      ..add(rule);
    _changes.add(null);
    return const Ok(null);
  }

  @override
  Future<Result<void>> delete(String id) async {
    rules.removeWhere((r) => r.id == id);
    _changes.add(null);
    return const Ok(null);
  }

  @override
  Future<Result<void>> reorder(List<RoutingRule> ordered) async {
    rules
      ..clear()
      ..addAll([
        for (var i = 0; i < ordered.length; i++)
          ordered[i].copyWith(priority: (i + 1) * 10),
      ]);
    _changes.add(null);
    return const Ok(null);
  }
}

const _targets = [
  VaultTargetInfo(
    id: 'v1',
    name: 'Personal',
    platform: VaultPlatform.appLocal,
    handle: '/p',
  ),
  VaultTargetInfo(
    id: 'v2',
    name: 'Work',
    platform: VaultPlatform.appLocal,
    handle: '/w',
  ),
];

void main() {
  late _MemoryRules rules;
  late FakeSettingsStore store;

  setUp(() {
    rules = _MemoryRules();
    store = FakeSettingsStore();
  });

  Future<void> pump(
    WidgetTester t,
    Widget home, {
    DistributionMode mode = DistributionMode.personal,
    List<Override> overrides = const [],
  }) async {
    t.view
      ..physicalSize = const Size(600, 2400)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          clockProvider.overrideWithValue(FakeClock(DateTime.utc(2026, 10))),
          distributionModeProvider.overrideWithValue(mode),
          routingRulesStoreProvider.overrideWithValue(rules),
          settingsStoreProvider.overrideWithValue(store),
          vaultTargetsProvider.overrideWith((ref) => Stream.value(_targets)),
          ...overrides,
        ],
        child: MaterialApp(home: home),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('a new rule is saved with its conditions, mode and folder', (
    t,
  ) async {
    await pump(t, const RoutingRuleEditorScreen(ruleId: kNewRuleId));
    await t.enterText(find.byKey(const ValueKey('rule-name')), 'Work notes');
    await t.tap(find.byKey(const ValueKey('rule-target')));
    await t.pumpAndSettle();
    await t.tap(find.text('Work').last);
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('rule-subpath')), 'Meetings');
    await t.enterText(
      find.byKey(const ValueKey('rule-tags')),
      'work, #client , ',
    );
    await t.enterText(find.byKey(const ValueKey('rule-speakers')), 'Priya');
    await t.tap(find.byKey(const ValueKey('rule-continue')));
    await t.tap(find.byKey(const ValueKey('rule-save')));
    await t.pumpAndSettle();

    final r = rules.rules.single;
    expect(r.name, 'Work notes');
    expect(r.targetId, 'v2');
    expect(r.subPath, 'Meetings');
    expect(r.match.tagsAny, ['work', '#client']);
    expect(r.match.speakersAny, ['Priya']);
    expect(r.mode, RuleMode.continueMatching);
    expect(r.priority, 10);
    expect(r.filenamePattern, isNull);
  });

  testWidgets('validation: folder required, bad pattern rejected', (t) async {
    await pump(t, const RoutingRuleEditorScreen(ruleId: kNewRuleId));
    await t.enterText(find.byKey(const ValueKey('rule-pattern')), '../x.md');
    await t.tap(find.byKey(const ValueKey('rule-save')));
    await t.pumpAndSettle();
    expect(find.text('Choose a vault folder.'), findsOneWidget);
    expect(find.text('Folders must stay inside the vault.'), findsOneWidget);
    expect(rules.rules, isEmpty);
    expect(filenamePatternError(''), isNull);
    expect(filenamePatternError('{{nope}}.md'), isNotNull);
    expect(filenamePatternError('{{slug}}.md'), isNull);
  });

  testWidgets('editing keeps id + priority; delete asks first', (t) async {
    rules.rules.add(
      const RoutingRule(
        id: 'r1',
        priority: 30,
        targetId: 'v1',
        match: RuleMatch(keywordsAny: ['acme'], classificationAny: ['x']),
      ),
    );
    await pump(t, const RoutingRuleEditorScreen(ruleId: 'r1'));
    expect(find.text('acme'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('rule-keywords')), 'acme, q4');
    await t.tap(find.byKey(const ValueKey('rule-save')));
    await t.pumpAndSettle();
    final r = rules.rules.single;
    expect((r.id, r.priority), ('r1', 30));
    expect(r.match.keywordsAny, ['acme', 'q4']);
    expect(r.match.classificationAny, ['x']);

    await pump(t, const RoutingRuleEditorScreen(ruleId: 'r1'));
    await t.tap(find.byKey(const ValueKey('rule-delete')));
    await t.pumpAndSettle();
    await t.tap(find.text('Delete rule').last);
    await t.pumpAndSettle();
    expect(rules.rules, isEmpty);
  });

  testWidgets('rules list: summary, order and Free read-only lock', (t) async {
    rules.rules.addAll(const [
      RoutingRule(id: 'b', priority: 20, targetId: 'v2', name: 'Second'),
      RoutingRule(
        id: 'a',
        priority: 10,
        targetId: 'v1',
        subPath: 'Inbox',
        mode: RuleMode.continueMatching,
        match: RuleMatch(tagsAny: ['t'], speakersAny: ['s']),
      ),
    ]);
    await pump(t, const RoutingRulesScreen());
    expect(find.text('To Personal'), findsOneWidget);
    expect(
      find.text('Notes matching 2 conditions · Inbox · then later rules'),
      findsOneWidget,
    );
    expect(find.text('Second'), findsOneWidget);
    expect(find.byKey(const ValueKey('rules-locked')), findsNothing);

    await pump(
      t,
      const RoutingRulesScreen(),
      mode: DistributionMode.commercial,
    );
    expect(find.byKey(const ValueKey('rules-locked')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('rule-add')));
    await t.pumpAndSettle();
    // No paywall product yet (LIC-02): the editor does not open.
    expect(find.byType(RoutingRuleEditorScreen), findsNothing);
  });

  testWidgets('folder options persist collision mode and sidecars', (t) async {
    await pump(t, const VaultTargetOptionsScreen(targetId: 'v2'));
    expect(find.text('Work'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('target-transcript')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('target-collision')));
    await t.pumpAndSettle();
    await t.tap(find.text('Skip').last);
    await t.pumpAndSettle();
    final saved = decodeTargetOptions(
      store.values[SettingKeys.exportTargetOptions],
    )['v2']!;
    expect(saved.transcriptSidecar, isTrue);
    expect(saved.audioSidecar, isFalse);
    expect(saved.collision, CollisionMode.skip);

    await t.enterText(find.byKey(const ValueKey('target-pattern')), '/abs.md');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(find.text('Folders must stay inside the vault.'), findsOneWidget);
  });

  testWidgets('Free plan: second folder shown as disabled', (t) async {
    await pump(
      t,
      const VaultFoldersScreen(),
      mode: DistributionMode.commercial,
    );
    expect(find.text('Not used on your current plan'), findsOneWidget);
  });

  test('policy of the entitlement', () {
    final c = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(FakeClock(DateTime.utc(2026, 10))),
        distributionModeProvider.overrideWithValue(DistributionMode.commercial),
        settingsStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(c.dispose);
    expect(c.read(routingPolicyProvider), RoutingPolicy.free);
    c.read(routingPolicyMirrorProvider);
    expect(
      RoutingPolicy.fromJson(store.values[SettingKeys.exportRoutingPolicy]),
      RoutingPolicy.free,
    );
  });
}
