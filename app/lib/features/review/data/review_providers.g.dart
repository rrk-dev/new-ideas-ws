// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every profile (built-in + user) for the review settings and the form.

@ProviderFor(reviewProfiles)
final reviewProfilesProvider = ReviewProfilesProvider._();

/// Every profile (built-in + user) for the review settings and the form.

final class ReviewProfilesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Profile>>,
          List<Profile>,
          Stream<List<Profile>>
        >
    with $FutureModifier<List<Profile>>, $StreamProvider<List<Profile>> {
  /// Every profile (built-in + user) for the review settings and the form.
  ReviewProfilesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reviewProfilesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reviewProfilesHash();

  @$internal
  @override
  $StreamProviderElement<List<Profile>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Profile>> create(Ref ref) {
    return reviewProfiles(ref);
  }
}

String _$reviewProfilesHash() => r'65425cf51197476dbd55b60ba77546faac126064';

/// One profile by id, or null when it no longer exists.

@ProviderFor(reviewProfile)
final reviewProfileProvider = ReviewProfileFamily._();

/// One profile by id, or null when it no longer exists.

final class ReviewProfileProvider
    extends
        $FunctionalProvider<AsyncValue<Profile?>, Profile?, FutureOr<Profile?>>
    with $FutureModifier<Profile?>, $FutureProvider<Profile?> {
  /// One profile by id, or null when it no longer exists.
  ReviewProfileProvider._({
    required ReviewProfileFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'reviewProfileProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$reviewProfileHash();

  @override
  String toString() {
    return r'reviewProfileProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Profile?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Profile?> create(Ref ref) {
    final argument = this.argument as String;
    return reviewProfile(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ReviewProfileProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$reviewProfileHash() => r'6657fbb8cfe322ca5798b72abb8692a5882c36e9';

/// One profile by id, or null when it no longer exists.

final class ReviewProfileFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Profile?>, String> {
  ReviewProfileFamily._()
    : super(
        retry: null,
        name: r'reviewProfileProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One profile by id, or null when it no longer exists.

  ReviewProfileProvider call(String profileId) =>
      ReviewProfileProvider._(argument: profileId, from: this);

  @override
  String toString() => r'reviewProfileProvider';
}

/// Whether [profileId]'s results are reviewed before export.

@ProviderFor(reviewMode)
final reviewModeProvider = ReviewModeFamily._();

/// Whether [profileId]'s results are reviewed before export.

final class ReviewModeProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Whether [profileId]'s results are reviewed before export.
  ReviewModeProvider._({
    required ReviewModeFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'reviewModeProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$reviewModeHash();

  @override
  String toString() {
    return r'reviewModeProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    final argument = this.argument as String;
    return reviewMode(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ReviewModeProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$reviewModeHash() => r'42ac5eb8beb111eeb5ed624a0170539df94013fb';

/// Whether [profileId]'s results are reviewed before export.

final class ReviewModeFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, String> {
  ReviewModeFamily._()
    : super(
        retry: null,
        name: r'reviewModeProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Whether [profileId]'s results are reviewed before export.

  ReviewModeProvider call(String profileId) =>
      ReviewModeProvider._(argument: profileId, from: this);

  @override
  String toString() => r'reviewModeProvider';
}

/// Built-in Markdown templates (EXP-01 assets) for the preview.

@ProviderFor(builtinTemplates)
final builtinTemplatesProvider = BuiltinTemplatesProvider._();

/// Built-in Markdown templates (EXP-01 assets) for the preview.

final class BuiltinTemplatesProvider
    extends
        $FunctionalProvider<
          AsyncValue<BuiltinTemplates>,
          BuiltinTemplates,
          FutureOr<BuiltinTemplates>
        >
    with $FutureModifier<BuiltinTemplates>, $FutureProvider<BuiltinTemplates> {
  /// Built-in Markdown templates (EXP-01 assets) for the preview.
  BuiltinTemplatesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'builtinTemplatesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$builtinTemplatesHash();

  @$internal
  @override
  $FutureProviderElement<BuiltinTemplates> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BuiltinTemplates> create(Ref ref) {
    return builtinTemplates(ref);
  }
}

String _$builtinTemplatesHash() => r'5a66e775f45f16ab2a61bb38cc65e8abbb6ecba5';

/// The note renderer used for the review preview — the same EXP-01
/// renderer the pipeline's RenderStep uses.

@ProviderFor(previewRenderer)
final previewRendererProvider = PreviewRendererProvider._();

/// The note renderer used for the review preview — the same EXP-01
/// renderer the pipeline's RenderStep uses.

final class PreviewRendererProvider
    extends
        $FunctionalProvider<
          AsyncValue<NoteRenderer>,
          NoteRenderer,
          FutureOr<NoteRenderer>
        >
    with $FutureModifier<NoteRenderer>, $FutureProvider<NoteRenderer> {
  /// The note renderer used for the review preview — the same EXP-01
  /// renderer the pipeline's RenderStep uses.
  PreviewRendererProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'previewRendererProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$previewRendererHash();

  @$internal
  @override
  $FutureProviderElement<NoteRenderer> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<NoteRenderer> create(Ref ref) {
    return previewRenderer(ref);
  }
}

String _$previewRendererHash() => r'12d517af1127eb1f499f4f807aba42abacf3afa2';

@ProviderFor(reviewService)
final reviewServiceProvider = ReviewServiceProvider._();

final class ReviewServiceProvider
    extends $FunctionalProvider<ReviewService, ReviewService, ReviewService>
    with $Provider<ReviewService> {
  ReviewServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reviewServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reviewServiceHash();

  @$internal
  @override
  $ProviderElement<ReviewService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ReviewService create(Ref ref) {
    return reviewService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReviewService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReviewService>(value),
    );
  }
}

String _$reviewServiceHash() => r'd2680aeb1aa33d6c8b7489ca41ad2cbe5f795ea0';
