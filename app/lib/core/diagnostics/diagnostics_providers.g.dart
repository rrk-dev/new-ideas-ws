// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diagnostics_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// App-private directories; `bootstrap` overrides it with resolved paths.

@ProviderFor(appPaths)
final appPathsProvider = AppPathsProvider._();

/// App-private directories; `bootstrap` overrides it with resolved paths.

final class AppPathsProvider
    extends $FunctionalProvider<AppPaths, AppPaths, AppPaths>
    with $Provider<AppPaths> {
  /// App-private directories; `bootstrap` overrides it with resolved paths.
  AppPathsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appPathsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appPathsHash();

  @$internal
  @override
  $ProviderElement<AppPaths> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppPaths create(Ref ref) {
    return appPaths(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppPaths value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppPaths>(value),
    );
  }
}

String _$appPathsHash() => r'41c691ca65a7ae8a5be553bd9deeacdd80f2efca';

/// The rotating log file sink; `bootstrap` overrides it with the instance
/// the [loggerProvider] writes to.

@ProviderFor(logFileSink)
final logFileSinkProvider = LogFileSinkProvider._();

/// The rotating log file sink; `bootstrap` overrides it with the instance
/// the [loggerProvider] writes to.

final class LogFileSinkProvider
    extends
        $FunctionalProvider<
          RotatingFileSink,
          RotatingFileSink,
          RotatingFileSink
        >
    with $Provider<RotatingFileSink> {
  /// The rotating log file sink; `bootstrap` overrides it with the instance
  /// the [loggerProvider] writes to.
  LogFileSinkProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'logFileSinkProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$logFileSinkHash();

  @$internal
  @override
  $ProviderElement<RotatingFileSink> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RotatingFileSink create(Ref ref) {
    return logFileSink(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RotatingFileSink value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RotatingFileSink>(value),
    );
  }
}

String _$logFileSinkHash() => r'412ee3be7b7b057b0e5c37d54a033af96b9ddfaa';

/// The app logger. Default (tests, before bootstrap): console in debug
/// builds, no file. `bootstrap` overrides it with the file-backed logger.

@ProviderFor(logger)
final loggerProvider = LoggerProvider._();

/// The app logger. Default (tests, before bootstrap): console in debug
/// builds, no file. `bootstrap` overrides it with the file-backed logger.

final class LoggerProvider extends $FunctionalProvider<Logger, Logger, Logger>
    with $Provider<Logger> {
  /// The app logger. Default (tests, before bootstrap): console in debug
  /// builds, no file. `bootstrap` overrides it with the file-backed logger.
  LoggerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'loggerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$loggerHash();

  @$internal
  @override
  $ProviderElement<Logger> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Logger create(Ref ref) {
    return logger(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Logger value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Logger>(value),
    );
  }
}

String _$loggerHash() => r'8f60faff238b95ae977aa25fc83269f1b68ad0ad';

@ProviderFor(metricsStore)
final metricsStoreProvider = MetricsStoreProvider._();

final class MetricsStoreProvider
    extends $FunctionalProvider<MetricsStore, MetricsStore, MetricsStore>
    with $Provider<MetricsStore> {
  MetricsStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'metricsStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$metricsStoreHash();

  @$internal
  @override
  $ProviderElement<MetricsStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MetricsStore create(Ref ref) {
    return metricsStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MetricsStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MetricsStore>(value),
    );
  }
}

String _$metricsStoreHash() => r'8016651bdd9bb506e592221b3a1bb099345bca36';

/// Measures per-job performance (RTF, tokens/s, peak RAM, battery, thermal).

@ProviderFor(jobMetricsRecorder)
final jobMetricsRecorderProvider = JobMetricsRecorderProvider._();

/// Measures per-job performance (RTF, tokens/s, peak RAM, battery, thermal).

final class JobMetricsRecorderProvider
    extends
        $FunctionalProvider<
          JobMetricsRecorder,
          JobMetricsRecorder,
          JobMetricsRecorder
        >
    with $Provider<JobMetricsRecorder> {
  /// Measures per-job performance (RTF, tokens/s, peak RAM, battery, thermal).
  JobMetricsRecorderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'jobMetricsRecorderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$jobMetricsRecorderHash();

  @$internal
  @override
  $ProviderElement<JobMetricsRecorder> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  JobMetricsRecorder create(Ref ref) {
    return jobMetricsRecorder(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(JobMetricsRecorder value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<JobMetricsRecorder>(value),
    );
  }
}

String _$jobMetricsRecorderHash() =>
    r'c4af74e47c9e098a2f46c975f3e6e16f7e5089f0';

/// Bridge versions for the diagnostics device info; `bootstrap` overrides
/// it with the values read from `vv_native` (empty when unavailable).

@ProviderFor(nativeVersions)
final nativeVersionsProvider = NativeVersionsProvider._();

/// Bridge versions for the diagnostics device info; `bootstrap` overrides
/// it with the values read from `vv_native` (empty when unavailable).

final class NativeVersionsProvider
    extends
        $FunctionalProvider<
          Map<String, String>,
          Map<String, String>,
          Map<String, String>
        >
    with $Provider<Map<String, String>> {
  /// Bridge versions for the diagnostics device info; `bootstrap` overrides
  /// it with the values read from `vv_native` (empty when unavailable).
  NativeVersionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nativeVersionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nativeVersionsHash();

  @$internal
  @override
  $ProviderElement<Map<String, String>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Map<String, String> create(Ref ref) {
    return nativeVersions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, String>>(value),
    );
  }
}

String _$nativeVersionsHash() => r'ff7ef52480603481744e0d7eb0e23033716fcecb';

/// OS share sheet; `bootstrap` overrides it with the share_plus adapter.

@ProviderFor(shareService)
final shareServiceProvider = ShareServiceProvider._();

/// OS share sheet; `bootstrap` overrides it with the share_plus adapter.

final class ShareServiceProvider
    extends $FunctionalProvider<ShareService, ShareService, ShareService>
    with $Provider<ShareService> {
  /// OS share sheet; `bootstrap` overrides it with the share_plus adapter.
  ShareServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shareServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shareServiceHash();

  @$internal
  @override
  $ProviderElement<ShareService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ShareService create(Ref ref) {
    return shareService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShareService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShareService>(value),
    );
  }
}

String _$shareServiceHash() => r'b9d6c594039936b64ba24aa4442b11b29f6bae80';

@ProviderFor(diagnosticsExporter)
final diagnosticsExporterProvider = DiagnosticsExporterProvider._();

final class DiagnosticsExporterProvider
    extends
        $FunctionalProvider<
          DiagnosticsExporter,
          DiagnosticsExporter,
          DiagnosticsExporter
        >
    with $Provider<DiagnosticsExporter> {
  DiagnosticsExporterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'diagnosticsExporterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$diagnosticsExporterHash();

  @$internal
  @override
  $ProviderElement<DiagnosticsExporter> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DiagnosticsExporter create(Ref ref) {
    return diagnosticsExporter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DiagnosticsExporter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DiagnosticsExporter>(value),
    );
  }
}

String _$diagnosticsExporterHash() =>
    r'a7673d1b309cb6f611e87e8c87ea9b7fe033ba53';
