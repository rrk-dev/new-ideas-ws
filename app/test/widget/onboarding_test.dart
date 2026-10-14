import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/app.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/flavor.dart';
import 'package:vaultvoice/core/flavor_provider.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/platform/app_settings_launcher.dart';
import 'package:vaultvoice/core/routing/app_router.dart';
import 'package:vaultvoice/features/export/data/export_providers.dart';
import 'package:vaultvoice/features/export/domain/vault_folder.dart';
import 'package:vaultvoice/features/models/data/download_providers.dart';
import 'package:vaultvoice/features/models/data/model_import_providers.dart';
import 'package:vaultvoice/features/models/data/model_state_providers.dart';
import 'package:vaultvoice/features/models/domain/installed_model.dart';
import 'package:vaultvoice/features/models/domain/model_bundle.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';
import 'package:vaultvoice/features/models/presentation/model_download_actions.dart';
import 'package:vaultvoice/features/onboarding/domain/onboarding_keys.dart';
import 'package:vaultvoice/features/onboarding/presentation/onboarding_screen.dart';
import 'package:vaultvoice/features/onboarding/presentation/permission_priming.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_providers.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

import '../fakes/fake_local_notifier.dart';
import '../fakes/fake_model_downloader.dart';
import '../fakes/fake_permission_hosts.dart';
import '../fakes/fake_settings_store.dart';
import '../helpers/library_fixtures.dart';
import '../helpers/model_fixtures.dart';

final AppLocalizations _l = lookupAppLocalizations(kFallbackLocale);

final _bundle = ModelBundle(
  tier: DeviceTier.mid,
  deviceKnown: true,
  totalRamBytes: 6 * 1024 * 1024 * 1024,
  models: [seedStt, seedLlm],
);

class _Rig {
  _Rig({
    bool grantNotifications = false,
    Set<ModelDownloadBlock> blocks = const {},
    Result<VaultFolder?> folder = kFolderRefused,
    this._networkDisabled = false,
    this._installed = const [],
    Map<String, Object?> settings = const {},
  }) : notifier = FakeLocalNotifier(grant: grantNotifications),
       downloader = FakeModelDownloader(blocks: blocks),
       folders = FakeVaultFolderAccess(folder),
       store = FakeSettingsStore(settings);

  final FakeLocalNotifier notifier;
  final FakeModelDownloader downloader;
  final FakeVaultFolderAccess folders;
  final FakeSettingsStore store;
  final launcher = FakeAppSettingsLauncher();
  final bool _networkDisabled;
  final List<InstalledModel> _installed;
  late final ProviderContainer container;

  List<Override> get overrides => [
    flavorProvider.overrideWithValue(Flavor.prod),
    settingsStoreProvider.overrideWithValue(store),
    storagePathsProvider.overrideWith(
      (ref) => Completer<StoragePaths>().future,
    ),
    vaultVoiceDatabaseProvider.overrideWith((ref) {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final db = VaultVoiceDatabase(NativeDatabase.memory());
      ref.onDispose(db.close);
      return db;
    }),
    processingViewsProvider.overrideWith((ref) async => const []),
    localNotificationsProvider.overrideWithValue(notifier),
    appSettingsLauncherProvider.overrideWithValue(launcher),
    vaultFolderAccessProvider.overrideWithValue(folders),
    recommendedModelBundleProvider.overrideWith((ref) async => _bundle),
    installedModelsProvider.overrideWith((ref) => Stream.value(_installed)),
    modelDownloaderProvider.overrideWith((ref) async => downloader),
    networkDisabledProvider.overrideWith(
      (ref) => Stream.value(_networkDisabled),
    ),
    // APP-02 Library behind "Explore first".
    ...libraryOverrides(),
  ];

  Future<void> pump(WidgetTester t) async {
    t.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await t.pumpAndSettle();
  }

  String get location =>
      container.read(appRouterProvider).routeInformationProvider.value.uri.path;
}

void _dismissSnackBars(WidgetTester t) =>
    ScaffoldMessenger.of(t.element(find.byType(OnboardingScreen)))
        .removeCurrentSnackBar();

Finder _next() => find.byKey(const ValueKey('onboarding-next'));

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> _toStep(WidgetTester t, OnboardingStep step) async {
  if (step == OnboardingStep.privacy) return;
  await _tap(t, _next());
  if (step == OnboardingStep.consent) return;
  await _tap(t, find.byKey(const ValueKey('onboarding-consent-check')));
  await _tap(t, _next());
  if (step == OnboardingStep.permissions) return;
  await _tap(t, _next());
  if (step == OnboardingStep.models) return;
  await _tap(t, _next());
}

