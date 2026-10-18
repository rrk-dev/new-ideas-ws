import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/app.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/flavor.dart';
import 'package:vaultvoice/core/flavor_provider.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/network/network_activity.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/core/routing/app_router.dart';
import 'package:vaultvoice/core/theme/app_theme.dart';
import 'package:vaultvoice/features/app_lock/domain/app_lock.dart';
import 'package:vaultvoice/features/app_lock/presentation/app_lock_gate.dart';
import 'package:vaultvoice/features/app_lock/presentation/app_lock_providers.dart';
import 'package:vaultvoice/features/ask/data/ask_providers.dart';
import 'package:vaultvoice/features/ask/domain/ask_availability.dart';
import 'package:vaultvoice/features/ask/domain/ask_history.dart';
import 'package:vaultvoice/features/export/data/routing_providers.dart';
import 'package:vaultvoice/features/export/domain/pending_export.dart';
import 'package:vaultvoice/features/export/domain/routing_rule.dart';
import 'package:vaultvoice/features/library/domain/recording_detail.dart';
import 'package:vaultvoice/features/licensing/data/purchase_providers.dart';
import 'package:vaultvoice/features/licensing/domain/feature_access.dart';
import 'package:vaultvoice/features/licensing/domain/store_purchase.dart';
import 'package:vaultvoice/features/models/data/model_import_providers.dart';
import 'package:vaultvoice/features/models/data/model_management_providers.dart';
import 'package:vaultvoice/features/models/data/model_state_providers.dart';
import 'package:vaultvoice/features/models/domain/installed_model.dart';
import 'package:vaultvoice/features/models/domain/model_management.dart';
import 'package:vaultvoice/features/onboarding/domain/onboarding_keys.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_providers.dart';
import 'package:vaultvoice/features/profiles/data/custom_profile_providers.dart';
import 'package:vaultvoice/features/profiles/data/profile_providers.dart';
import 'package:vaultvoice/features/profiles/domain/profile_codec.dart';
import 'package:vaultvoice/features/review/data/review_providers.dart';
import 'package:vaultvoice/features/settings/domain/settings_ports.dart';
import 'package:vaultvoice/features/settings/presentation/network_activity_screen.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';
import 'package:vaultvoice/features/templates/data/template_editor_providers.dart';
import 'package:vaultvoice/features/templates/data/template_store.dart';
import 'package:vaultvoice/features/transcription/domain/playback_timeline.dart';
import 'package:vaultvoice/features/transcription/domain/transcript_player.dart';
import 'package:vaultvoice/features/transcription/domain/transcript_view.dart';
import 'package:vaultvoice/features/transcription/presentation/transcript_providers.dart';

import '../fakes/fake_ask_engine.dart';
import '../fakes/fake_settings_store.dart';
import '../fakes/fake_transcript_player.dart';
import '../helpers/library_fixtures.dart';
import '../helpers/model_fixtures.dart';
import '../helpers/processing_fixtures.dart';
import '../unit/templates/template_fixtures.dart' as fixtures;

class _Managed implements ManagedSettingsSource {
  const _Managed();

  @override
  Stream<ManagedSettings> watch() =>
      Stream.value(const ManagedSettings(values: {'security.app_lock': true}));
}

/// The routes below are audited unlocked (the managed settings above force
/// the app lock on, so the lock is opened here); the lock screen (SEC-03)
/// has its own rows at the end.
class _Unlocked extends AppLock {
  @override
  AppLockView build() => const AppLockView(enabled: false, locked: false);
}

class _NoAuth implements DeviceAuthenticator {
  @override
  Future<AuthOutcome> authenticate(String reason) async => AuthOutcome.failed;
}

/// Every screen reachable in the app today, by route location.
const _screens = {
  'Record': '/record',
  'Library': '/library',
  'Processing queue': '/library/processing',
  'Recording detail': '/library/recordings/rec-a',
  'Recording transcript': '/library/recordings/rec-a/text',
  'Action items': '/library/action-items',
  'Ask': '/library/ask',
  'Ask history': '/library/ask/history',
  'Review before export': '/library/recordings/rec-a/review',
  'Review settings': '/settings/review',
  'Profiles': '/profiles',
  'Profile editor (new)': '/profiles/new',
  'Profile editor (built-in, read-only)': '/profiles/meeting',
  'Settings': '/settings',
  'Pro paywall': '/settings/pro',
  'Vault folders': '/settings/vault-folders',
  'Routing rules': '/settings/routing-rules',
  'Routing rule editor': '/settings/routing-rules/r1',
  'New routing rule': '/settings/routing-rules/new',
  'Vault folder options': '/settings/vault-folders/v1',
  'Pending exports': '/settings/pending-exports',
  'Models': '/settings/models',
  'Transcript': '/library/recordings/rec-a/transcript',
  'Templates': '/settings/templates',
  'Template (built-in)': '/settings/templates/meeting-default',
  'Template editor': '/settings/templates/mine',
  'Onboarding': '/onboarding',
  'Beta feedback': '/settings/feedback',
};

