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
import 'package:vaultvoice/core/db/enums.dart';
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
import 'package:vaultvoice/features/legal/domain/legal_documents.dart';
import 'package:vaultvoice/features/models/data/download_providers.dart';
import 'package:vaultvoice/features/models/data/model_import_providers.dart';
import 'package:vaultvoice/features/models/data/model_state_providers.dart';
import 'package:vaultvoice/features/models/domain/installed_model.dart';
import 'package:vaultvoice/features/models/domain/model_bundle.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';
import 'package:vaultvoice/features/models/presentation/model_download_actions.dart';
import 'package:vaultvoice/features/onboarding/data/onboarding_readiness_providers.dart';
import 'package:vaultvoice/features/onboarding/domain/onboarding_keys.dart';
import 'package:vaultvoice/features/onboarding/domain/onboarding_readiness.dart';
import 'package:vaultvoice/features/onboarding/presentation/onboarding_screen.dart';
import 'package:vaultvoice/features/onboarding/presentation/permission_priming.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_providers.dart';
import 'package:vaultvoice/features/recording/data/recording_providers.dart';
import 'package:vaultvoice/features/recording/data/recording_screen_providers.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

import '../fakes/fake_local_notifier.dart';
import '../fakes/fake_model_downloader.dart';
import '../fakes/fake_pcm_mic_source.dart';
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

final List<InstalledModel> _bothInstalled = [
  for (final m in [seedStt, seedLlm])
    InstalledModel(
      id: m.id,
      version: '1',
      size: m.size,
      relativePath: 'models/${m.id}/${m.file}',
      installedAt: DateTime.utc(2026),
      type: m.type,
    ),
];

/// Microphone whose OS prompt answer the test scripts.
class _Mic extends FakePcmMicSource {
  _Mic({bool granted = true, this.allowOnRequest = false}) {
    permission = granted;
  }

  final bool allowOnRequest;

  @override
  Future<bool> hasPermission({bool request = true}) async {
    if (request) {
      permissionRequests++;
      if (allowOnRequest) permission = true;
    }
    return permission;
  }
}

class _Rig {
  _Rig({
    bool grantNotifications = false,
    Set<ModelDownloadBlock> blocks = const {},
    Result<VaultFolder?> folder = kFolderRefused,
    this._networkDisabled = false,
    this._installed = const [],
    Map<String, Object?> settings = const {},
    bool micGranted = true,
    bool micAllowOnRequest = false,
    int freeBytes = 10 * 1024 * 1024 * 1024,
  }) : mic = _Mic(granted: micGranted, allowOnRequest: micAllowOnRequest),
       disk = FakeDiskSpaceProbe(freeBytes),
       installedCtl = StreamController<List<InstalledModel>>.broadcast(),
       notifier = FakeLocalNotifier(grant: grantNotifications),
       downloader = FakeModelDownloader(blocks: blocks),
       folders = FakeVaultFolderAccess(folder),
       store = FakeSettingsStore({
         LegalKeys.acceptedVersion: kLegalVersion,
         ...settings,
       });

  final FakeLocalNotifier notifier;
  final FakeModelDownloader downloader;
  final FakeVaultFolderAccess folders;
  final FakeSettingsStore store;
  final launcher = FakeAppSettingsLauncher();
  final _Mic mic;
  final FakeDiskSpaceProbe disk;
  final StreamController<List<InstalledModel>> installedCtl;
  final bool _networkDisabled;
  final List<InstalledModel> _installed;
  late final ProviderContainer container;

  List<Override> get overrides => [
    flavorProvider.overrideWithValue(Flavor.prod),
    settingsStoreProvider.overrideWithValue(store),
    storagePathsProvider.overrideWith(
      (ref) async => StoragePaths('/vv-onboarding-test'),
    ),
    pcmMicSourceProvider.overrideWithValue(mic),
    diskSpaceProbeProvider.overrideWithValue(disk),
    vaultVoiceDatabaseProvider.overrideWith((ref) {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      // Not closed on dispose: closing needs real async, which hangs the
      // fake-async teardown once the readiness check has opened the DB.
      return VaultVoiceDatabase(NativeDatabase.memory());
    }),
    processingViewsProvider.overrideWith((ref) async => const []),
    // Integration W3: AUD-08's Record screen pickers (DB streams).
    profileChoicesProvider.overrideWith((ref) => Stream.value(const [])),
    destinationChoicesProvider.overrideWith((ref) async => const []),
    localNotificationsProvider.overrideWithValue(notifier),
    appSettingsLauncherProvider.overrideWithValue(launcher),
    vaultFolderAccessProvider.overrideWithValue(folders),
    recommendedModelBundleProvider.overrideWith((ref) async => _bundle),
    installedModelsProvider.overrideWith((ref) async* {
      yield _installed;
      yield* installedCtl.stream;
    }),
    modelDownloaderProvider.overrideWith((ref) async => downloader),
    networkDisabledProvider.overrideWith(
      (ref) => Stream.value(_networkDisabled),
    ),
    // APP-02 Library behind "Explore first".
    ...libraryOverrides(),
  ];

