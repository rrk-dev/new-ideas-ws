// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recording_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Platform call guard (SEC-09); tests override it with `FakeCallGuard`.

@ProviderFor(callGuard)
final callGuardProvider = CallGuardProvider._();

/// Platform call guard (SEC-09); tests override it with `FakeCallGuard`.

final class CallGuardProvider
    extends $FunctionalProvider<CallGuard, CallGuard, CallGuard>
    with $Provider<CallGuard> {
  /// Platform call guard (SEC-09); tests override it with `FakeCallGuard`.
  CallGuardProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'callGuardProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$callGuardHash();

  @$internal
  @override
  $ProviderElement<CallGuard> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CallGuard create(Ref ref) {
    return callGuard(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CallGuard value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CallGuard>(value),
    );
  }
}

String _$callGuardHash() => r'a6c1e88ffb8313dec8f094c025b6c092f4f3ad78';

/// Standard OS microphone API (`record` package); tests use a fake.

@ProviderFor(pcmMicSource)
final pcmMicSourceProvider = PcmMicSourceProvider._();

/// Standard OS microphone API (`record` package); tests use a fake.

final class PcmMicSourceProvider
    extends $FunctionalProvider<PcmMicSource, PcmMicSource, PcmMicSource>
    with $Provider<PcmMicSource> {
  /// Standard OS microphone API (`record` package); tests use a fake.
  PcmMicSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pcmMicSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pcmMicSourceHash();

  @$internal
  @override
  $ProviderElement<PcmMicSource> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PcmMicSource create(Ref ref) {
    return pcmMicSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PcmMicSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PcmMicSource>(value),
    );
  }
}

String _$pcmMicSourceHash() => r'14b17b3d0b5196c19cd5ac003aa659a4c24d90a4';

/// Free-space probe for the recording storage policy.

@ProviderFor(diskSpaceProbe)
final diskSpaceProbeProvider = DiskSpaceProbeProvider._();

/// Free-space probe for the recording storage policy.

final class DiskSpaceProbeProvider
    extends $FunctionalProvider<DiskSpaceProbe, DiskSpaceProbe, DiskSpaceProbe>
    with $Provider<DiskSpaceProbe> {
  /// Free-space probe for the recording storage policy.
  DiskSpaceProbeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'diskSpaceProbeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$diskSpaceProbeHash();

  @$internal
  @override
  $ProviderElement<DiskSpaceProbe> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DiskSpaceProbe create(Ref ref) {
    return diskSpaceProbe(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DiskSpaceProbe value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DiskSpaceProbe>(value),
    );
  }
}

String _$diskSpaceProbeHash() => r'cdbd1cf159dc9b43d433dd4f0e67088ba3c5178f';

/// Chunk file codec. SEC-01 overrides it if its ADR picks `vvenc`.

@ProviderFor(audioChunkCodec)
final audioChunkCodecProvider = AudioChunkCodecProvider._();

/// Chunk file codec. SEC-01 overrides it if its ADR picks `vvenc`.

final class AudioChunkCodecProvider
    extends
        $FunctionalProvider<AudioChunkCodec, AudioChunkCodec, AudioChunkCodec>
    with $Provider<AudioChunkCodec> {
  /// Chunk file codec. SEC-01 overrides it if its ADR picks `vvenc`.
  AudioChunkCodecProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'audioChunkCodecProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$audioChunkCodecHash();

  @$internal
  @override
  $ProviderElement<AudioChunkCodec> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AudioChunkCodec create(Ref ref) {
    return audioChunkCodec(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AudioChunkCodec value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AudioChunkCodec>(value),
    );
  }
}

String _$audioChunkCodecHash() => r'da3872a8e77c3efae435710c9f3e6e74b8420fb3';

/// iOS audio-session observer (route / engine configuration / media-services
/// reset, AUD-04). Android `AudioRecord` follows routes itself.

@ProviderFor(audioSessionMonitor)
final audioSessionMonitorProvider = AudioSessionMonitorProvider._();

/// iOS audio-session observer (route / engine configuration / media-services
/// reset, AUD-04). Android `AudioRecord` follows routes itself.

