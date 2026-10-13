import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/diagnostics/diagnostics_bundle.dart';
import 'package:vaultvoice/core/diagnostics/diagnostics_exporter.dart';
import 'package:vaultvoice/core/diagnostics/job_metrics.dart';
import 'package:vaultvoice/core/flavor_provider.dart';
import 'package:vaultvoice/core/logging/logger.dart';
import 'package:vaultvoice/core/logging/rotating_file_sink.dart';
import 'package:vaultvoice/core/platform/app_paths.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/core/platform/share_service.dart';

part 'diagnostics_providers.g.dart';

/// App-private directories; `bootstrap` overrides it with resolved paths.
@Riverpod(keepAlive: true)
AppPaths appPaths(Ref ref) =>
    throw UnimplementedError('appPathsProvider must be overridden');

/// The rotating log file sink; `bootstrap` overrides it with the instance
/// the [loggerProvider] writes to.
@Riverpod(keepAlive: true)
RotatingFileSink logFileSink(Ref ref) =>
    RotatingFileSink(ref.watch(appPathsProvider).logs);

/// The app logger. Default (tests, before bootstrap): console in debug
/// builds, no file. `bootstrap` overrides it with the file-backed logger.
@Riverpod(keepAlive: true)
Logger logger(Ref ref) => Logger(
  sinks: [if (kDebugMode) const DeveloperLogSink()],
  clock: ref.watch(clockProvider),
);

@Riverpod(keepAlive: true)
MetricsStore metricsStore(Ref ref) =>
    JsonlMetricsStore(ref.watch(appPathsProvider).metricsFile);

/// Measures per-job performance (RTF, tokens/s, peak RAM, battery, thermal).
@Riverpod(keepAlive: true)
JobMetricsRecorder jobMetricsRecorder(Ref ref) => JobMetricsRecorder(
  store: ref.watch(metricsStoreProvider),
  clock: ref.watch(clockProvider),
);

/// Bridge versions for the diagnostics device info; `bootstrap` overrides
/// it with the values read from `vv_native` (empty when unavailable).
@Riverpod(keepAlive: true)
Map<String, String> nativeVersions(Ref ref) => const {};

/// OS share sheet; `bootstrap` overrides it with the share_plus adapter.
@Riverpod(keepAlive: true)
ShareService shareService(Ref ref) =>
    throw UnimplementedError('shareServiceProvider must be overridden');

@Riverpod(keepAlive: true)
DiagnosticsExporter diagnosticsExporter(Ref ref) {
  final paths = ref.watch(appPathsProvider);
  final sink = ref.watch(logFileSinkProvider);
  final flavor = ref.watch(flavorProvider);
  final native = ref.watch(nativeVersionsProvider);
  return DiagnosticsExporter(
    builder: DiagnosticsBundleBuilder(
      logFiles: () => sink.files,
      metrics: ref.watch(metricsStoreProvider),
      deviceInfo: () =>
          DeviceInfo.current(flavor: flavor, nativeVersions: native),
      clock: ref.watch(clockProvider),
    ),
    shareService: ref.watch(shareServiceProvider),
    exportDirectory: paths.diagnosticsExport,
    logger: ref.watch(loggerProvider),
  );
}