  Future<void> installBoth(WidgetTester t) async {
    installedCtl.add(_bothInstalled);
    await t.pumpAndSettle();
  }

  Future<void> pump(WidgetTester t) async {
    t.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    // Not awaited: the done event needs the event loop, unavailable here.
    addTearDown(() => unawaited(installedCtl.close()));
    await t.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await settle(t);
  }

  /// The readiness check reads the real in-memory DB, which needs real async
  /// gaps between frames.
  static Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 3; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pumpAndSettle();
    }
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
    final done = _Rig(
      installed: _bothInstalled,
      settings: {
        OnboardingKeys.completed: true,
        OnboardingKeys.notesInApp: true,
      },
    );
    await done.pump(t);
    expect(done.location, '/record');
    expect(find.byType(OnboardingScreen), findsNothing);
  });

  testWidgets('[APP-01/AC2] every required item blocks Continue with a '
      'Fix button until fixed; completion only when all are ready', (t) async {
    final rig = _Rig(
      blocks: {ModelDownloadBlock.unmeteredNetworkRequired},
      micGranted: false,
    );
    await rig.pump(t);

    // Consent explainer (SEC-07 placement) incl. the no-call statement;
    // continuing requires the acknowledgement.
    await _toStep(t, OnboardingStep.consent);
    expect(find.text(_l.consentNeverCalls), findsOneWidget);
    expect(t.widget<FilledButton>(_next()).onPressed, isNull);
    await _tap(t, find.byKey(const ValueKey('onboarding-consent-check')));
    await _tap(t, _next());
    expect(rig.store.values[OnboardingKeys.consentAcknowledgedAt], isA<int>());

    // Permissions: nothing was requested at launch or by merely arriving.
    expect(rig.mic.permissionRequests, 0, reason: 'SEC-09: only on a tap');
    expect(find.text(_l.readinessMicMissing), findsOneWidget);
    expect(t.widget<FilledButton>(_next()).onPressed, isNull);
    await _tap(t, find.byKey(const ValueKey('onboarding-allow-notifications')));
    expect(rig.notifier.permissionRequests, 1);
    expect(
      find.byKey(const ValueKey('onboarding-notifications-denied')),
      findsOneWidget,
    );

    // Fix → priming explanation first; "Not now" asks nothing.
    await _tap(t, find.byKey(const ValueKey('onboarding-fix-microphone')));
    expect(find.text(_l.micPrimerTitle), findsOneWidget);
    await _tap(t, find.text(_l.commonNotNow));
    expect(rig.mic.permissionRequests, 0);

    // Continue in the primer → OS prompt → denied → Open settings.
    await _tap(t, find.byKey(const ValueKey('onboarding-fix-microphone')));
    await _tap(
      t,
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(_l.commonContinue),
      ),
    );
    expect(rig.mic.permissionRequests, 1);
    expect(find.byKey(const ValueKey('onboarding-mic-denied')), findsOneWidget);
    expect(t.widget<FilledButton>(_next()).onPressed, isNull);
    await _tap(t, find.text(_l.permissionOpenSettings).first);
    expect(rig.launcher.calls, 1);

    // Allowed in Settings, back in the app: the check re-runs.
    rig.mic.permission = true;
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpAndSettle();
    expect(t.widget<FilledButton>(_next()).onPressed, isNotNull);
    await _tap(t, _next());

    // Models: both missing → two messages, one Fix; Continue disabled.
    expect(find.text(_l.readinessSttMissing), findsOneWidget);
    expect(find.text(_l.readinessLlmMissing), findsOneWidget);
    expect(t.widget<FilledButton>(_next()).onPressed, isNull);
    await _tap(t, find.byKey(const ValueKey('onboarding-fix-sttModel')));
    expect(find.text(_l.downloadCellularTitle), findsOneWidget);
    await _tap(t, find.text(_l.downloadWaitForWifi));
    expect(rig.downloader.started, isEmpty);
    _dismissSnackBars(t);
    expect(t.widget<FilledButton>(_next()).onPressed, isNull);
    await rig.installBoth(t);
    expect(find.text(_l.readinessSttMissing), findsNothing);
    await _tap(t, _next());

    // Folder: access refused → still required; keeping notes in the app is
    // an explicit, remembered choice.
    expect(find.text(_l.readinessFolderMissing), findsOneWidget);
    await _tap(t, find.byKey(const ValueKey('onboarding-choose-folder')));
    expect(rig.folders.picks, 1);
    expect(find.text(_l.onboardingFolderFailed), findsOneWidget);
    expect(rig.store.values[OnboardingKeys.completed], isNull);
    await _tap(t, find.byKey(const ValueKey('onboarding-keep-in-app')));
    expect(rig.store.values[OnboardingKeys.notesInApp], true);

    // Ready → the guided first recording only opens the Record tab.
    await _tap(t, find.byKey(const ValueKey('onboarding-first-recording')));
    expect(rig.store.values[OnboardingKeys.completed], true);
    expect(rig.location, '/record');
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('[APP-01/AC2] finishing re-checks: a revoked microphone sends '
      'the user back and nothing is marked completed', (t) async {
    final rig = _Rig(installed: _bothInstalled);
    await rig.pump(t);
    await _toStep(t, OnboardingStep.ready);
    await _tap(t, find.byKey(const ValueKey('onboarding-keep-in-app')));
    expect(find.text(_l.onboardingReadyTitle), findsOneWidget);
    rig.mic.permission = false;
    await _tap(t, find.byKey(const ValueKey('onboarding-first-recording')));
    expect(rig.store.values[OnboardingKeys.completed], isNull);
    expect(rig.location, '/onboarding');
    expect(find.text(_l.readinessMicMissing), findsOneWidget);
    expect(find.text(_l.readinessBlocked), findsOneWidget);
  });

  testWidgets('[APP-01/AC2] granted notifications and a picked folder are '
      'confirmed; Explore first opens the Library', (t) async {
    final rig = _Rig(
      installed: _bothInstalled,
      grantNotifications: true,
      folder: const Ok(
        VaultFolder(
          kind: VaultTargetKind.bookmark,
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
    await _Rig.settle(t);
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
      'download with progress, continue once installed', (t) async {
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
    // Models are required: Continue waits for the install.
    expect(t.widget<FilledButton>(_next()).onPressed, isNull);
    await rig.installBoth(t);
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
    final rig = _Rig(installed: _bothInstalled);
    await rig.pump(t);
    await _toStep(t, OnboardingStep.models);
    expect(find.text(_l.onboardingModelsReady), findsOneWidget);
    expect(find.text(_l.modelStatusInstalled), findsNWidgets(2));
  });

  group('relaunch re-check (onboarding.completed from an older build)', () {
    final done = {OnboardingKeys.completed: true};

    Future<_Rig> relaunch(
      WidgetTester t, {
      List<InstalledModel>? installed,
      bool mic = true,
      bool notes = true,
      int free = 10 * 1024 * 1024 * 1024,
    }) async {
      final rig = _Rig(
        installed: installed ?? _bothInstalled,
        micGranted: mic,
        freeBytes: free,
        settings: {...done, if (notes) OnboardingKeys.notesInApp: true},
      );
      await rig.pump(t);
      return rig;
    }

    testWidgets('[APP-01/AC2] no models installed → back to the models '
        'step with Fix, never Record', (t) async {
      final rig = await relaunch(t, installed: const []);
      expect(rig.location, '/onboarding');
      expect(find.text(_l.onboardingModelsTitle), findsOneWidget);
      expect(find.text(_l.readinessSttMissing), findsOneWidget);
      expect(find.text(_l.readinessLlmMissing), findsOneWidget);
      expect(
        find.byKey(const ValueKey('onboarding-fix-sttModel')),
        findsOneWidget,
      );
      expect(t.widget<FilledButton>(_next()).onPressed, isNull);
      expect(rig.store.values[OnboardingKeys.completed], true);
    });

    testWidgets('[APP-01/AC2] only the language model missing', (t) async {
      final rig = await relaunch(t, installed: [_bothInstalled.first]);
      expect(rig.location, '/onboarding');
      expect(find.text(_l.readinessSttMissing), findsNothing);
      expect(find.text(_l.readinessLlmMissing), findsOneWidget);
      expect(
        find.byKey(const ValueKey('onboarding-fix-llmModel')),
        findsOneWidget,
      );
    });

    testWidgets('[APP-01/AC2] only the speech model missing', (t) async {
      final rig = await relaunch(t, installed: [_bothInstalled.last]);
      expect(rig.location, '/onboarding');
      expect(find.text(_l.readinessSttMissing), findsOneWidget);
      expect(find.text(_l.readinessLlmMissing), findsNothing);
    });

    testWidgets('[APP-01/AC2] microphone missing → permissions step, '
        'nothing requested until the Fix tap', (t) async {
      final rig = await relaunch(t, mic: false);
      expect(rig.location, '/onboarding');
      expect(find.text(_l.onboardingPermissionsTitle), findsOneWidget);
      expect(find.text(_l.readinessMicMissing), findsOneWidget);
      expect(rig.mic.permissionRequests, 0);
    });

    testWidgets('[APP-01/AC2] a completed user with a missing item can still '
        'read the Library; only Record is gated', (t) async {
      final rig = await relaunch(t, mic: false);
      expect(rig.location, '/onboarding');
      await _tap(t, find.byKey(const ValueKey('onboarding-open-library')));
      expect(rig.location, '/library');
      rig.container.read(appRouterProvider).go('/record');
      await t.pumpAndSettle();
      expect(rig.location, '/onboarding');
    });

    testWidgets('[APP-01/AC2] an existing app-local vault target counts as '
        'a notes destination', (t) async {
      final rig = await relaunch(t, notes: false);
      expect(rig.location, '/onboarding');
      await t.runAsync(
        () => rig.container
            .read(vaultVoiceDatabaseProvider)
            .vaultRepository
            .upsertTarget(
              VaultTargetsCompanion.insert(
                id: 'local',
                platform: VaultPlatform.appLocal,
                displayName: 'In app',
                handle: '/vault',
                createdAt: DateTime.utc(2026),
              ),
            ),
      );
      final sub = rig.container.listen(onboardingReadinessProvider, (_, _) {});
      addTearDown(sub.close);
      rig.container.invalidate(onboardingReadinessProvider);
      await _Rig.settle(t);
      expect(sub.read().requireValue.notesDestinationChosen, isTrue);
    });

    testWidgets('[APP-01/AC2] no notes destination → folder step; '
        'Keep in app is remembered', (t) async {
      final rig = await relaunch(t, notes: false);
      expect(rig.location, '/onboarding');
      expect(find.text(_l.onboardingFolderTitle), findsOneWidget);
      expect(find.text(_l.readinessFolderMissing), findsOneWidget);
      expect(find.byKey(const ValueKey('onboarding-next')), findsNothing);
      await _tap(t, find.byKey(const ValueKey('onboarding-keep-in-app')));
      expect(rig.store.values[OnboardingKeys.notesInApp], true);
      expect(find.text(_l.onboardingReadyTitle), findsOneWidget);
    });

    testWidgets('[APP-01/AC2] not enough disk space → needed vs free '
        'explained with a re-check Fix', (t) async {
      final rig = await relaunch(t, installed: const [], free: 1000);
      expect(rig.location, '/onboarding');
      expect(
        find.text(
          _l.readinessSpaceMissing(
            formatSize(_bundle.totalBytes),
            formatSize(1000),
          ),
        ),
        findsOneWidget,
      );
      rig.disk.free = 10 * 1024 * 1024 * 1024;
      await _tap(t, find.byKey(const ValueKey('onboarding-fix-diskSpace')));
      expect(find.text(_l.readinessSttMissing), findsOneWidget);
      expect(
        find.byKey(const ValueKey('onboarding-fix-diskSpace')),
        findsNothing,
      );
    });

    testWidgets('[APP-01/AC2] deleting a model later routes back from '
        'Record', (t) async {
      final rig = await relaunch(t);
      expect(rig.location, '/record');
      rig.installedCtl.add([_bothInstalled.first]);
      await t.pumpAndSettle();
      expect(rig.location, '/onboarding');
      expect(find.text(_l.readinessLlmMissing), findsOneWidget);
    });
  });

  testWidgets('[APP-01/AC2] readiness composes models, notes choice, '
      'microphone and space', (t) async {
    final rig = _Rig(micGranted: false, freeBytes: 5);
    await rig.pump(t);
    final sub = rig.container.listen(onboardingReadinessProvider, (_, _) {});
    addTearDown(sub.close);
    await _Rig.settle(t);
    final r = sub.read().requireValue;
    expect(r.missing, [
      ReadinessItem.microphone,
      ReadinessItem.sttModel,
      ReadinessItem.llmModel,
      ReadinessItem.diskSpace,
      ReadinessItem.notesFolder,
    ]);
    expect(r.requiredBytes, _bundle.totalBytes);
    expect(r.firstMissingStep, OnboardingStep.permissions);
    expect(OnboardingReadiness.allReady.isReady, isTrue);
    expect(OnboardingReadiness.allReady.firstMissingStep, isNull);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('[APP-06/AC1] every onboarding step: labelled controls, tap '
        'targets, contrast and no overflow at ${scale}x text', (t) async {
      final handle = t.ensureSemantics();
      t.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(t.platformDispatcher.clearAllTestValues);
      final rig = _Rig(installed: _bothInstalled);
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
