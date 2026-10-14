// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'template_editor_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(templateStore)
final templateStoreProvider = TemplateStoreProvider._();

final class TemplateStoreProvider
    extends $FunctionalProvider<TemplateStore, TemplateStore, TemplateStore>
    with $Provider<TemplateStore> {
  TemplateStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'templateStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$templateStoreHash();

  @$internal
  @override
  $ProviderElement<TemplateStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TemplateStore create(Ref ref) {
    return templateStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TemplateStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TemplateStore>(value),
    );
  }
}

String _$templateStoreHash() => r'a4c17ba0bfb0f10307dc930751b3548a3fd3475b';

/// Custom templates, by id.

@ProviderFor(customTemplates)
final customTemplatesProvider = CustomTemplatesProvider._();

/// Custom templates, by id.

final class CustomTemplatesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CustomTemplate>>,
          List<CustomTemplate>,
          Stream<List<CustomTemplate>>
        >
    with
        $FutureModifier<List<CustomTemplate>>,
        $StreamProvider<List<CustomTemplate>> {
  /// Custom templates, by id.
  CustomTemplatesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'customTemplatesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$customTemplatesHash();

  @$internal
  @override
  $StreamProviderElement<List<CustomTemplate>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<CustomTemplate>> create(Ref ref) {
    return customTemplates(ref);
  }
}

String _$customTemplatesHash() => r'ab06513099d357d4f884ab2957133e65a4c4d2b8';

/// Profile id → bound custom template id.

@ProviderFor(templateBindings)
final templateBindingsProvider = TemplateBindingsProvider._();

/// Profile id → bound custom template id.

final class TemplateBindingsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, String>>,
          Map<String, String>,
          Stream<Map<String, String>>
        >
    with
        $FutureModifier<Map<String, String>>,
        $StreamProvider<Map<String, String>> {
  /// Profile id → bound custom template id.
  TemplateBindingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'templateBindingsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$templateBindingsHash();

  @$internal
  @override
  $StreamProviderElement<Map<String, String>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, String>> create(Ref ref) {
    return templateBindings(ref);
  }
}

String _$templateBindingsHash() => r'c867dcc0fc59bc33c9331597a98d5bc4b9e5808c';

/// Built-in template sources by id (read-only view, duplicate, reset).

@ProviderFor(builtinTemplateSources)
final builtinTemplateSourcesProvider = BuiltinTemplateSourcesProvider._();

/// Built-in template sources by id (read-only view, duplicate, reset).

final class BuiltinTemplateSourcesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, String>>,
          Map<String, String>,
          FutureOr<Map<String, String>>
        >
    with
        $FutureModifier<Map<String, String>>,
        $FutureProvider<Map<String, String>> {
  /// Built-in template sources by id (read-only view, duplicate, reset).
  BuiltinTemplateSourcesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'builtinTemplateSourcesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$builtinTemplateSourcesHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, String>> create(Ref ref) {
    return builtinTemplateSources(ref);
  }
}

String _$builtinTemplateSourcesHash() =>
    r'94035a7a2892b723074ae78093de2e5d90f3fedf';

/// Profiles a template can be written for: built-ins plus valid user /
/// enterprise profiles from the database.

@ProviderFor(editorProfiles)
final editorProfilesProvider = EditorProfilesProvider._();

/// Profiles a template can be written for: built-ins plus valid user /
/// enterprise profiles from the database.

final class EditorProfilesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Profile>>,
          List<Profile>,
          FutureOr<List<Profile>>
        >
    with $FutureModifier<List<Profile>>, $FutureProvider<List<Profile>> {
  /// Profiles a template can be written for: built-ins plus valid user /
  /// enterprise profiles from the database.
  EditorProfilesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'editorProfilesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$editorProfilesHash();

  @$internal
  @override
  $FutureProviderElement<List<Profile>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Profile>> create(Ref ref) {
    return editorProfiles(ref);
  }
}

String _$editorProfilesHash() => r'19d134727aeee2991e1c61dc2e55b10727487b1a';

/// The latest valid extractions of [profileId] (newest first, ≤ 10).

@ProviderFor(previewRecordings)
final previewRecordingsProvider = PreviewRecordingsFamily._();

/// The latest valid extractions of [profileId] (newest first, ≤ 10).

final class PreviewRecordingsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<PreviewRecording>>,
          List<PreviewRecording>,
          FutureOr<List<PreviewRecording>>
        >
    with
        $FutureModifier<List<PreviewRecording>>,
        $FutureProvider<List<PreviewRecording>> {
  /// The latest valid extractions of [profileId] (newest first, ≤ 10).
  PreviewRecordingsProvider._({
    required PreviewRecordingsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'previewRecordingsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$previewRecordingsHash();

  @override
  String toString() {
    return r'previewRecordingsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<PreviewRecording>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<PreviewRecording>> create(Ref ref) {
    final argument = this.argument as String;
    return previewRecordings(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PreviewRecordingsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$previewRecordingsHash() => r'c84ebb046832117f80ee5337fc0170cc0db5150e';

/// The latest valid extractions of [profileId] (newest first, ≤ 10).

final class PreviewRecordingsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<PreviewRecording>>, String> {
  PreviewRecordingsFamily._()
    : super(
        retry: null,
        name: r'previewRecordingsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The latest valid extractions of [profileId] (newest first, ≤ 10).

  PreviewRecordingsProvider call(String profileId) =>
      PreviewRecordingsProvider._(argument: profileId, from: this);

  @override
  String toString() => r'previewRecordingsProvider';
}
