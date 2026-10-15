import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:vaultvoice/app.dart';
import 'package:vaultvoice/core/crash/crash_providers.dart';
import 'package:vaultvoice/core/crash/crash_reporting.dart';
import 'package:vaultvoice/core/crash/native_crash_capture.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/diagnostics/diagnostics_providers.dart';
import 'package:vaultvoice/core/errors/error_boundary.dart';
import 'package:vaultvoice/core/flavor.dart';
import 'package:vaultvoice/core/flavor_provider.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/licenses/bundled_licenses.dart';
import 'package:vaultvoice/core/logging/logger.dart';
import 'package:vaultvoice/core/logging/redaction.dart';
import 'package:vaultvoice/core/logging/rotating_file_sink.dart';
import 'package:vaultvoice/core/network/network_activity.dart';
import 'package:vaultvoice/core/platform/app_paths.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/core/security/key_vault.dart';
import 'package:vaultvoice/core/security/security_providers.dart';
import 'package:vaultvoice/core/security/storage_protection.dart';
import 'package:vaultvoice/features/extraction/data/preview_llm_engine.dart';
import 'package:vaultvoice/features/pipeline/data/flutter_local_notifier.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_providers.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_services_host.dart';
import 'package:vaultvoice/features/retention/presentation/retention_host.dart';
import 'package:vaultvoice/features/settings/data/share_plus_share_service.dart';
import 'package:vv_native/vv_native.dart';

/// Shared startup path for every flavor.
///
/// Real engine implementations are added to [overrides] by the features that
/// own them.
///
/// [productionLlm]: back `llmEngineProvider` with the active installed LLM
/// (PRF-07 profile preview, integration wave 3); the dev flavor passes false
/// when `VV_DEV_LLM_MODEL` supplies its own engine in [overrides].
Future<void> bootstrap(
  Flavor flavor, {
  List<Override> overrides = const [],
  bool productionLlm = true,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  registerBundledLicenses();
  final paths = await _resolvePaths();
  final sink = RotatingFileSink(paths.logs);
  final logger = Logger.forFlavor(
    flavor,
    sinks: [sink, if (kDebugMode) const DeveloperLogSink()],
  );
  // REL-02: harvest last run's native report, then arm the signal handler.
  const nativeCrash = VvNativeCrashCapture();
  final crash = CrashReporting.start(
    directory: paths.crashReports,
    native: nativeCrash,
    appBuild: CrashBuildInfo.describe(flavor),
    logger: logger,
  );
  installErrorBoundary(
    onError: (type) =>
        logger.error('app', 'uncaught error', fields: {'type': LogId(type)}),
    onCrash: crash.recordDart,
  );
  logger.info('app', 'app start', fields: {'flavor': flavor});
  // SEC-01: OS file protection + sqlite3mc key before anything opens the DB.
  final security = (Platform.isAndroid || Platform.isIOS)
      ? await prepareEncryptionAtRest(
          vault: const MethodChannelKeyVault(),
          protection: const MethodChannelStorageProtection(),
          storageRoot: (await StoragePaths.fromPlatform()).root,
          logger: logger,
        )
      : const <Override>[];
  runApp(
    ProviderScope(
      overrides: [
        flavorProvider.overrideWithValue(flavor),
        appPathsProvider.overrideWithValue(paths),
        logFileSinkProvider.overrideWithValue(sink),
        // SEC-02: every request (host, path, bytes) survives restarts.
        networkActivityLogProvider.overrideWithValue(
          NetworkActivityLog(
            file: File(
              '${paths.root.path}${Platform.pathSeparator}network'
              '${Platform.pathSeparator}activity.jsonl',
            ),
          ),
        ),
        loggerProvider.overrideWithValue(logger),
        nativeVersionsProvider.overrideWithValue(_nativeVersions()),
        shareServiceProvider.overrideWithValue(const SharePlusShareService()),
        if (Platform.isAndroid || Platform.isIOS)
          localNotificationsProvider.overrideWithValue(
            FlutterLocalNotifier(
              channelName: l10nFor(PlatformDispatcher.instance.locale)
                  .notificationChannelProcessing,
            ),
          ),
        crashReportStoreProvider.overrideWithValue(crash.store),
        nativeCrashCaptureProvider.overrideWithValue(nativeCrash),
        ...security,
        if (productionLlm)
          llmEngineProvider.overrideWith(
            (ref) => ref.watch(previewLlmEngineProvider),
          ),
        ...overrides,
      ],
      child: const ProcessingServicesHost(child: RetentionHost(child: App())),
    ),
  );
}

Future<AppPaths> _resolvePaths() async {
  try {
    return await AppPaths.resolve();
  } on Object {
    // Never fail startup over diagnostics storage: fall back to the OS temp
    // directory (still app-private on Android and iOS).
    final tmp = Directory.systemTemp.path;
    return AppPaths(
      root: Directory('$tmp${Platform.pathSeparator}vv'),
      temp: Directory('$tmp${Platform.pathSeparator}vv-tmp'),
    );
  }
}

/// Bridge versions for diagnostics; empty if the library cannot be loaded.
Map<String, String> _nativeVersions() {
  try {
    final native = VvNative.open();
    return {
      'bridge': native.version,
      'abi': '${native.abiVersion}',
      'whisper': native.whisperVersion,
      'ggml': native.ggmlVersion,
      'whisper_system': native.whisperSystemInfo,
      'llama_system': native.llamaSystemInfo,
    };
  } on Object {
    return const {'bridge': 'unavailable'};
  }
}