void main() {
  testWidgets('[APP-01/AC2] first launch redirects to onboarding', (t) async {
    final rig = _Rig();
    await rig.pump(t);
    expect(rig.location, '/onboarding');
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text(_l.onboardingPrivacyTitle), findsOneWidget);
    expect(find.text(_l.onboardingPrivacyNetwork), findsOneWidget);
  });

  testWidgets('[APP-01/AC2] a finished onboarding never shows again', (
    t,
  ) async {
    final done = _Rig(settings: {OnboardingKeys.completed: true});
    await done.pump(t);
    expect(done.location, '/record');
    expect(find.byType(OnboardingScreen), findsNothing);
  });

  testWidgets('[APP-01/AC2] denying every permission still finishes '
      'onboarding, with a recovery path for each', (t) async {
    final rig = _Rig(blocks: {ModelDownloadBlock.unmeteredNetworkRequired});
    await rig.pump(t);

    // Consent explainer (SEC-07 placement) incl. the no-call statement;
    // continuing requires the acknowledgement.
    await _toStep(t, OnboardingStep.consent);
    expect(find.text(_l.consentNeverCalls), findsOneWidget);
    expect(t.widget<FilledButton>(_next()).onPressed, isNull);
    await _tap(t, find.byKey(const ValueKey('onboarding-consent-check')));
    await _tap(t, _next());
    expect(rig.store.values[OnboardingKeys.consentAcknowledgedAt], isA<int>());

    // Permissions: the microphone is only explained, never requested here.
    expect(find.text(_l.onboardingPermissionMic), findsOneWidget);
    await _tap(t, find.byKey(const ValueKey('onboarding-allow-notifications')));
    expect(rig.notifier.permissionRequests, 1);
    expect(rig.store.values[SettingKeys.notificationsPermissionAsked], true);
    expect(
      find.byKey(const ValueKey('onboarding-notifications-denied')),
      findsOneWidget,
    );
    await _tap(t, find.text(_l.permissionOpenSettings));
    expect(rig.launcher.calls, 1, reason: 'denied → Open settings');
    await _tap(t, _next());

    // Models: decline mobile data → nothing downloads, the user continues.
    expect(find.text(seedStt.displayName), findsOneWidget);
    expect(find.text(seedLlm.displayName), findsOneWidget);
    await _tap(t, find.byKey(const ValueKey('onboarding-download-models')));
    expect(find.text(_l.downloadCellularTitle), findsOneWidget);
    await _tap(t, find.text(_l.downloadWaitForWifi));
    expect(rig.downloader.started, isEmpty);
    expect(find.text(_l.downloadWaitingForWifi), findsOneWidget);
    _dismissSnackBars(t);
    await _tap(t, _next());

    // Folder: access refused → explained; keep notes in the app instead.
    await _tap(t, find.byKey(const ValueKey('onboarding-choose-folder')));
    expect(rig.folders.picks, 1);
    expect(find.text(_l.onboardingFolderFailed), findsOneWidget);
    await _tap(t, find.byKey(const ValueKey('onboarding-keep-in-app')));

    // Ready → the guided first recording only opens the Record tab.
    await _tap(t, find.byKey(const ValueKey('onboarding-first-recording')));
    expect(rig.store.values[OnboardingKeys.completed], true);
    expect(rig.location, '/record');
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('[APP-01/AC2] granted notifications and a picked folder are '
      'confirmed; Explore first opens the Library', (t) async {
    final rig = _Rig(
      grantNotifications: true,
      folder: const Ok(
        VaultFolder(
          kind: VaultTargetKind.appLocal,
          handle: '/vault',
          displayName: 'Obsidian',
        ),
      ),
    );
    await rig.pump(t);
    await _toStep(t, OnboardingStep.permissions);
    await _tap(t, find.byKey(const ValueKey('onboarding-allow-notifications')));
    expect(find.text(_l.notificationsAllowed), findsOneWidget);
    await _tap(t, _next());
    await _tap(t, _next());
    await t.runAsync(() async {
      await t.tap(find.byKey(const ValueKey('onboarding-choose-folder')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await t.pumpAndSettle();
    expect(find.text(_l.onboardingFolderChosen('Obsidian')), findsOneWidget);
    final targets = await t.runAsync(
      () => rig.container.read(vaultRepositoryProvider).watchTargets().first,
    );
    expect(targets!.single.displayName, 'Obsidian');
    await _tap(t, _next());
    await _tap(t, find.byKey(const ValueKey('onboarding-explore')));
    expect(rig.location, '/library');
  });

  testWidgets('[APP-01] models step: recommended bundle with sizes, '
      'download with progress, continue while downloading', (t) async {
    final rig = _Rig();
    await rig.pump(t);
    await _toStep(t, OnboardingStep.models);
    expect(
      find.text(
        _l.onboardingModelsDevice(
          _l.deviceTierMid,
          formatSize(_bundle.totalRamBytes),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.text(_l.onboardingModelsTotal(formatSize(_bundle.totalBytes))),
      findsOneWidget,
    );
    await _tap(t, find.byKey(const ValueKey('onboarding-download-models')));
    expect(rig.downloader.started.map((s) => s.id), [seedStt.id, seedLlm.id]);
    expect(find.byType(LinearProgressIndicator), findsWidgets);
    expect(find.text(_l.downloadPhaseDownloading(25)), findsNWidgets(2));
    // Downloading never blocks: Continue stays enabled.
    expect(t.widget<FilledButton>(_next()).onPressed, isNotNull);
    await _tap(t, _next());
    expect(find.text(_l.onboardingFolderTitle), findsOneWidget);
  });

  testWidgets('[APP-01] mobile-data consent can be remembered', (t) async {
    final rig = _Rig(blocks: {ModelDownloadBlock.unmeteredNetworkRequired});
    await rig.pump(t);
    await _toStep(t, OnboardingStep.models);
    await _tap(t, find.byKey(const ValueKey('onboarding-download-models')));
    await _tap(t, find.byKey(const ValueKey('download-cellular-always')));
    await _tap(t, find.text(_l.downloadNow));
    expect(rig.downloader.started.first.allowCellular, isTrue);
    expect(rig.store.values[kAllowCellularDownloadsKey], true);
  });

  testWidgets('[APP-01] offline mode hides downloads and offers import', (
    t,
  ) async {
    final offline = _Rig(networkDisabled: true);
    await offline.pump(t);
    await _toStep(t, OnboardingStep.models);
    expect(
      find.byKey(const ValueKey('onboarding-download-models')),
      findsNothing,
    );
    expect(find.text(_l.onboardingModelsOffline), findsOneWidget);
    expect(find.text(_l.modelImportTitle), findsOneWidget);
  });

  testWidgets('[APP-01] installed bundle shows as ready', (t) async {
    final rig = _Rig(
      installed: [
        for (final m in [seedStt, seedLlm])
          InstalledModel(
            id: m.id,
            version: '1',
            size: m.size,
            relativePath: 'models/${m.id}/${m.file}',
            installedAt: DateTime.utc(2026),
          ),
      ],
    );
    await rig.pump(t);
    await _toStep(t, OnboardingStep.models);
    expect(find.text(_l.onboardingModelsReady), findsOneWidget);
    expect(find.text(_l.modelStatusInstalled), findsNWidgets(2));
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('[APP-06/AC1] every onboarding step: labelled controls, tap '
        'targets, contrast and no overflow at ${scale}x text', (t) async {
      final handle = t.ensureSemantics();
      t.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(t.platformDispatcher.clearAllTestValues);
      final rig = _Rig();
      await rig.pump(t);
      Future<void> check() async {
        expect(t.takeException(), isNull);
        await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(t, meetsGuideline(androidTapTargetGuideline));
        await expectLater(t, meetsGuideline(textContrastGuideline));
      }

      await check();
      await _tap(t, _next());
      await check();
      await _tap(t, find.byKey(const ValueKey('onboarding-consent-check')));
      await _tap(t, _next());
      await check();
      await _tap(t, _next());
      await check();
      await _tap(t, _next());
      await check();
      await _tap(t, find.byKey(const ValueKey('onboarding-keep-in-app')));
      await check();
      handle.dispose();
    });
  }

  group('microphone priming (first Record tap)', () {
    Future<(ProviderContainer, BuildContext)> host(
      WidgetTester t,
      FakeSettingsStore store,
      FakeAppSettingsLauncher launcher,
    ) async {
      final container = ProviderContainer(
        overrides: [
          settingsStoreProvider.overrideWithValue(store),
          appSettingsLauncherProvider.overrideWithValue(launcher),
        ],
      );
      addTearDown(container.dispose);
      late BuildContext ctx;
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (c) {
                  ctx = c;
                  return PermissionDeniedNotice.microphone();
                },
              ),
            ),
          ),
        ),
      );
      return (container, ctx);
    }

    testWidgets('[APP-01/AC2] explains once before the OS prompt; '
        '"Not now" requests nothing', (t) async {
      final store = FakeSettingsStore();
      final launcher = FakeAppSettingsLauncher();
      final (_, ctx) = await host(t, store, launcher);
      final ref = t.element(find.byType(PermissionDeniedNotice)) as WidgetRef;

      var answer = primeMicrophonePermission(ctx, ref);
      await t.pumpAndSettle();
      expect(find.text(_l.micPrimerTitle), findsOneWidget);
      await t.tap(find.text(_l.commonNotNow));
      await t.pumpAndSettle();
      expect(await answer, isFalse);
      expect(store.values[OnboardingKeys.micPrimed], isNull);

      answer = primeMicrophonePermission(ctx, ref);
      await t.pumpAndSettle();
      await t.tap(find.text(_l.commonContinue));
      await t.pumpAndSettle();
      expect(await answer, isTrue);
      expect(store.values[OnboardingKeys.micPrimed], true);

      // Second Record tap: straight to the OS prompt, no dialog.
      answer = primeMicrophonePermission(ctx, ref);
      await t.pumpAndSettle();
      expect(find.text(_l.micPrimerTitle), findsNothing);
      expect(await answer, isTrue);
    });

    testWidgets('[APP-01/AC2] microphone denied → explains what still works '
        'and opens system settings', (t) async {
      final launcher = FakeAppSettingsLauncher(opens: false);
      await host(t, FakeSettingsStore(), launcher);
      expect(find.text(_l.micDeniedBody), findsOneWidget);
      await t.tap(find.text(_l.permissionOpenSettings));
      await t.pumpAndSettle();
      expect(launcher.calls, 1);
      expect(find.text(_l.permissionOpenSettingsFailed), findsOneWidget);
    });
  });
}

String formatSize(int bytes) => formatBytes(_l, bytes);