final class AudioSessionMonitorProvider
    extends
        $FunctionalProvider<
          AudioSessionMonitor,
          AudioSessionMonitor,
          AudioSessionMonitor
        >
    with $Provider<AudioSessionMonitor> {
  /// iOS audio-session observer (route / engine configuration / media-services
  /// reset, AUD-04). Android `AudioRecord` follows routes itself.
  AudioSessionMonitorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'audioSessionMonitorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$audioSessionMonitorHash();

  @$internal
  @override
  $ProviderElement<AudioSessionMonitor> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AudioSessionMonitor create(Ref ref) {
    return audioSessionMonitor(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AudioSessionMonitor value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AudioSessionMonitor>(value),
    );
  }
}

String _$audioSessionMonitorHash() =>
    r'4f507bc4d2d641013bdbe8582588cdb91ff7a66e';

/// Platform voice-processing effects of this device (AUD-02).

@ProviderFor(platformAudioEffects)
final platformAudioEffectsProvider = PlatformAudioEffectsProvider._();

/// Platform voice-processing effects of this device (AUD-02).

final class PlatformAudioEffectsProvider
    extends
        $FunctionalProvider<
          AsyncValue<PlatformAudioEffects>,
          PlatformAudioEffects,
          FutureOr<PlatformAudioEffects>
        >
    with
        $FutureModifier<PlatformAudioEffects>,
        $FutureProvider<PlatformAudioEffects> {
  /// Platform voice-processing effects of this device (AUD-02).
  PlatformAudioEffectsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'platformAudioEffectsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$platformAudioEffectsHash();

  @$internal
  @override
  $FutureProviderElement<PlatformAudioEffects> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PlatformAudioEffects> create(Ref ref) {
    return platformAudioEffects(ref);
  }
}

String _$platformAudioEffectsHash() =>
    r'53be40be201f824fe8ff9e2b04085458954e2c45';

/// Reads the user's audio-processing settings (Settings → Audio) — managed
/// value › user value › default, like `settingStateProvider`, but straight
/// from the sources so it works from a keep-alive provider.

@ProviderFor(audioProcessingSettingsReader)
final audioProcessingSettingsReaderProvider =
    AudioProcessingSettingsReaderProvider._();

/// Reads the user's audio-processing settings (Settings → Audio) — managed
/// value › user value › default, like `settingStateProvider`, but straight
/// from the sources so it works from a keep-alive provider.

final class AudioProcessingSettingsReaderProvider
    extends
        $FunctionalProvider<
          Future<AudioProcessingSettings> Function(),
          Future<AudioProcessingSettings> Function(),
          Future<AudioProcessingSettings> Function()
        >
    with $Provider<Future<AudioProcessingSettings> Function()> {
  /// Reads the user's audio-processing settings (Settings → Audio) — managed
  /// value › user value › default, like `settingStateProvider`, but straight
  /// from the sources so it works from a keep-alive provider.
  AudioProcessingSettingsReaderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'audioProcessingSettingsReaderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$audioProcessingSettingsReaderHash();

  @$internal
  @override
  $ProviderElement<Future<AudioProcessingSettings> Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Future<AudioProcessingSettings> Function() create(Ref ref) {
    return audioProcessingSettingsReader(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Future<AudioProcessingSettings> Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<Future<AudioProcessingSettings> Function()>(value),
    );
  }
}

String _$audioProcessingSettingsReaderHash() =>
    r'f25a670c42b012e5df24c1638ec6c94e8ae77e11';

/// The real microphone capture (AUD-01).

@ProviderFor(recordCaptureBackend)
final recordCaptureBackendProvider = RecordCaptureBackendProvider._();

/// The real microphone capture (AUD-01).

final class RecordCaptureBackendProvider
    extends
        $FunctionalProvider<
          RecordCaptureBackend,
          RecordCaptureBackend,
          RecordCaptureBackend
        >
    with $Provider<RecordCaptureBackend> {
  /// The real microphone capture (AUD-01).
  RecordCaptureBackendProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recordCaptureBackendProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recordCaptureBackendHash();

  @$internal
  @override
  $ProviderElement<RecordCaptureBackend> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RecordCaptureBackend create(Ref ref) {
    return recordCaptureBackend(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RecordCaptureBackend value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RecordCaptureBackend>(value),
    );
  }
}

