import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/app_info.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/diagnostics/diagnostics_providers.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/features/export/data/pigeon/bookmark_api.g.dart';
import 'package:vaultvoice/features/export/data/pigeon/saf_api.g.dart';
import 'package:vaultvoice/features/extraction/data/device_profile_probe.dart';
import 'package:vaultvoice/features/extraction/data/native_device_capabilities.dart';
import 'package:vaultvoice/features/extraction/domain/device_tiering.dart';
import 'package:vaultvoice/features/licensing/data/licensing_providers.dart';
import 'package:vaultvoice/features/models/data/catalog_providers.dart';
import 'package:vaultvoice/features/pipeline/data/active_models_publisher.dart';
import 'package:vaultvoice/features/pipeline/data/production_engines.dart';
import 'package:vaultvoice/features/profiles/data/profile_providers.dart';
import 'package:vaultvoice/features/profiles/domain/builtin_profiles.dart';
import 'package:vaultvoice/features/templates/domain/builtin_templates.dart';
import 'package:vaultvoice/features/transcription/domain/stt_model_policy.dart';
import 'package:vv_native/vv_native.dart';

part 'engine_providers.g.dart';

/// Hardware facts for model selection (LLM-07); null when the bridge
/// cannot be loaded (selection then ignores the device tier).
@Riverpod(keepAlive: true)
DeviceProfile? deviceProfile(Ref ref) {
  try {
    final native = VvNative.open(
      hostPath: ref.watch(nativeLibraryPathProvider),
    );
    return NativeDeviceProfileProbe(
      native,
      NativeDeviceCapabilities(native),
    ).probe();
  } on Object {
    return null;
  }
}

/// The app's own vault folder (default/fallback target): Android
/// `filesDir/vault`, iOS `Documents/` (EXP-03/EXP-04 host APIs); elsewhere
/// `<storage root>/vault`.
@Riverpod(keepAlive: true)
Future<String> appLocalVaultRoot(Ref ref) async {
  if (Platform.isAndroid) return await SafHostApi().appLocalVaultPath();
  if (Platform.isIOS) return await BookmarkHostApi().appDocumentsPath();
  final paths = await ref.watch(storagePathsProvider.future);
  return p.join(paths.root, 'vault');
}

/// Everything the production worker factory needs, read on the UI isolate
/// before the worker starts (FND-11): built-in profile/template asset text,
/// the app-local vault root, the metrics file and the lifecycle state.
@Riverpod(keepAlive: true)
Future<ProductionEngineSpec> productionEngineSpec(Ref ref) async {
  final load = ref.watch(profileAssetLoaderProvider);
  final profiles = <String, String>{
    for (final asset in kBuiltinProfileAssets) asset: await load(asset),
  };
  final templates = <String, String>{
    for (final t in kBuiltinTemplates) t.assetPath: await load(t.assetPath),
  };
  return ProductionEngineSpec(
    profileSources: profiles,
    templateSources: templates,
    appLocalVaultRoot: await ref.watch(appLocalVaultRootProvider.future),
    metricsFile: ref.watch(appPathsProvider).metricsFile.path,
    platform: currentDevicePlatform(),
    appVersion: kAppVersion,
    nativeLibPath: ref.watch(nativeLibraryPathProvider),
    rootIsolateToken: RootIsolateToken.instance,
    foreground: _isForeground(),
  );
}

/// Publishes the active STT/LLM selection for the worker (FND-11).
@Riverpod(keepAlive: true)
ActiveModelsPublisher activeModelsPublisher(Ref ref) {
  final entitlements = ref.watch(entitlementServiceProvider);
  final catalogs = ref.watch(catalogRepositoryProvider);
  return ActiveModelsPublisher(
    settings: ref.watch(settingsRepositoryProvider),
    models: ref.watch(modelsRepositoryProvider),
    access: () => entitlements.access,
    accessChanges: entitlements.changes,
    catalog: () async =>
        catalogs.current ?? (await catalogs.loadBundled()).valueOrNull,
    device: () => ref.read(deviceProfileProvider),
    // STT-07: device-locale default language (PRODUCT-DECISION in
    // defaultSttLanguage) until a transcription-language setting exists.
    sttLanguage: () =>
        defaultSttLanguage(PlatformDispatcher.instance.locale.languageCode),
  );
}

/// Whether the app is visible now; unknown (no binding, headless) counts as
/// background, so the GPU is never used by mistake.
bool _isForeground() {
  try {
    return WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  } on Object {
    return false;
  }
}
