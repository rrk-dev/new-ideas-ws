// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'crash_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Crash report files; `bootstrap` overrides it with the store that
/// harvested this launch's reports.

@ProviderFor(crashReportStore)
final crashReportStoreProvider = CrashReportStoreProvider._();

/// Crash report files; `bootstrap` overrides it with the store that
/// harvested this launch's reports.

final class CrashReportStoreProvider
    extends
        $FunctionalProvider<
          CrashReportStore,
          CrashReportStore,
          CrashReportStore
        >
    with $Provider<CrashReportStore> {
  /// Crash report files; `bootstrap` overrides it with the store that
  /// harvested this launch's reports.
  CrashReportStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'crashReportStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$crashReportStoreHash();

  @$internal
  @override
  $ProviderElement<CrashReportStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CrashReportStore create(Ref ref) {
    return crashReportStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CrashReportStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CrashReportStore>(value),
    );
  }
}

String _$crashReportStoreHash() => r'a44a06d7dfdffc160d6156c248460b331048ed1c';

/// Native handler access (dev-only forced crash). `bootstrap` overrides it
/// with the FFI implementation.

@ProviderFor(nativeCrashCapture)
final nativeCrashCaptureProvider = NativeCrashCaptureProvider._();

/// Native handler access (dev-only forced crash). `bootstrap` overrides it
/// with the FFI implementation.

final class NativeCrashCaptureProvider
    extends
        $FunctionalProvider<
          NativeCrashCapture,
          NativeCrashCapture,
          NativeCrashCapture
        >
    with $Provider<NativeCrashCapture> {
  /// Native handler access (dev-only forced crash). `bootstrap` overrides it
  /// with the FFI implementation.
  NativeCrashCaptureProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nativeCrashCaptureProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nativeCrashCaptureHash();

  @$internal
  @override
  $ProviderElement<NativeCrashCapture> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NativeCrashCapture create(Ref ref) {
    return nativeCrashCapture(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NativeCrashCapture value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NativeCrashCapture>(value),
    );
  }
}

String _$nativeCrashCaptureHash() =>
    r'647ce1c66b8ec3afcc158c1e618552d845b4c908';

/// Stored crash reports (newest first) and the user's actions on them:
/// review → share via the OS sheet, or discard. No upload endpoint exists.

@ProviderFor(CrashReports)
final crashReportsProvider = CrashReportsProvider._();

/// Stored crash reports (newest first) and the user's actions on them:
/// review → share via the OS sheet, or discard. No upload endpoint exists.
final class CrashReportsProvider
    extends $NotifierProvider<CrashReports, List<CrashReport>> {
  /// Stored crash reports (newest first) and the user's actions on them:
  /// review → share via the OS sheet, or discard. No upload endpoint exists.
  CrashReportsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'crashReportsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$crashReportsHash();

  @$internal
  @override
  CrashReports create() => CrashReports();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<CrashReport> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<CrashReport>>(value),
    );
  }
}

String _$crashReportsHash() => r'f565aef90a93f0159b0bcf041d321a0b5e8892c3';

/// Stored crash reports (newest first) and the user's actions on them:
/// review → share via the OS sheet, or discard. No upload endpoint exists.

abstract class _$CrashReports extends $Notifier<List<CrashReport>> {
  List<CrashReport> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<CrashReport>, List<CrashReport>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<CrashReport>, List<CrashReport>>,
              List<CrashReport>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
