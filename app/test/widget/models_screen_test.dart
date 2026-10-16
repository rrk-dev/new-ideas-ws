import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/features/extraction/domain/device_tiering.dart';
import 'package:vaultvoice/features/licensing/data/licensing_providers.dart';
import 'package:vaultvoice/features/licensing/domain/feature_matrix.dart';
import 'package:vaultvoice/features/models/data/download_providers.dart';
import 'package:vaultvoice/features/models/data/model_import_providers.dart';
import 'package:vaultvoice/features/models/data/model_installer.dart';
import 'package:vaultvoice/features/models/data/model_management_providers.dart';
import 'package:vaultvoice/features/models/data/model_state_providers.dart';
import 'package:vaultvoice/features/models/domain/installed_model.dart';
import 'package:vaultvoice/features/models/domain/model_bundle.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';
import 'package:vaultvoice/features/models/domain/model_management.dart';
import 'package:vaultvoice/features/models/presentation/model_download_actions.dart';
import 'package:vaultvoice/features/models/presentation/models_screen.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_providers.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

import '../fakes/fake_local_notifier.dart';
import '../fakes/fake_model_downloader.dart';
import '../fakes/fake_settings_store.dart';
import '../helpers/model_fixtures.dart';

final AppLocalizations _l = lookupAppLocalizations(kFallbackLocale);

final CatalogModel _tiny = catalogModel(
  'whisper-tiny',
  size: 78 * 1000 * 1000,
  displayName: 'Whisper Tiny',
);
final CatalogModel _base = catalogModel(
  'whisper-base',
  size: 148 * 1000 * 1000,
  displayName: 'Whisper Base',
  version: '2',
);
final CatalogModel _small = catalogModel(
  'whisper-small',
  size: 488 * 1000 * 1000,
  tier: ModelTier.pro,
  displayName: 'Whisper Small',
);
final CatalogModel _llm = catalogModel(
  'qwen',
  type: ModelType.llm,
  size: 491 * 1000 * 1000,
  displayName: 'Qwen Small',
);
final CatalogModel _bigLlm = catalogModel(
  'llama-3b',
  type: ModelType.llm,
  size: 2000 * 1000 * 1000,
  minRamMb: 8192,
  displayName: 'Llama Large',
  attribution: 'Built with Llama',
);

InstalledModel _installed(CatalogModel m, {String? version}) => InstalledModel(
  id: m.id,
  version: version ?? m.version,
  size: m.size,
  relativePath: 'models/${m.id}/${m.file}',
  installedAt: DateTime.utc(2026),
);

class _Catalog extends ActiveCatalog {
  _Catalog(this._catalog, this._refreshes);

  final ModelCatalog _catalog;
  final List<DateTime> _refreshes;

  @override
  Future<ModelCatalog?> build() async => _catalog;

  @override
  Future<Result<ModelCatalog>> refresh() async {
    _refreshes.add(DateTime.now());
    return Ok(_catalog);
  }
}

class _Installer implements ModelInstaller {
  final removed = <String>[];

  @override
  Future<Result<void>> uninstall(String modelId) async {
    removed.add(modelId);
    return const Ok(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Rig {
  _Rig({
    this.installed = const [],
    this.offline = false,
    this.mode = DistributionMode.personal,
    Map<String, Object?> settings = const {},
  }) : store = FakeSettingsStore(settings);

  final List<InstalledModel> installed;
  final bool offline;
  final DistributionMode mode;
  final FakeSettingsStore store;
  final downloader = FakeModelDownloader();
  final installer = _Installer();
  final notifier = FakeLocalNotifier();
  final refreshes = <DateTime>[];
  late final catalog = _Catalog(
    catalogOf([_tiny, _base, _small, _llm, _bigLlm]),
    refreshes,
  );

  List<Override> get overrides => [
    settingsStoreProvider.overrideWithValue(store),
    distributionModeProvider.overrideWithValue(mode),
    activeCatalogProvider.overrideWith(() => catalog),
    installedModelsProvider.overrideWith((ref) => Stream.value(installed)),
    deviceProfileProvider.overrideWith(
      (ref) async => const DeviceProfile(
        platform: 'android',
        osVersion: 'test',
        totalRamBytes: 6 * 1024 * 1024 * 1024,
        availableRamBytes: 3 * 1024 * 1024 * 1024,
      ),
    ),
    recommendedModelBundleProvider.overrideWith(
      (ref) async => ModelBundle(
        tier: DeviceTier.mid,
        deviceKnown: true,
        totalRamBytes: 6 * 1024 * 1024 * 1024,
        models: [_tiny, _llm],
      ),
    ),
    storageUsageProvider.overrideWith(
      (ref) => Stream.value(
        const StorageUsage(
          modelBytes: 569 * 1000 * 1000,
          audioBytes: 115 * 1000 * 1000,
          transcriptBytes: 42 * 1000,
        ),
      ),
    ),
    modelDownloaderProvider.overrideWith((ref) async => downloader),
    modelInstallerProvider.overrideWith((ref) async => installer),
    networkDisabledProvider.overrideWith((ref) => Stream.value(offline)),
    localNotificationsProvider.overrideWithValue(notifier),
  ];

  Future<void> pump(WidgetTester t, {double scale = 1}) async {
    t.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const ModelsScreen(),
        ),
      ),
    );
    await t.pumpAndSettle();
  }
}