class _Templates implements TemplateStore {
  @override
  Stream<List<CustomTemplate>> watch() => Stream.value(const [
    CustomTemplate(
      id: 'mine',
      body: '# {{data.title}}\n\n{{#data.action_items}}\n',
      filenamePattern: '{{slug}}.md',
      profileId: 'meeting',
      baseId: 'meeting-default',
    ),
  ]);

  @override
  Stream<Map<String, String>> watchBindings() => Stream.value(const {});

  @override
  Future<Result<void>> save(CustomTemplate template) async => const Ok(null);

  @override
  Future<Result<void>> delete(String id) async => const Ok(null);

  @override
  Future<Result<void>> bind(String profileId, String? templateId) async =>
      const Ok(null);
}

/// STT-06 transcript with a speaker, a low-confidence word and a marker.
const _transcript = TranscriptViewData(
  transcriptId: 't1',
  edited: false,
  segments: [
    TranscriptSegmentView(
      id: 1,
      seq: 0,
      startMs: 0,
      endMs: 4000,
      text: 'Ask Jon about the budget review',
      speaker: 'Speaker 1',
      tokens: [SegmentToken(text: ' Jon', p: 0.2)],
    ),
    TranscriptSegmentView(
      id: 2,
      seq: 1,
      startMs: 5000,
      endMs: 9000,
      text: 'Notes go out on Friday',
      originalText: 'Notes go out on Fryday',
    ),
  ],
  markers: [TranscriptMarkerView(id: 1, atMs: 4500, label: 'Decision')],
);

