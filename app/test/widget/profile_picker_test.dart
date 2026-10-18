import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/features/licensing/data/licensing_providers.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/licensing/domain/feature_matrix.dart';
import 'package:vaultvoice/features/licensing/domain/paywall.dart';
import 'package:vaultvoice/features/profiles/domain/profile_features.dart';
import 'package:vaultvoice/features/profiles/presentation/profile_picker.dart';
import 'package:vaultvoice/features/recording/domain/recording_session.dart';
import 'package:vaultvoice/features/review/presentation/schema_form.dart';

import '../fakes/fake_clock.dart';
import '../unit/profiles/profile_fixtures.dart';

const _ids = [
  'meeting',
  'warranty',
  'engineering',
  'lecture',
  'sales_call',
  'interview',
];

class _Paywall implements PaywallPresenter {
  final requests = <PaywallRequest>[];

  @override
  Future<void> show(PaywallRequest request) async => requests.add(request);
}

List<ProfileChoice> _choices() => [
  for (final id in _ids)
    ProfileChoice(
      id: id,
      name: builtinProfile(id).name,
      description: builtinProfile(id).description,
      icon: builtinProfile(id).icon,
    ),
];

void main() {
  final t0 = DateTime.utc(2026, 3);

  Future<
    ({_Paywall paywall, ProviderContainer container, List<ProfilePick?> picks})
  >
  open(
    WidgetTester tester, {
    required DistributionMode mode,
    Plan plan = Plan.free,
    String? selected,
  }) async {
    final paywall = _Paywall();
    final picks = <ProfilePick?>[];
    final container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(FakeClock(t0)),
        distributionModeProvider.overrideWithValue(mode),
        paywallPresenterProvider.overrideWithValue(paywall),
      ],
    );
    addTearDown(container.dispose);
    if (plan != Plan.free) {
      container
          .read(entitlementServiceProvider)
          .update(
            Entitlement(
              plan: plan,
              verifiedAt: t0,
              source: EntitlementSource.appStore,
            ),
          );
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            GlobalMaterialLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const ValueKey('open'),
                onPressed: () async => picks.add(
                  await showProfilePicker(
                    context,
                    choices: _choices(),
                    selectedId: selected,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
    return (paywall: paywall, container: container, picks: picks);
  }

  bool lockShown(String id) =>
      find.byKey(ValueKey('profile-lock-$id')).evaluate().isNotEmpty;

  group('[TPL-04/AC3] picker locks exactly as kFeatureMatrix says', () {
    testWidgets('lists Auto and all six built-ins with name, description, '
        'icon', (tester) async {
      await open(tester, mode: DistributionMode.personal);
      expect(find.byKey(const ValueKey('profile-option-auto')), findsOneWidget);
      for (final id in _ids) {
        final p = builtinProfile(id);
        final row = find.byKey(ValueKey('profile-option-$id'));
        expect(row, findsOneWidget, reason: id);
        expect(
          find.descendant(of: row, matching: find.text(p.name)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: row, matching: find.text(p.description)),
          findsOneWidget,
          reason: '$id description',
        );
        expect(
          find.descendant(of: row, matching: find.byIcon(profileIcon(p.icon))),
          findsOneWidget,
          reason: '$id icon',
        );
        expect(p.icon, isNotNull);
        expect(profileIcon(p.icon), isNot(Icons.tune), reason: id);
      }
    });

    testWidgets('commercial Free: locked = not free in the matrix', (
      tester,
    ) async {
      await open(tester, mode: DistributionMode.commercial);
      for (final id in _ids) {
        final feature = featureForProfile(id);
        final expected = feature != null && !kFeatureMatrix[feature]!.free;
        expect(lockShown(id), expected, reason: id);
      }
      expect(lockShown('warranty'), isTrue);
      expect(lockShown('engineering'), isTrue);
      expect(lockShown('lecture'), isFalse);
    });

    testWidgets('commercial Pro: nothing locked', (tester) async {
      await open(
        tester,
        mode: DistributionMode.commercial,
        plan: Plan.proLifetime,
      );
      for (final id in _ids) {
        final feature = featureForProfile(id);
        expect(
          lockShown(id),
          feature != null && !kFeatureMatrix[feature]!.pro,
          reason: id,
        );
      }
    });

    testWidgets('personal build: nothing locked', (tester) async {
      await open(tester, mode: DistributionMode.personal);
      for (final id in _ids) {
        expect(lockShown(id), isFalse, reason: id);
      }
    });

    testWidgets('tapping a locked profile opens the paywall and stays open', (
      tester,
    ) async {
      final r = await open(tester, mode: DistributionMode.commercial);
      await tester.tap(find.byKey(const ValueKey('profile-option-warranty')));
      await tester.pumpAndSettle();
      expect(r.paywall.requests.single.feature, Feature.builtinWarranty);
      expect(
        r.paywall.requests.single.entryPoint,
        PaywallEntryPoint.profilePicker,
      );
      expect(r.picks, isEmpty);
      expect(
        find.byKey(const ValueKey('profile-option-warranty')),
        findsOneWidget,
      );
    });

    testWidgets('tapping an unlocked profile returns it; Auto returns null', (
      tester,
    ) async {
      final r = await open(tester, mode: DistributionMode.commercial);
      await tester.tap(find.byKey(const ValueKey('profile-option-lecture')));
      await tester.pumpAndSettle();
      expect(r.paywall.requests, isEmpty);
      expect(r.picks.single?.id, 'lecture');

      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-option-auto')));
      await tester.pumpAndSettle();
      expect(r.picks.last, isNotNull);
      expect(r.picks.last!.id, isNull);
    });
  });

  group('[TPL-04/AC4] the review form renders each new profile schema', () {
    const samples = <String, Map<String, Object?>>{
      'lecture': {
        'title': 'Thermodynamics',
        'summary': 'Entropy.',
        'key_concepts': [
          {'term': 'Entropy', 'explanation': 'Disorder.'},
        ],
        'outline': [
          {
            'heading': 'Second law',
            'points': ['Entropy never decreases'],
          },
        ],
        'assignments': [
          {'task': 'Problem set 4', 'due': null, 't': '00:01:00'},
        ],
        'questions': ['Open systems?'],
        'references': ['Chapter 5'],
      },
      'sales_call': {
        'title': 'Renewal',
        'summary': 'Pricing.',
        'participants': ['Mia'],
        'needs': ['SSO'],
        'objections': [
          {'objection': 'Price', 'response': null},
        ],
        'commitments': [
          {'who': 'Mia', 'what': 'Send a quote', 't': null},
        ],
        'next_steps': [
          {'task': 'Demo', 'owner': 'Mia', 'due': null, 't': null},
        ],
        'competitors_mentioned': ['Tailspin'],
        'open_questions': <String>[],
      },
      'interview': {
        'title': 'Drift',
        'summary': 'Research.',
        'participants': [
          {'name': 'Dana', 'role': 'interviewer'},
        ],
        'topics': ['drift'],
        'qa_highlights': [
          {'question': 'Why?', 'answer': 'Heat.', 't': null},
        ],
        'quotes': [
          {'text': 'It drifts.', 'speaker': 'Ravi', 't': null},
        ],
        'follow_ups': [
          {'task': 'Email', 'owner': null, 'due': null, 't': null},
        ],
        'open_questions': <String>[],
      },
    };

    for (final e in samples.entries) {
      testWidgets('${e.key}: every top-level field gets an input', (
        tester,
      ) async {
        final schema = builtinProfile(e.key).schema;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [
              ...AppLocalizations.localizationsDelegates,
              GlobalMaterialLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: SchemaForm(
                  schema: schema,
                  value: e.value,
                  onChanged: (_) {},
                  onInputValidityChanged: (_) {},
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        for (final name in schema.properties.keys) {
          expect(
            find.byKey(ValueKey('field-0-$name'), skipOffstage: false),
            findsOneWidget,
            reason: '${e.key}.$name',
          );
        }
      });
    }
  });
}
