// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_import_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(audioFilePicker)
final audioFilePickerProvider = AudioFilePickerProvider._();

final class AudioFilePickerProvider
    extends
        $FunctionalProvider<AudioFilePicker, AudioFilePicker, AudioFilePicker>
    with $Provider<AudioFilePicker> {
  AudioFilePickerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'audioFilePickerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$audioFilePickerHash();

  @$internal
  @override
  $ProviderElement<AudioFilePicker> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AudioFilePicker create(Ref ref) {
    return audioFilePicker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AudioFilePicker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AudioFilePicker>(value),
    );
  }
}

String _$audioFilePickerHash() => r'3501084d188f5b4a058a88e84fa44290a8967392';

/// Native decoders (AUD-06); tests override with a fake.

@ProviderFor(audioDecoder)
final audioDecoderProvider = AudioDecoderProvider._();

/// Native decoders (AUD-06); tests override with a fake.

final class AudioDecoderProvider
    extends $FunctionalProvider<AudioDecoder, AudioDecoder, AudioDecoder>
    with $Provider<AudioDecoder> {
  /// Native decoders (AUD-06); tests override with a fake.
  AudioDecoderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'audioDecoderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$audioDecoderHash();

  @$internal
  @override
  $ProviderElement<AudioDecoder> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AudioDecoder create(Ref ref) {
    return audioDecoder(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AudioDecoder value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AudioDecoder>(value),
    );
  }
}

String _$audioDecoderHash() => r'6f1607373487537eada84a733024a2c32f1292c6';

/// Files shared into the app, waiting for the attestation; tests override.

@ProviderFor(sharedAudioInbox)
final sharedAudioInboxProvider = SharedAudioInboxProvider._();

/// Files shared into the app, waiting for the attestation; tests override.

final class SharedAudioInboxProvider
    extends
        $FunctionalProvider<
          SharedAudioInbox,
          SharedAudioInbox,
          SharedAudioInbox
        >
    with $Provider<SharedAudioInbox> {
  /// Files shared into the app, waiting for the attestation; tests override.
  SharedAudioInboxProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sharedAudioInboxProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sharedAudioInboxHash();

  @$internal
  @override
  $ProviderElement<SharedAudioInbox> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SharedAudioInbox create(Ref ref) {
    return sharedAudioInbox(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SharedAudioInbox value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SharedAudioInbox>(value),
    );
  }
}

String _$sharedAudioInboxHash() => r'b3ae256de4f51c64adc2f6241bee1efb5cdf11fe';

/// The platform whose decoder table applies.

@ProviderFor(importPlatform)
final importPlatformProvider = ImportPlatformProvider._();

/// The platform whose decoder table applies.

final class ImportPlatformProvider
    extends $FunctionalProvider<ImportPlatform, ImportPlatform, ImportPlatform>
    with $Provider<ImportPlatform> {
  /// The platform whose decoder table applies.
  ImportPlatformProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'importPlatformProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$importPlatformHash();

  @$internal
  @override
  $ProviderElement<ImportPlatform> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ImportPlatform create(Ref ref) {
    return importPlatform(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ImportPlatform value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ImportPlatform>(value),
    );
  }
}

String _$importPlatformHash() => r'9d0a40919fbeda64691c9a1d6b6188ffb0ce7c8d';

@ProviderFor(audioImportService)
final audioImportServiceProvider = AudioImportServiceProvider._();

final class AudioImportServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<AudioImportService>,
          AudioImportService,
          FutureOr<AudioImportService>
        >
    with
        $FutureModifier<AudioImportService>,
        $FutureProvider<AudioImportService> {
  AudioImportServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'audioImportServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$audioImportServiceHash();

  @$internal
  @override
  $FutureProviderElement<AudioImportService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AudioImportService> create(Ref ref) {
    return audioImportService(ref);
  }
}

String _$audioImportServiceHash() =>
    r'e83e4e5730a47620c3ab3311e76a0e697ac8a3f4';
