import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/diagnostics/diagnostics_providers.dart';
import 'package:vaultvoice/core/platform/call_guard.dart';
import 'package:vaultvoice/core/platform/id_generator.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/features/recording/data/method_channel_call_guard.dart';
import 'package:vaultvoice/features/recording/data/method_channel_disk_space_probe.dart';
import 'package:vaultvoice/features/recording/data/record_capture_backend.dart';
import 'package:vaultvoice/features/recording/data/record_mic_source.dart';
import 'package:vaultvoice/features/recording/data/wav_chunk_codec.dart';
import 'package:vaultvoice/features/recording/domain/audio_chunk_codec.dart';
import 'package:vaultvoice/features/recording/domain/audio_format.dart';
import 'package:vaultvoice/features/recording/domain/capture_backend.dart';
import 'package:vaultvoice/features/recording/domain/pcm_mic_source.dart';
import 'package:vaultvoice/features/recording/domain/recording_controller.dart';
import 'package:vaultvoice/features/recording/domain/storage_policy.dart';

part 'recording_providers.g.dart';

/// Platform call guard (SEC-09); tests override it with `FakeCallGuard`.
@Riverpod(keepAlive: true)
CallGuard callGuard(Ref ref) => MethodChannelCallGuard();

/// Standard OS microphone API (`record` package); tests use a fake.
@Riverpod(keepAlive: true)
PcmMicSource pcmMicSource(Ref ref) =>
    RecordMicSource(clock: ref.watch(clockProvider));

/// Free-space probe for the recording storage policy.
@Riverpod(keepAlive: true)
DiskSpaceProbe diskSpaceProbe(Ref ref) => const MethodChannelDiskSpaceProbe();

/// Chunk file codec. SEC-01 overrides it if its ADR picks `vvenc`.
@Riverpod(keepAlive: true)
AudioChunkCodec audioChunkCodec(Ref ref) => const WavChunkCodec();

/// The real microphone capture (AUD-01).
@Riverpod(keepAlive: true)
RecordCaptureBackend recordCaptureBackend(Ref ref) {
  final backend = RecordCaptureBackend(
    mic: ref.watch(pcmMicSourceProvider),
    recordings: ref.watch(recordingsRepositoryProvider),
    paths: () => ref.read(storagePathsProvider.future),
    disk: ref.watch(diskSpaceProbeProvider),
    clock: ref.watch(clockProvider),
    ids: ref.watch(idGeneratorProvider),
    codec: ref.watch(audioChunkCodecProvider),
    logger: ref.watch(loggerProvider),
  );
  ref.onDispose(backend.dispose);
  return backend;
}

/// Selectable inputs (built-in, wired, Bluetooth HFP, USB). Querying never
/// opens the microphone.
@riverpod
Future<List<AudioInputDevice>> recordingInputDevices(Ref ref) async {
  final r = await ref.watch(recordCaptureBackendProvider).inputDevices();
  return r.valueOrNull ?? const [];
}

/// Selects the input used by the next start/resume (null = default).
@riverpod
void Function(AudioInputDevice?) recordingInputSelector(Ref ref) =>
    ref.watch(recordCaptureBackendProvider).selectInput;

/// Microphone capture driven by [recordingController]; tests override it
/// with `FakeCaptureBackend`.
@Riverpod(keepAlive: true)
CaptureBackend captureBackend(Ref ref) =>
    ref.watch(recordCaptureBackendProvider);

/// The single recording entry point (SEC-09).
@Riverpod(keepAlive: true)
RecordingController recordingController(Ref ref) {
  final controller = RecordingController(
    capture: ref.watch(captureBackendProvider),
    callGuard: ref.watch(callGuardProvider),
    clock: ref.watch(clockProvider),
    isAppInForeground: isAppInForeground,
  );
  ref.onDispose(controller.dispose);
  return controller;
}

/// Whether the app is visible and interactive. Fails closed: an unknown
/// lifecycle state (e.g. a headless engine) is not foreground, so no
/// background/headless start is possible.
bool isAppInForeground() =>
    WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