String _$recordCaptureBackendHash() =>
    r'02f4bc106f124f78ce905bb5ead34028a4b58c0f';

/// Live input level of the open recording (AUD-02 meter). Empty when the
/// capture backend does not meter (test fakes).

@ProviderFor(recordingLevels)
final recordingLevelsProvider = RecordingLevelsProvider._();

/// Live input level of the open recording (AUD-02 meter). Empty when the
/// capture backend does not meter (test fakes).

final class RecordingLevelsProvider
    extends
        $FunctionalProvider<
          AsyncValue<AudioLevel>,
          AudioLevel,
          Stream<AudioLevel>
        >
    with $FutureModifier<AudioLevel>, $StreamProvider<AudioLevel> {
  /// Live input level of the open recording (AUD-02 meter). Empty when the
  /// capture backend does not meter (test fakes).
  RecordingLevelsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recordingLevelsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recordingLevelsHash();

  @$internal
  @override
  $StreamProviderElement<AudioLevel> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<AudioLevel> create(Ref ref) {
    return recordingLevels(ref);
  }
}

String _$recordingLevelsHash() => r'42db6fa578f30428258dc75557524cbb6d3ed0f4';

/// Selectable inputs (built-in, wired, Bluetooth HFP, USB). Querying never
/// opens the microphone.

@ProviderFor(recordingInputDevices)
final recordingInputDevicesProvider = RecordingInputDevicesProvider._();

/// Selectable inputs (built-in, wired, Bluetooth HFP, USB). Querying never
/// opens the microphone.

final class RecordingInputDevicesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AudioInputDevice>>,
          List<AudioInputDevice>,
          FutureOr<List<AudioInputDevice>>
        >
    with
        $FutureModifier<List<AudioInputDevice>>,
        $FutureProvider<List<AudioInputDevice>> {
  /// Selectable inputs (built-in, wired, Bluetooth HFP, USB). Querying never
  /// opens the microphone.
  RecordingInputDevicesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recordingInputDevicesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recordingInputDevicesHash();

  @$internal
  @override
  $FutureProviderElement<List<AudioInputDevice>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AudioInputDevice>> create(Ref ref) {
    return recordingInputDevices(ref);
  }
}

String _$recordingInputDevicesHash() =>
    r'be1c03b245d93c5d82c1395e93853c70b76585da';

/// Selects the input used by the next start/resume (null = default).

@ProviderFor(recordingInputSelector)
final recordingInputSelectorProvider = RecordingInputSelectorProvider._();

/// Selects the input used by the next start/resume (null = default).

final class RecordingInputSelectorProvider
    extends
        $FunctionalProvider<
          void Function(AudioInputDevice?),
          void Function(AudioInputDevice?),
          void Function(AudioInputDevice?)
        >
    with $Provider<void Function(AudioInputDevice?)> {
  /// Selects the input used by the next start/resume (null = default).
  RecordingInputSelectorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recordingInputSelectorProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recordingInputSelectorHash();

  @$internal
  @override
  $ProviderElement<void Function(AudioInputDevice?)> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  void Function(AudioInputDevice?) create(Ref ref) {
    return recordingInputSelector(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void Function(AudioInputDevice?) value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void Function(AudioInputDevice?)>(
        value,
      ),
    );
  }
}

String _$recordingInputSelectorHash() =>
    r'fdc661708e30413a84094fdc2a368fc167c0f930';

/// Recordings repaired at launch after a crash / OS kill (AUD-07). Runs once
/// per process; never touches the recording open in this process.

@ProviderFor(recoveredRecordings)
final recoveredRecordingsProvider = RecoveredRecordingsProvider._();

/// Recordings repaired at launch after a crash / OS kill (AUD-07). Runs once
/// per process; never touches the recording open in this process.

