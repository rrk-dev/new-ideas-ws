import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart' as rec;
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/clock.dart';
import 'package:vaultvoice/features/recording/domain/audio_format.dart';
import 'package:vaultvoice/features/recording/domain/pcm_mic_source.dart';

/// [PcmMicSource] on the `record` package (verified against record 7.1.2 /
/// record_android 2.2.0 / record_ios 2.1.1 / record_platform_interface
/// 2.1.0): iOS AVAudioSession + AVAudioEngine, Android `AudioRecord` — the
/// standard OS microphone APIs (SEC-09 §1).
///
/// A fresh plugin recorder is created per [open] and disposed on [close], so
/// no native input is held between segments (no pre-capture).
class RecordMicSource implements PcmMicSource {
  RecordMicSource({
    rec.AudioRecorder Function()? createRecorder,
    this._clock = const SystemClock(),
  }) : _create = createRecorder ?? rec.AudioRecorder.new;

  final rec.AudioRecorder Function() _create;
  final Clock _clock;

  rec.AudioRecorder? _plugin;
  StreamController<MicEvent>? _events;
  // Cancelled in close().
  // ignore: cancel_subscriptions
  StreamSubscription<Uint8List>? _dataSub;
  // Cancelled in close().
  // ignore: cancel_subscriptions
  StreamSubscription<rec.RecordState>? _stateSub;

  /// A short-lived recorder for permission and device queries (these never
  /// open the microphone input).
  Future<T> _withQueryRecorder<T>(
    Future<T> Function(rec.AudioRecorder r) body,
  ) async {
    final open = _plugin;
    if (open != null) return await body(open);
    final r = _create();
    try {
      return await body(r);
    } finally {
      await r.dispose();
    }
  }

  @override
  Future<bool> hasPermission({bool request = true}) async {
    try {
      return await _withQueryRecorder((r) => r.hasPermission(request: request));
    } on Object {
      return false;
    }
  }

  @override
  Future<Result<List<AudioInputDevice>>> inputDevices() async {
    try {
      final list = await _withQueryRecorder((r) => r.listInputDevices());
      return Ok([
        for (final d in list)
          AudioInputDevice(id: d.id, label: d.label, kind: inputKindOf(d.type)),
      ]);
    } on Object catch (e) {
      return Err(UnexpectedFailure(e.runtimeType.toString()));
    }
  }

  @override
  Future<Result<Stream<MicEvent>>> open(MicRequest request) async {
    await close();
    final events = StreamController<MicEvent>(sync: true);
    final plugin = _create();
    _events = events;
    _plugin = plugin;
    try {
      await plugin.setOnConfigChanged((c) {
        if (!events.isClosed) {
          events.add(
            MicFormatChanged(
              MicFormat(sampleRate: c.sampleRate, channels: c.numChannels),
            ),
          );
        }
      });
      _stateSub = plugin.onStateChanged().listen((s) {
        // The plugin paused by itself (focus loss / OS interruption): report
        // it; it is never resumed automatically (SEC-09 §3).
        if (s == rec.RecordState.pause && !events.isClosed) {
          events.add(const MicInterrupted());
        }
      }, onError: (Object _) {});
      final pcm = await plugin.startStream(buildRecordConfig(request));
      _dataSub = pcm.listen(
        (bytes) {
          if (!events.isClosed) events.add(MicData(bytes, _clock.now()));
        },
        onError: (Object e) {
          if (!events.isClosed) events.add(MicFailed(e.runtimeType.toString()));
        },
        onDone: () {
          if (!events.isClosed) events.add(const MicFailed('stream ended'));
        },
      );
      return Ok(events.stream);
    } on Object catch (e) {
      await close();
      return Err(UnexpectedFailure(e.runtimeType.toString()));
    }
  }

  @override
  Future<void> close() async {
    final plugin = _plugin;
    final events = _events;
    final dataSub = _dataSub;
    final stateSub = _stateSub;
    _plugin = null;
    _events = null;
    _dataSub = null;
    _stateSub = null;
    // Close our stream first so nothing captured from here on is delivered.
    if (events != null && !events.isClosed) unawaited(events.close());
    await dataSub?.cancel();
    await stateSub?.cancel();
    if (plugin != null) {
      try {
        await plugin.stop();
      } on Object {
        // Already stopped by the platform.
      }
      try {
        await plugin.dispose();
      } on Object {
        // Best effort.
      }
    }
  }
}

/// The `record` configuration for [request] — the one place the recording
/// policy (SEC-09) meets the plugin; pinned by tests:
/// * PCM16, 16 kHz, mono stream (format contract);
/// * Android source `voiceRecognition` or `mic` only; audio-manager mode
///   untouched (`modeNormal`), no stream muting, no speakerphone;
/// * Bluetooth SCO only when the user picked a Bluetooth input;
/// * iOS `.playAndRecord` with `defaultToSpeaker` + `allowBluetooth`
///   (HFP) — never mixing with other apps;
/// * on interruption the plugin **pauses** and never resumes by itself.
rec.RecordConfig buildRecordConfig(MicRequest request) {
  final device = request.device;
  final bluetooth = device?.kind == AudioInputKind.bluetooth;
  return rec.RecordConfig(
    encoder: rec.AudioEncoder.pcm16bits,
    sampleRate: AudioFormat.sampleRate,
    numChannels: AudioFormat.channels,
    autoGain: request.autoGain,
    echoCancel: request.echoCancel,
    noiseSuppress: request.noiseSuppress,
    device: device == null
        ? null
        : rec.InputDevice(id: device.id, label: device.label),
    androidConfig: rec.AndroidRecordConfig(
      audioSource: switch (request.androidSource) {
        MicAudioSource.voiceRecognition =>
          rec.AndroidAudioSource.voiceRecognition,
        MicAudioSource.mic => rec.AndroidAudioSource.mic,
      },
      manageBluetooth: bluetooth,
    ),
    iosConfig: const rec.IosRecordConfig(
      categoryOptions: [
        rec.IosAudioCategoryOption.defaultToSpeaker,
        rec.IosAudioCategoryOption.allowBluetooth,
      ],
    ),
    // Explicit (= the plugin default) so the no-auto-resume policy is
    // visible and pinned here.
    // ignore: avoid_redundant_argument_values
    audioInterruption: rec.AudioInterruptionMode.pause,
  );
}

/// Maps the plugin's device type to [AudioInputKind].
AudioInputKind inputKindOf(rec.InputDeviceType type) => switch (type) {
  rec.InputDeviceType.builtIn => AudioInputKind.builtIn,
  rec.InputDeviceType.wiredHeadset ||
  rec.InputDeviceType.lineIn => AudioInputKind.wired,
  rec.InputDeviceType.bluetoothSco ||
  rec.InputDeviceType.bluetoothA2dp ||
  rec.InputDeviceType.bluetoothLe => AudioInputKind.bluetooth,
  rec.InputDeviceType.usb => AudioInputKind.usb,
  _ => AudioInputKind.unknown,
};
