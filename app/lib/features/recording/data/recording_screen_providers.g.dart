// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recording_screen_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The open recording (id + recorded time) for markers and the details
/// sheet; null when the capture backend does not expose it (test fakes).

@ProviderFor(activeRecording)
final activeRecordingProvider = ActiveRecordingProvider._();

/// The open recording (id + recorded time) for markers and the details
/// sheet; null when the capture backend does not expose it (test fakes).

final class ActiveRecordingProvider
    extends
        $FunctionalProvider<
          ActiveRecording?,
          ActiveRecording?,
          ActiveRecording?
        >
    with $Provider<ActiveRecording?> {
  /// The open recording (id + recorded time) for markers and the details
  /// sheet; null when the capture backend does not expose it (test fakes).
  ActiveRecordingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeRecordingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeRecordingHash();

  @$internal
  @override
  $ProviderElement<ActiveRecording?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ActiveRecording? create(Ref ref) {
    return activeRecording(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ActiveRecording? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ActiveRecording?>(value),
    );
  }
}

String _$activeRecordingHash() => r'95bd46148965e6de317d7a18b4c4bd2d314fb5ab';

/// Writes the recording screen's choices (AUD-08).

@ProviderFor(recordingSessionService)
final recordingSessionServiceProvider = RecordingSessionServiceProvider._();

/// Writes the recording screen's choices (AUD-08).

final class RecordingSessionServiceProvider
    extends
        $FunctionalProvider<
          RecordingSessionService,
          RecordingSessionService,
          RecordingSessionService
        >
    with $Provider<RecordingSessionService> {
  /// Writes the recording screen's choices (AUD-08).
  RecordingSessionServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recordingSessionServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recordingSessionServiceHash();

  @$internal
  @override
  $ProviderElement<RecordingSessionService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RecordingSessionService create(Ref ref) {
    return recordingSessionService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RecordingSessionService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RecordingSessionService>(value),
    );
  }
}

String _$recordingSessionServiceHash() =>
    r'a1686aa778d2d77ac3ccb6b45feea0982bfdb5f3';

/// Profiles to pre-select (Auto is implicit). Empty when the registry is
/// unavailable — the screen then offers Auto only.

@ProviderFor(profileChoices)
final profileChoicesProvider = ProfileChoicesProvider._();

/// Profiles to pre-select (Auto is implicit). Empty when the registry is
/// unavailable — the screen then offers Auto only.

final class ProfileChoicesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ProfileChoice>>,
          List<ProfileChoice>,
          Stream<List<ProfileChoice>>
        >
    with
        $FutureModifier<List<ProfileChoice>>,
        $StreamProvider<List<ProfileChoice>> {
  /// Profiles to pre-select (Auto is implicit). Empty when the registry is
  /// unavailable — the screen then offers Auto only.
  ProfileChoicesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileChoicesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileChoicesHash();

  @$internal
  @override
  $StreamProviderElement<List<ProfileChoice>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ProfileChoice>> create(Ref ref) {
    return profileChoices(ref);
  }
}

String _$profileChoicesHash() => r'baf5ef3133070e681ea7a9b4ef17c7b3c08a5eca';

/// Vault folders to send the note to (Auto = routing rules).

@ProviderFor(destinationChoices)
final destinationChoicesProvider = DestinationChoicesProvider._();

/// Vault folders to send the note to (Auto = routing rules).

final class DestinationChoicesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<DestinationChoice>>,
          List<DestinationChoice>,
          FutureOr<List<DestinationChoice>>
        >
    with
        $FutureModifier<List<DestinationChoice>>,
        $FutureProvider<List<DestinationChoice>> {
  /// Vault folders to send the note to (Auto = routing rules).
  DestinationChoicesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'destinationChoicesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$destinationChoicesHash();

  @$internal
  @override
  $FutureProviderElement<List<DestinationChoice>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<DestinationChoice>> create(Ref ref) {
    return destinationChoices(ref);
  }
}

String _$destinationChoicesHash() =>
    r'987d0b9556dc255910323b3fe4771db3bbcf61fc';