List<Override> _overrides({bool locked = false}) => [
  askAvailabilityStateProvider.overrideWith(
    (ref) async => AskAvailability.ready,
  ),
  askModelEntryProvider.overrideWith((ref) async => null),
  askEngineProvider.overrideWith((ref) async => FakeAskEngine()),
  askSaveHistoryEnabledProvider.overrideWithValue(true),
  askThreadsProvider.overrideWith(
    (ref) async => [
      AskThread(
        id: 'a',
        recordingId: null,
        updatedAt: DateTime(2026, 10, 18),
        turns: [
          AskTurn(
            id: 'a1',
            question: 'When is the launch?',
            answer: 'May.',
            found: true,
            citations: const [],
            createdAt: DateTime(2026, 10, 18),
          ),
        ],
      ),
    ],
  ),
  storeProductsProvider.overrideWith(
    (ref) async => const [
      StoreProduct(id: annualProductId, price: 'TEST 12.00'),
      StoreProduct(id: lifetimeProductId, price: 'TEST 34.00'),
    ],
  ),
  // SEC-03: unlocked unless a test asks for the lock screen.
  if (!locked) appLockProvider.overrideWith(_Unlocked.new),
  deviceAuthenticatorProvider.overrideWithValue(_NoAuth()),
  templateStoreProvider.overrideWithValue(_Templates()),
  // rootBundle caches futures across tests (fake-async zones): read the
  // asset files directly instead.
  profileAssetLoaderProvider.overrideWithValue(
    (key) async => File(key).readAsStringSync(),
  ),
  editorProfilesProvider.overrideWith(
    (ref) async => (await ref.watch(builtinProfilesProvider.future)).all,
  ),
  templatePreviewRecordingsProvider.overrideWith((ref, id) async => const []),
  transcriptViewProvider('rec-a').overrideWith((ref) async => _transcript),
  transcriptPlaybackProvider('rec-a').overrideWith(
    (ref) async => TranscriptPlayback(
      FakeTranscriptPlayer(),
      PlaybackTimeline(const [
        PlaybackChunk(path: '/c0', startMs: 0, pcmBytes: 10000 * 32),
      ]),
    ),
  ),
  flavorProvider.overrideWithValue(Flavor.prod),
  processingViewsProvider.overrideWith((ref) async => sampleQueue()),
  // Hermetic: no platform storage dir (path_provider) behind the
  // recording/model providers that joined in integration wave 2.
  storagePathsProvider.overrideWith((ref) => Completer<StoragePaths>().future),
  // APP-01: past onboarding, so the router does not redirect.
  settingsStoreProvider.overrideWithValue(
    FakeSettingsStore({OnboardingKeys.completed: true}),
  ),
  managedSettingsSourceProvider.overrideWithValue(const _Managed()),
  vaultTargetsProvider.overrideWith(
    (ref) => Stream.value(const [
      VaultTargetInfo(
        id: 'v1',
        name: 'Obsidian vault',
        platform: VaultPlatform.appLocal,
        handle: '/x',
      ),
    ]),
  ),
  profileListProvider.overrideWith(
    (ref) => Stream.value([
      for (final id in ['meeting', 'warranty', 'engineering'])
        ProfileCodec.parseYaml(
          File('assets/profiles/$id.yaml').readAsStringSync(),
          profileSource: ProfileSource.builtin,
        ).profile!,
    ]),
  ),
  pendingExportsProvider.overrideWith(
    (ref) => Stream.value(const [
      PendingExport(
        recordingId: 'rec-a',
        title: 'Standup',
        reason: PendingReason.accessRevoked,
        jobId: 'j1',
        targetId: 'v1',
        targetName: 'Obsidian vault',
      ),
      PendingExport(
        recordingId: 'rec-b',
        title: '',
        reason: PendingReason.noDestination,
        jobId: 'j2',
      ),
    ]),
  ),
  routingRuleListProvider.overrideWith(
    (ref) => Stream.value(const [
      RoutingRule(
        id: 'r1',
        priority: 10,
        targetId: 'v1',
        subPath: 'Meetings',
        match: RuleMatch(tagsAny: ['work']),
      ),
    ]),
  ),
  // APP-02 library, recording detail and action items.
  ...libraryOverrides(
    actionItems: const [
      ActionItemView(
        id: 1,
        recordingId: 'rec-a',
        recordingTitle: 'Weekly planning',
        body: 'Update the client SDK',
        done: false,
        owner: 'Sam',
      ),
    ],
  ),
  // APP-05 review screen + settings.
  reviewProfileProvider('meeting')
      .overrideWith((ref) async => fixtures.builtinProfiles['meeting']),
  reviewProfilesProvider.overrideWith(
    (ref) => Stream.value(fixtures.builtinProfiles.all),
  ),
  // MDL-03 model screen: hermetic catalog/install state.
  modelEntriesProvider.overrideWith(
    (ref) async => [
      ModelEntry(
        model: seedStt,
        installed: InstalledModel(
          id: seedStt.id,
          version: '1',
          size: seedStt.size,
          relativePath: 'models/x/y.bin',
          installedAt: DateTime.utc(2026),
        ),
        access: AccessLevel.full,
        compatible: true,
        recommended: true,
        active: true,
      ),
      ModelEntry(
        model: seedLlm,
        installed: null,
        access: AccessLevel.full,
        compatible: true,
        recommended: true,
        active: false,
      ),
    ],
  ),
  storageUsageProvider.overrideWith(
    (ref) => Stream.value(
      const StorageUsage(modelBytes: 1, audioBytes: 2, transcriptBytes: 3),
    ),
  ),
  modelDownloadProgressProvider.overrideWith((ref) => Stream.value(const {})),
  networkDisabledProvider.overrideWith((ref) => Stream.value(false)),
  routingRulesProvider.overrideWith(
    (ref) => Stream.value(const [
      RoutingRuleInfo(id: 'r1', targetId: 'v1', subPath: 'Meetings'),
    ]),
  ),
];

Future<void> _pumpAt(
  WidgetTester t,
  String location, {
  required ThemeMode mode,
  required double scale,
  bool locked = false,
}) async {
  final container = ProviderContainer(overrides: _overrides(locked: locked));
  addTearDown(container.dispose);
  container.read(appRouterProvider).go(location);
  t.platformDispatcher
    ..platformBrightnessTestValue = mode == ThemeMode.dark
        ? Brightness.dark
        : Brightness.light
    ..textScaleFactorTestValue = scale;
  addTearDown(t.platformDispatcher.clearAllTestValues);
  await t.pumpWidget(
    UncontrolledProviderScope(container: container, child: const App()),
  );
  await t.pumpAndSettle();
  // The variant really applies, and the route really rendered.
  final ctx = t.element(find.byType(Scaffold).last);
  expect(
    Theme.of(ctx).brightness,
    mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
  );
  expect(MediaQuery.textScalerOf(ctx).scale(10), 10 * scale);
  expect(
    container.read(appRouterProvider).routeInformationProvider.value.uri.path,
    location,
  );
}

