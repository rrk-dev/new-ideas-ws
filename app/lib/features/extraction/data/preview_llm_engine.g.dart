// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'preview_llm_engine.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Production `llmEngineProvider` override (see `bootstrap`).

@ProviderFor(previewLlmEngine)
final previewLlmEngineProvider = PreviewLlmEngineProvider._();

/// Production `llmEngineProvider` override (see `bootstrap`).

final class PreviewLlmEngineProvider
    extends $FunctionalProvider<LlmEngine, LlmEngine, LlmEngine>
    with $Provider<LlmEngine> {
  /// Production `llmEngineProvider` override (see `bootstrap`).
  PreviewLlmEngineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'previewLlmEngineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$previewLlmEngineHash();

  @$internal
  @override
  $ProviderElement<LlmEngine> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LlmEngine create(Ref ref) {
    return previewLlmEngine(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LlmEngine value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LlmEngine>(value),
    );
  }
}

String _$previewLlmEngineHash() => r'6e03da4df3ac74d23b27e0a8f45733dc7d366a0a';
