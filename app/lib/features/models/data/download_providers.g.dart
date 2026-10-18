// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(modelDownloadPlatform)
final modelDownloadPlatformProvider = ModelDownloadPlatformProvider._();

final class ModelDownloadPlatformProvider
    extends
        $FunctionalProvider<
          MethodChannelDownloadPlatform,
          MethodChannelDownloadPlatform,
          MethodChannelDownloadPlatform
        >
    with $Provider<MethodChannelDownloadPlatform> {
  ModelDownloadPlatformProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'modelDownloadPlatformProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$modelDownloadPlatformHash();

  @$internal
  @override
  $ProviderElement<MethodChannelDownloadPlatform> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MethodChannelDownloadPlatform create(Ref ref) {
    return modelDownloadPlatform(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MethodChannelDownloadPlatform value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MethodChannelDownloadPlatform>(
        value,
      ),
    );
  }
}

String _$modelDownloadPlatformHash() =>
    r'8d441a90cf3ba2f8ac0f47efe418f8abd2913352';

/// iOS: background download session (survives suspension/termination).
/// Android / host: in-process gateway stream kept alive by a `dataSync`
/// foreground service (ADR-MDL-02).

@ProviderFor(modelDownloadTransport)
final modelDownloadTransportProvider = ModelDownloadTransportProvider._();

/// iOS: background download session (survives suspension/termination).
/// Android / host: in-process gateway stream kept alive by a `dataSync`
/// foreground service (ADR-MDL-02).

final class ModelDownloadTransportProvider
    extends
        $FunctionalProvider<
          DownloadTransport,
          DownloadTransport,
          DownloadTransport
        >
    with $Provider<DownloadTransport> {
  /// iOS: background download session (survives suspension/termination).
  /// Android / host: in-process gateway stream kept alive by a `dataSync`
  /// foreground service (ADR-MDL-02).
  ModelDownloadTransportProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'modelDownloadTransportProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$modelDownloadTransportHash();

  @$internal
  @override
  $ProviderElement<DownloadTransport> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DownloadTransport create(Ref ref) {
    return modelDownloadTransport(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DownloadTransport value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DownloadTransport>(value),
    );
  }
}

String _$modelDownloadTransportHash() =>
    r'e4a3fe4ea183382a62f28b094cd7509b8d609393';

@ProviderFor(modelDownloader)
final modelDownloaderProvider = ModelDownloaderProvider._();

final class ModelDownloaderProvider
    extends
        $FunctionalProvider<
          AsyncValue<ModelDownloader>,
          ModelDownloader,
          FutureOr<ModelDownloader>
        >
    with $FutureModifier<ModelDownloader>, $FutureProvider<ModelDownloader> {
  ModelDownloaderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'modelDownloaderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$modelDownloaderHash();

  @$internal
  @override
  $FutureProviderElement<ModelDownloader> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ModelDownloader> create(Ref ref) {
    return modelDownloader(ref);
  }
}

String _$modelDownloaderHash() => r'24b48d96463427c2cf59ca7132bd118ee3c45d02';

/// Resumes downloads interrupted by an app kill (MDL-02/AC1). Watched once
/// at app start; returns the resumed model ids (empty on any error — never
/// blocks startup).

@ProviderFor(resumeModelDownloads)
final resumeModelDownloadsProvider = ResumeModelDownloadsProvider._();

/// Resumes downloads interrupted by an app kill (MDL-02/AC1). Watched once
/// at app start; returns the resumed model ids (empty on any error — never
/// blocks startup).

final class ResumeModelDownloadsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<String>>,
          List<String>,
          FutureOr<List<String>>
        >
    with $FutureModifier<List<String>>, $FutureProvider<List<String>> {
  /// Resumes downloads interrupted by an app kill (MDL-02/AC1). Watched once
  /// at app start; returns the resumed model ids (empty on any error — never
  /// blocks startup).
  ResumeModelDownloadsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'resumeModelDownloadsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$resumeModelDownloadsHash();

  @$internal
  @override
  $FutureProviderElement<List<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<String>> create(Ref ref) {
    return resumeModelDownloads(ref);
  }
}

String _$resumeModelDownloadsHash() =>
    r'0964c5634cd68823050d31d280f5f37a3849d863';