Finder _card(CatalogModel m) => find.byKey(ValueKey('model-${m.id}'));

Finder _inCard(CatalogModel m, Finder f) =>
    find.descendant(of: _card(m), matching: f);

Future<void> _tap(WidgetTester t, Finder f) async {
  if (f.evaluate().isEmpty) {
    // Back to the top, then scroll down until it is built.
    await t.drag(find.byType(Scrollable).first, const Offset(0, 5000));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      f,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('[SEC-05/AC1] the catalog attribution is shown on the cards '
      'of the models that have one', (t) async {
    await _Rig().pump(t);
    await t.scrollUntilVisible(
      _card(_bigLlm),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(_inCard(_bigLlm, find.text('Built with Llama')), findsOneWidget);
    expect(find.text('Built with Llama'), findsOneWidget);
  });

  testWidgets('[MDL-03] lists models by type with size, tier, device fit, '
      'status and storage totals', (t) async {
    final rig = _Rig(installed: [_installed(_tiny), _installed(_llm)]);
    await rig.pump(t);
    expect(find.text(_l.modelTypeStt), findsOneWidget);
    expect(find.text(_l.modelsStorageTitle), findsOneWidget);
    expect(find.text('569 MB'), findsOneWidget);
    expect(find.text('115 MB'), findsOneWidget);
    expect(_inCard(_tiny, find.text(_l.modelBadgeActive)), findsOneWidget);
    expect(_inCard(_tiny, find.text(_l.modelBadgeRecommended)), findsOneWidget);
    expect(
      _inCard(
        _tiny,
        find.text(_l.modelSizeVersion(formatBytes(_l, _tiny.size), '1')),
      ),
      findsOneWidget,
    );
    expect(_inCard(_small, find.text(_l.modelBadgePro)), findsOneWidget);
    await t.scrollUntilVisible(
      _card(_bigLlm),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      _inCard(
        _bigLlm,
        find.text(_l.modelIncompatible(formatBytes(_l, 8192 * 1024 * 1024))),
      ),
      findsOneWidget,
    );
    expect(find.text(_l.modelTypeLlm), findsOneWidget);
  });

  testWidgets('[MDL-03/AC1] deleting the active model asks for a '
      'replacement and switches to it first', (t) async {
    final rig = _Rig(
      installed: [_installed(_tiny), _installed(_base), _installed(_llm)],
      settings: {ActiveModelKeys.stt: _tiny.id},
    );
    await rig.pump(t);
    await _tap(t, find.byKey(ValueKey('model-delete-${_tiny.id}')));
    expect(find.text(_l.modelDeleteReplaceBody(_tiny.displayName)), findsOne);
    expect(find.byKey(ValueKey('model-replacement-${_base.id}')), findsOne);
    await t.tap(find.byKey(const ValueKey('model-delete-replace')));
    await t.pumpAndSettle();
    expect(rig.store.values[ActiveModelKeys.stt], _base.id);
    expect(rig.installer.removed, [_tiny.id]);
    expect(find.text(_l.modelDeleted(_tiny.displayName)), findsOneWidget);
  });

  testWidgets('[MDL-03/AC1] the only usable model of a type cannot be '
      'deleted; cancelling the replacement keeps everything', (t) async {
    final rig = _Rig(
      installed: [_installed(_tiny), _installed(_base), _installed(_llm)],
    );
    await rig.pump(t);
    await _tap(t, find.byKey(ValueKey('model-delete-${_llm.id}')));
    expect(find.text(_l.modelDeleteBlockedTitle), findsOneWidget);
    await t.tap(find.text(_l.commonOk));
    await t.pumpAndSettle();
    expect(rig.installer.removed, isEmpty);

    await _tap(t, find.byKey(ValueKey('model-delete-${_tiny.id}')));
    await t.tap(find.text(_l.commonCancel));
    await t.pumpAndSettle();
    expect(rig.installer.removed, isEmpty);
    expect(rig.store.values[ActiveModelKeys.stt], isNull);
  });

  testWidgets('[MDL-03] non-active model: confirm, then delete', (t) async {
    final rig = _Rig(
      installed: [_installed(_tiny), _installed(_base), _installed(_llm)],
    );
    await rig.pump(t);
    // The pipeline's selector (largest recommended-tier / default) uses base.
    await _tap(t, find.byKey(ValueKey('model-delete-${_tiny.id}')));
    await t.tap(find.byKey(const ValueKey('model-delete-confirm')));
    await t.pumpAndSettle();
    expect(rig.installer.removed, [_tiny.id]);
  });

  testWidgets('[MDL-03] set as default, update notice, download asks for '
      'notifications once (Android 13+) and shows progress', (t) async {
    final rig = _Rig(
      installed: [
        _installed(_tiny),
        _installed(_base, version: '1'),
        _installed(_llm),
      ],
    );
    await rig.pump(t);
    expect(find.text(_l.modelsUpdatesAvailable(1)), findsOneWidget);
    expect(_inCard(_base, find.text(_l.modelBadgeUpdate)), findsOneWidget);

    await _tap(t, find.byKey(ValueKey('model-use-${_tiny.id}')));
    expect(rig.store.values[ActiveModelKeys.stt], _tiny.id);

    await _tap(t, find.byKey(ValueKey('model-download-${_base.id}')));
    expect(rig.downloader.started.single.id, _base.id);
    expect(rig.notifier.permissionRequests, 1);
    expect(rig.store.values[SettingKeys.notificationsPermissionAsked], true);
    expect(_inCard(_base, find.byType(LinearProgressIndicator)), findsOne);
    expect(find.byKey(ValueKey('model-pause-${_base.id}')), findsOneWidget);

    await _tap(t, find.byKey(ValueKey('model-download-${_small.id}')));
    expect(rig.notifier.permissionRequests, 1, reason: 'asked only once');

    await t.tap(find.byKey(const ValueKey('models-check-updates')));
    await t.pumpAndSettle();
    expect(rig.refreshes, hasLength(1));
  });

  testWidgets('[MDL-03] network_disabled hides downloads and update checks; '
      'the import tile stays', (t) async {
    final rig = _Rig(installed: [_installed(_tiny)], offline: true);
    await rig.pump(t);
    expect(find.byKey(const ValueKey('models-offline')), findsOneWidget);
    expect(find.byKey(const ValueKey('models-check-updates')), findsNothing);
    expect(find.byKey(ValueKey('model-download-${_base.id}')), findsNothing);
    await t.scrollUntilVisible(
      find.text(_l.modelImportTitle),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(_l.modelImportTitle), findsOneWidget);
  });

  testWidgets('[MDL-03] Pro models on the commercial Free plan cannot be '
      'downloaded', (t) async {
    final rig = _Rig(mode: DistributionMode.commercial);
    await rig.pump(t);
    expect(find.byKey(ValueKey('model-upgrade-${_small.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('model-download-${_small.id}')), findsNothing);
    await _tap(t, find.byKey(ValueKey('model-upgrade-${_small.id}')));
    expect(rig.downloader.started, isEmpty);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('[APP-06/AC1] Models screen: labelled controls, tap targets, '
        'contrast at ${scale}x text', (t) async {
      final handle = t.ensureSemantics();
      final rig = _Rig(
        installed: [_installed(_tiny), _installed(_base), _installed(_llm)],
      );
      await rig.pump(t, scale: scale);
      expect(t.takeException(), isNull);
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      await expectLater(t, meetsGuideline(textContrastGuideline));
      await t.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      handle.dispose();
    });
  }
}
