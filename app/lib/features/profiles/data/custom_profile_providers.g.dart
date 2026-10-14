// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'custom_profile_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every profile for the Profiles tab: built-ins (assets) then stored
/// user/enterprise profiles (rows that no longer validate are skipped).
/// Needs no grammar converter, so it works before LLM-05 is wired.

@ProviderFor(profileList)
final profileListProvider = ProfileListProvider._();

/// Every profile for the Profiles tab: built-ins (assets) then stored
/// user/enterprise profiles (rows that no longer validate are skipped).
/// Needs no grammar converter, so it works before LLM-05 is wired.

final class ProfileListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Profile>>,
          List<Profile>,
          Stream<List<Profile>>
        >
    with $FutureModifier<List<Profile>>, $StreamProvider<List<Profile>> {
  /// Every profile for the Profiles tab: built-ins (assets) then stored
  /// user/enterprise profiles (rows that no longer validate are skipped).
  /// Needs no grammar converter, so it works before LLM-05 is wired.
  ProfileListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileListHash();

  @$internal
  @override
  $StreamProviderElement<List<Profile>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Profile>> create(Ref ref) {
    return profileList(ref);
  }
}

String _$profileListHash() => r'a4c55d651b85e0d22a10974f659f52bd65f1e57c';

/// One profile by id (editor).

@ProviderFor(profileById)
final profileByIdProvider = ProfileByIdFamily._();

/// One profile by id (editor).

final class ProfileByIdProvider
    extends
        $FunctionalProvider<AsyncValue<Profile?>, Profile?, FutureOr<Profile?>>
    with $FutureModifier<Profile?>, $FutureProvider<Profile?> {
  /// One profile by id (editor).
  ProfileByIdProvider._({
    required ProfileByIdFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'profileByIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$profileByIdHash();

  @override
  String toString() {
    return r'profileByIdProvider'
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
    return profileById(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ProfileByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$profileByIdHash() => r'140aa4b2b2d71a22c0b6ca022e5e6aad20bf85eb';

/// One profile by id (editor).

final class ProfileByIdFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Profile?>, String> {
  ProfileByIdFamily._()
    : super(
        retry: null,
        name: r'profileByIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One profile by id (editor).

  ProfileByIdProvider call(String id) =>
      ProfileByIdProvider._(argument: id, from: this);

  @override
  String toString() => r'profileByIdProvider';
}

/// Whether custom profiles can be created / edited (LIC-01).

@ProviderFor(canEditProfiles)
final canEditProfilesProvider = CanEditProfilesProvider._();

/// Whether custom profiles can be created / edited (LIC-01).

final class CanEditProfilesProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether custom profiles can be created / edited (LIC-01).
  CanEditProfilesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'canEditProfilesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$canEditProfilesHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return canEditProfiles(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$canEditProfilesHash() => r'd9c20168e1ee970e003fda2fca0fa76ae9cb2e1a';

@ProviderFor(customProfileService)
final customProfileServiceProvider = CustomProfileServiceProvider._();

final class CustomProfileServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<CustomProfileService>,
          CustomProfileService,
          FutureOr<CustomProfileService>
        >
    with
        $FutureModifier<CustomProfileService>,
        $FutureProvider<CustomProfileService> {
  CustomProfileServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'customProfileServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$customProfileServiceHash();

  @$internal
  @override
  $FutureProviderElement<CustomProfileService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CustomProfileService> create(Ref ref) {
    return customProfileService(ref);
  }
}

String _$customProfileServiceHash() =>
    r'cdfdfd00ed40e36dcb81ae1cc06f2c25e261b4fd';

@ProviderFor(profilePreview)
final profilePreviewProvider = ProfilePreviewProvider._();

final class ProfilePreviewProvider
    extends
        $FunctionalProvider<
          AsyncValue<ProfilePreview>,
          ProfilePreview,
          FutureOr<ProfilePreview>
        >
    with $FutureModifier<ProfilePreview>, $FutureProvider<ProfilePreview> {
  ProfilePreviewProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profilePreviewProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profilePreviewHash();

  @$internal
  @override
  $FutureProviderElement<ProfilePreview> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ProfilePreview> create(Ref ref) {
    return profilePreview(ref);
  }
}

String _$profilePreviewHash() => r'e500f3da0825278bf9006be09e97674d8197b391';

/// Recordings that can be used for "Test on a recording".

@ProviderFor(previewRecordings)
final previewRecordingsProvider = PreviewRecordingsProvider._();

/// Recordings that can be used for "Test on a recording".

final class PreviewRecordingsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<PreviewRecording>>,
          List<PreviewRecording>,
          Stream<List<PreviewRecording>>
        >
    with
        $FutureModifier<List<PreviewRecording>>,
        $StreamProvider<List<PreviewRecording>> {
  /// Recordings that can be used for "Test on a recording".
  PreviewRecordingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'previewRecordingsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$previewRecordingsHash();

  @$internal
  @override
  $StreamProviderElement<List<PreviewRecording>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<PreviewRecording>> create(Ref ref) {
    return previewRecordings(ref);
  }
}

String _$previewRecordingsHash() => r'b82d87323f76243d94fa0262220ddadefb1ec64e';

/// The latest transcript of [recordingId] as prompt input (empty when none).

@ProviderFor(previewInput)
final previewInputProvider = PreviewInputFamily._();

/// The latest transcript of [recordingId] as prompt input (empty when none).

final class PreviewInputProvider
    extends
        $FunctionalProvider<
          AsyncValue<PromptInputParts>,
          PromptInputParts,
          FutureOr<PromptInputParts>
        >
    with $FutureModifier<PromptInputParts>, $FutureProvider<PromptInputParts> {
  /// The latest transcript of [recordingId] as prompt input (empty when none).
  PreviewInputProvider._({
    required PreviewInputFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'previewInputProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$previewInputHash();

  @override
  String toString() {
    return r'previewInputProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<PromptInputParts> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PromptInputParts> create(Ref ref) {
    final argument = this.argument as String;
    return previewInput(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PreviewInputProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$previewInputHash() => r'97b6e36d99c0a435821bb70ee8b7a525aff5a3e5';

/// The latest transcript of [recordingId] as prompt input (empty when none).

final class PreviewInputFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<PromptInputParts>, String> {
  PreviewInputFamily._()
    : super(
        retry: null,
        name: r'previewInputProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The latest transcript of [recordingId] as prompt input (empty when none).

  PreviewInputProvider call(String recordingId) =>
      PreviewInputProvider._(argument: recordingId, from: this);

  @override
  String toString() => r'previewInputProvider';
}
