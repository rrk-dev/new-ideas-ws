// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Schema → GBNF converter: the native-bridge implementation
/// (`vv_json_schema_to_gbnf`, LLM-05; wired as the default in FND-11);
/// tests use `FakeSchemaGrammarConverter`.

@ProviderFor(schemaGrammarConverter)
final schemaGrammarConverterProvider = SchemaGrammarConverterProvider._();

/// Schema → GBNF converter: the native-bridge implementation
/// (`vv_json_schema_to_gbnf`, LLM-05; wired as the default in FND-11);
/// tests use `FakeSchemaGrammarConverter`.

final class SchemaGrammarConverterProvider
    extends
        $FunctionalProvider<
          SchemaGrammarConverter,
          SchemaGrammarConverter,
          SchemaGrammarConverter
        >
    with $Provider<SchemaGrammarConverter> {
  /// Schema → GBNF converter: the native-bridge implementation
  /// (`vv_json_schema_to_gbnf`, LLM-05; wired as the default in FND-11);
  /// tests use `FakeSchemaGrammarConverter`.
  SchemaGrammarConverterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'schemaGrammarConverterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$schemaGrammarConverterHash();

  @$internal
  @override
  $ProviderElement<SchemaGrammarConverter> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SchemaGrammarConverter create(Ref ref) {
    return schemaGrammarConverter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SchemaGrammarConverter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SchemaGrammarConverter>(value),
    );
  }
}

String _$schemaGrammarConverterHash() =>
    r'6609593cc48879697d9d059f7e87faa63e32f383';

/// Asset loader; tests override it to read from disk or memory.

@ProviderFor(profileAssetLoader)
final profileAssetLoaderProvider = ProfileAssetLoaderProvider._();

/// Asset loader; tests override it to read from disk or memory.

final class ProfileAssetLoaderProvider
    extends
        $FunctionalProvider<
          Future<String> Function(String key),
          Future<String> Function(String key),
          Future<String> Function(String key)
        >
    with $Provider<Future<String> Function(String key)> {
  /// Asset loader; tests override it to read from disk or memory.
  ProfileAssetLoaderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileAssetLoaderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileAssetLoaderHash();

  @$internal
  @override
  $ProviderElement<Future<String> Function(String key)> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Future<String> Function(String key) create(Ref ref) {
    return profileAssetLoader(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Future<String> Function(String key) value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Future<String> Function(String key)>(
        value,
      ),
    );
  }
}

String _$profileAssetLoaderHash() =>
    r'078ad18dad45514739e0b607c4f707d3dec73bf6';

/// Built-in profiles, parsed from assets once per launch.

@ProviderFor(builtinProfiles)
final builtinProfilesProvider = BuiltinProfilesProvider._();

/// Built-in profiles, parsed from assets once per launch.

final class BuiltinProfilesProvider
    extends
        $FunctionalProvider<
          AsyncValue<BuiltinProfiles>,
          BuiltinProfiles,
          FutureOr<BuiltinProfiles>
        >
    with $FutureModifier<BuiltinProfiles>, $FutureProvider<BuiltinProfiles> {
  /// Built-in profiles, parsed from assets once per launch.
  BuiltinProfilesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'builtinProfilesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$builtinProfilesHash();

  @$internal
  @override
  $FutureProviderElement<BuiltinProfiles> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BuiltinProfiles> create(Ref ref) {
    return builtinProfiles(ref);
  }
}

String _$builtinProfilesHash() => r'362d3039ac50ed0282aab72fb1aa9da66e56f34e';

@ProviderFor(profileRegistry)
final profileRegistryProvider = ProfileRegistryProvider._();

final class ProfileRegistryProvider
    extends
        $FunctionalProvider<
          AsyncValue<ProfileRegistry>,
          ProfileRegistry,
          FutureOr<ProfileRegistry>
        >
    with $FutureModifier<ProfileRegistry>, $FutureProvider<ProfileRegistry> {
  ProfileRegistryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileRegistryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileRegistryHash();

  @$internal
  @override
  $FutureProviderElement<ProfileRegistry> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ProfileRegistry> create(Ref ref) {
    return profileRegistry(ref);
  }
}

String _$profileRegistryHash() => r'd2b41651e589f8b5cedca9b7827de1159dc53043';

/// PRF-02 extraction prompts for a profile — the seam the extract step
/// (FND-11) and the map-reduce strategy (LLM-06) call for single-pass and
/// per-chunk prompts. The exact-budget chat-message path is
/// `PromptBuilder(SessionPromptTokenizer(session)).build(...)`.

@ProviderFor(extractionPrompts)
final extractionPromptsProvider = ExtractionPromptsProvider._();

/// PRF-02 extraction prompts for a profile — the seam the extract step
/// (FND-11) and the map-reduce strategy (LLM-06) call for single-pass and
/// per-chunk prompts. The exact-budget chat-message path is
/// `PromptBuilder(SessionPromptTokenizer(session)).build(...)`.

final class ExtractionPromptsProvider
    extends
        $FunctionalProvider<
          ExtractionPromptsFactory,
          ExtractionPromptsFactory,
          ExtractionPromptsFactory
        >
    with $Provider<ExtractionPromptsFactory> {
  /// PRF-02 extraction prompts for a profile — the seam the extract step
  /// (FND-11) and the map-reduce strategy (LLM-06) call for single-pass and
  /// per-chunk prompts. The exact-budget chat-message path is
  /// `PromptBuilder(SessionPromptTokenizer(session)).build(...)`.
  ExtractionPromptsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'extractionPromptsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$extractionPromptsHash();

  @$internal
  @override
  $ProviderElement<ExtractionPromptsFactory> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ExtractionPromptsFactory create(Ref ref) {
    return extractionPrompts(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ExtractionPromptsFactory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ExtractionPromptsFactory>(value),
    );
  }
}

String _$extractionPromptsHash() => r'df4b3fd5658ab4b3cc5bfe18823db06d6822aecc';