final class RecoveredRecordingsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RecoveredRecording>>,
          List<RecoveredRecording>,
          FutureOr<List<RecoveredRecording>>
        >
    with
        $FutureModifier<List<RecoveredRecording>>,
        $FutureProvider<List<RecoveredRecording>> {
  /// Recordings repaired at launch after a crash / OS kill (AUD-07). Runs once
  /// per process; never touches the recording open in this process.
  RecoveredRecordingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recoveredRecordingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recoveredRecordingsHash();

  @$internal
  @override
  $FutureProviderElement<List<RecoveredRecording>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<RecoveredRecording>> create(Ref ref) {
    return recoveredRecordings(ref);
  }
}

String _$recoveredRecordingsHash() =>
    r'5dc2cb5ca21938bdb8a50d6c44b3dd5c0a58a32f';

/// "Process now" for a recovered recording: queues it at the front of the
/// pipeline (FND-05).

@ProviderFor(recoveredRecordingProcessor)
final recoveredRecordingProcessorProvider =
    RecoveredRecordingProcessorProvider._();

/// "Process now" for a recovered recording: queues it at the front of the
/// pipeline (FND-05).

final class RecoveredRecordingProcessorProvider
    extends
        $FunctionalProvider<
          Future<void> Function(String recordingId),
          Future<void> Function(String recordingId),
          Future<void> Function(String recordingId)
        >
    with $Provider<Future<void> Function(String recordingId)> {
  /// "Process now" for a recovered recording: queues it at the front of the
  /// pipeline (FND-05).
  RecoveredRecordingProcessorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recoveredRecordingProcessorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recoveredRecordingProcessorHash();

  @$internal
  @override
  $ProviderElement<Future<void> Function(String recordingId)> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Future<void> Function(String recordingId) create(Ref ref) {
    return recoveredRecordingProcessor(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Future<void> Function(String recordingId) value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<Future<void> Function(String recordingId)>(value),
    );
  }
}

String _$recoveredRecordingProcessorHash() =>
    r'90b7d8253650dbe8e92c2b440c3795e8d124980f';

/// Microphone capture driven by [recordingController]; tests override it
/// with `FakeCaptureBackend`.

@ProviderFor(captureBackend)
final captureBackendProvider = CaptureBackendProvider._();

/// Microphone capture driven by [recordingController]; tests override it
/// with `FakeCaptureBackend`.

final class CaptureBackendProvider
    extends $FunctionalProvider<CaptureBackend, CaptureBackend, CaptureBackend>
    with $Provider<CaptureBackend> {
  /// Microphone capture driven by [recordingController]; tests override it
  /// with `FakeCaptureBackend`.
  CaptureBackendProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'captureBackendProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$captureBackendHash();

  @$internal
  @override
  $ProviderElement<CaptureBackend> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CaptureBackend create(Ref ref) {
    return captureBackend(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CaptureBackend value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CaptureBackend>(value),
    );
  }
}

String _$captureBackendHash() => r'abb770d3a28157dfc7aff6d2061bf3e16b4c54a0';

/// Platform channel behind the OS recording indicator (Android foreground
/// service notification — AUD-05; iOS — AUD-04).

@ProviderFor(platformRecordingIndicator)
final platformRecordingIndicatorProvider =
    PlatformRecordingIndicatorProvider._();

/// Platform channel behind the OS recording indicator (Android foreground
/// service notification — AUD-05; iOS — AUD-04).

final class PlatformRecordingIndicatorProvider
    extends
        $FunctionalProvider<
          MethodChannelRecordingIndicator,
          MethodChannelRecordingIndicator,
          MethodChannelRecordingIndicator
        >
    with $Provider<MethodChannelRecordingIndicator> {
  /// Platform channel behind the OS recording indicator (Android foreground
  /// service notification — AUD-05; iOS — AUD-04).
  PlatformRecordingIndicatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'platformRecordingIndicatorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$platformRecordingIndicatorHash();

  @$internal
  @override
  $ProviderElement<MethodChannelRecordingIndicator> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MethodChannelRecordingIndicator create(Ref ref) {
    return platformRecordingIndicator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MethodChannelRecordingIndicator value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MethodChannelRecordingIndicator>(
        value,
      ),
    );
  }
}

