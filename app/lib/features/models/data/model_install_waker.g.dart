// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_install_waker.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(modelInstallWaker)
final modelInstallWakerProvider = ModelInstallWakerProvider._();

final class ModelInstallWakerProvider
    extends
        $FunctionalProvider<
          ModelInstallWaker,
          ModelInstallWaker,
          ModelInstallWaker
        >
    with $Provider<ModelInstallWaker> {
  ModelInstallWakerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'modelInstallWakerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$modelInstallWakerHash();

  @$internal
  @override
  $ProviderElement<ModelInstallWaker> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ModelInstallWaker create(Ref ref) {
    return modelInstallWaker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ModelInstallWaker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ModelInstallWaker>(value),
    );
  }
}

String _$modelInstallWakerHash() => r'918103904736c708fbd5023c13fbd6037148714d';