void main() {
  for (final MapEntry(key: name, value: location) in _screens.entries) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets(
        '[APP-06/AC1]${name.startsWith('Ask') ? ' [ASK-04/AC3]' : ''} $name (${mode.name}): labelled controls, '
        'tap targets and WCAG AA text contrast',
        (t) async {
          final handle = t.ensureSemantics();
          t.view
            ..physicalSize = const Size(390, 844)
            ..devicePixelRatio = 1;
          addTearDown(t.view.reset);
          await _pumpAt(t, location, mode: mode, scale: 1);
          await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(t, meetsGuideline(androidTapTargetGuideline));
          await expectLater(t, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(t, meetsGuideline(textContrastGuideline));
          handle.dispose();
        },
      );
    }
    testWidgets(
      '[APP-06/AC1]${name.startsWith('Ask') ? ' [ASK-04/AC3]' : ''} $name renders at 200 % text size without '
      'overflow',
      (t) async {
        t.view
          ..physicalSize = const Size(390, 844)
          ..devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await _pumpAt(t, location, mode: ThemeMode.light, scale: 2);
        expect(t.takeException(), isNull);
        // Scroll through scrollable content: nothing overflows further down.
        final scrollables = find.byType(Scrollable);
        if (scrollables.evaluate().isNotEmpty) {
          await t.drag(scrollables.first, const Offset(0, -3000));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        }
      },
    );
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('[APP-06/AC1] App lock screen (${mode.name}): labelled '
        'controls, tap targets and WCAG AA text contrast', (t) async {
      final handle = t.ensureSemantics();
      t.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await _pumpAt(t, '/settings', mode: mode, scale: 1, locked: true);
      expect(find.byType(LockScreen), findsOneWidget);
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      await expectLater(t, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(t, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  }

  testWidgets('[APP-06/AC1] App lock screen renders at 200 % text size '
      'without overflow', (t) async {
    t.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await _pumpAt(
      t,
      '/settings',
      mode: ThemeMode.light,
      scale: 2,
      locked: true,
    );
    expect(find.byType(LockScreen), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('[APP-06/AC1] Network activity (${mode.name}, '
          '${(scale * 100).round()} %): labelled controls, tap targets, '
          'contrast, no overflow', (t) async {
        final handle = t.ensureSemantics();
        t.view
          ..physicalSize = const Size(390, 844)
          ..devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final log = NetworkActivityLog()
          ..record(
            NetworkActivityEntry.request(
              DateTime.utc(2026, 10, 14, 9),
              Uri.parse('https://huggingface.co/ggerganov/model.bin'),
              NetworkOutcome.completed,
              statusCode: 200,
              bytes: 77000000,
            ),
          );
        await t.pumpWidget(
          ProviderScope(
            overrides: [networkActivityLogProvider.overrideWithValue(log)],
            child: MaterialApp(
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: mode,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const NetworkActivityScreen(),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        if (scale == 1) {
          await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(t, meetsGuideline(androidTapTargetGuideline));
          await expectLater(t, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(t, meetsGuideline(textContrastGuideline));
        }
        handle.dispose();
      });
    }
  }

  testWidgets('[APP-06/AC1] tab bar and queue indicator announce their '
      'purpose to screen readers', (t) async {
    final handle = t.ensureSemantics();
    await _pumpAt(t, '/record', mode: ThemeMode.light, scale: 1);
    final l = lookupAppLocalizations(kFallbackLocale);
    for (final label in [
      l.tabRecord,
      l.tabLibrary,
      l.tabProfiles,
      l.tabSettings,
    ]) {
      expect(find.bySemanticsLabel(RegExp(label)), findsWidgets);
    }
    expect(
      find.bySemanticsLabel(
        RegExp('Processing 3 recordings · 1 needs attention. Open processing'),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  test('theme colour pairs used for status text meet WCAG AA (4.5:1)', () {
    double luminance(Color c) => c.computeLuminance();
    double ratio(Color a, Color b) {
      final la = luminance(a);
      final lb = luminance(b);
      final hi = la > lb ? la : lb;
      final lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    for (final theme in [AppTheme.light, AppTheme.dark]) {
      final s = theme.colorScheme;
      for (final (fg, bg) in [
        (s.onSurface, s.surface),
        (s.onSurfaceVariant, s.surface),
        (s.primary, s.surface),
        (s.error, s.surface),
        (s.onSecondaryContainer, s.secondaryContainer),
        (s.onError, s.error),
      ]) {
        expect(ratio(fg, bg), greaterThanOrEqualTo(4.5), reason: '$fg on $bg');
      }
    }
  });
}