String _$platformRecordingIndicatorHash() =>
    r'ca775aeea35f0039197fea6b2a7207af2201e7d3';

/// The always-visible OS recording indicator; tests override it.

@ProviderFor(recordingIndicator)
final recordingIndicatorProvider = RecordingIndicatorProvider._();

/// The always-visible OS recording indicator; tests override it.

final class RecordingIndicatorProvider
    extends
        $FunctionalProvider<
          RecordingIndicator,
          RecordingIndicator,
          RecordingIndicator
        >
    with $Provider<RecordingIndicator> {
  /// The always-visible OS recording indicator; tests override it.
  RecordingIndicatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recordingIndicatorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recordingIndicatorHash();

  @$internal
  @override
  $ProviderElement<RecordingIndicator> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RecordingIndicator create(Ref ref) {
    return recordingIndicator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RecordingIndicator value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RecordingIndicator>(value),
    );
  }
}

String _$recordingIndicatorHash() =>
    r'039dc3036e439a0c1f186a44c4391f2c02e1614e';

/// Battery-optimization state for the OEM guidance card (Android; null
/// elsewhere).

@ProviderFor(batteryStatus)
final batteryStatusProvider = BatteryStatusProvider._();

/// Battery-optimization state for the OEM guidance card (Android; null
/// elsewhere).

final class BatteryStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<BatteryStatus?>,
          BatteryStatus?,
          FutureOr<BatteryStatus?>
        >
    with $FutureModifier<BatteryStatus?>, $FutureProvider<BatteryStatus?> {
  /// Battery-optimization state for the OEM guidance card (Android; null
  /// elsewhere).
  BatteryStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'batteryStatusProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$batteryStatusHash();

  @$internal
  @override
  $FutureProviderElement<BatteryStatus?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BatteryStatus?> create(Ref ref) {
    return batteryStatus(ref);
  }
}

String _$batteryStatusHash() => r'18cdbd4405a471c412986f24b3571ffce57d91fe';

/// Auto-pause / auto-stop after silence (AUD-03). Watching it (Record tab)
/// attaches it to the controller; it can only pause or stop (SEC-09).

@ProviderFor(silenceWatcher)
final silenceWatcherProvider = SilenceWatcherProvider._();

/// Auto-pause / auto-stop after silence (AUD-03). Watching it (Record tab)
/// attaches it to the controller; it can only pause or stop (SEC-09).

final class SilenceWatcherProvider
    extends $FunctionalProvider<SilenceWatcher, SilenceWatcher, SilenceWatcher>
    with $Provider<SilenceWatcher> {
  /// Auto-pause / auto-stop after silence (AUD-03). Watching it (Record tab)
  /// attaches it to the controller; it can only pause or stop (SEC-09).
  SilenceWatcherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'silenceWatcherProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$silenceWatcherHash();

  @$internal
  @override
  $ProviderElement<SilenceWatcher> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SilenceWatcher create(Ref ref) {
    return silenceWatcher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SilenceWatcher value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SilenceWatcher>(value),
    );
  }
}

String _$silenceWatcherHash() => r'7605de25c9c4ac4a619e9c94d6894bea4a4f4fcf';

/// The single recording entry point (SEC-09).

@ProviderFor(recordingController)
final recordingControllerProvider = RecordingControllerProvider._();

/// The single recording entry point (SEC-09).

final class RecordingControllerProvider
    extends
        $FunctionalProvider<
          RecordingController,
          RecordingController,
          RecordingController
        >
    with $Provider<RecordingController> {
  /// The single recording entry point (SEC-09).
  RecordingControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recordingControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recordingControllerHash();

  @$internal
  @override
  $ProviderElement<RecordingController> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RecordingController create(Ref ref) {
    return recordingController(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RecordingController value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RecordingController>(value),
    );
  }
}

String _$recordingControllerHash() =>
    r'e803b1bde4c6a7631cee25bde6862473c7976287';
