import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:vaultvoice/app.dart';
import 'package:vaultvoice/core/crash/crash_providers.dart';
import 'package:vaultvoice/core/crash/crash_reporting.dart';
import 'package:vaultvoice/core/crash/native_crash_capture.dart';
import 'package:vaultvoice/core/diagnostics/diagnostics_providers.dart';
import 'package:vaultvoice/core/errors/error_boundary.dart';
import 'package:vaultvoice/core/flavor.dart';
import 'package:vaultvoice/core/flavor_provider.dart';
import 'package:vaultvoice/core/logging/logger.dart';
import 'package:vaultvoice/core/logging/redaction.dart';
import 'package:vaultvoice/core/logging/rotating_file_sink.dart';
import 'package:vaultvoice/core/platform/app_paths.dart';
import 'package:vaultvoice/features/settings/data/share_plus_share_service.dart';
import 'package:vv_native/vv_native.dart';

/// Shared startup path for every flavor.
///
/// Real engine implementations are added to [overrides] by the features that
/// own them.
Future<void> bootstrap(
  Flavor flavor, {
  List<Override> overrides = const [],
}) async {
  WidgetsFlutterBinding.ensureInitialized();
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
  runApp(
    ProviderScope(
      overrides: [
        flavorProvider.overrideWithValue(flavor),
        appPathsProvider.overrideWithValue(paths),
        logFileSinkProvider.overrideWithValue(sink),
        loggerProvider.overrideWithValue(logger),
        nativeVersionsProvider.overrideWithValue(_nativeVersions()),
        shareServiceProvider.overrideWithValue(const SharePlusShareService()),
        crashReportStoreProvider.overrideWithValue(crash.store),
        nativeCrashCaptureProvider.overrideWithValue(nativeCrash),
        ...overrides,
      ],
      child: const App(),
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
