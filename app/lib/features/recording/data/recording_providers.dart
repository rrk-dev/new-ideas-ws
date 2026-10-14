import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/diagnostics/diagnostics_providers.dart';
import 'package:vaultvoice/core/platform/call_guard.dart';
import 'package:vaultvoice/core/platform/id_generator.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_providers.dart';
import 'package:vaultvoice/features/recording/data/method_channel_audio_session_monitor.dart';
import 'package:vaultvoice/features/recording/data/method_channel_call_guard.dart';
import 'package:vaultvoice/features/recording/data/method_channel_disk_space_probe.dart';
import 'package:vaultvoice/features/recording/data/method_channel_recording_indicator.dart';
import 'package:vaultvoice/features/recording/data/record_capture_backend.dart';
import 'package:vaultvoice/features/recording/data/record_mic_source.dart';
import 'package:vaultvoice/features/recording/data/recording_recovery.dart';
import 'package:vaultvoice/features/recording/data/wav_chunk_codec.dart';
import 'package:vaultvoice/features/recording/domain/audio_chunk_codec.dart';
import 'package:vaultvoice/features/recording/domain/audio_format.dart';
import 'package:vaultvoice/features/recording/domain/audio_session_monitor.dart';
import 'package:vaultvoice/features/recording/domain/capture_backend.dart';
import 'package:vaultvoice/features/recording/domain/pcm_mic_source.dart';
import 'package:vaultvoice/features/recording/domain/recording_controller.dart';
import 'package:vaultvoice/features/recording/domain/recording_indicator.dart';
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

/// iOS audio-session observer (route / engine configuration / media-services
/// reset, AUD-04). Android `AudioRecord` follows routes itself.
@Riverpod(keepAlive: true)
AudioSessionMonitor audioSessionMonitor(Ref ref) => Platform.isIOS
    ? MethodChannelAudioSessionMonitor()
    : const NoAudioSessionMonitor();

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
    audioSession: ref.watch(audioSessionMonitorProvider),
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

/// Recordings repaired at launch after a crash / OS kill (AUD-07). Runs once
/// per process; never touches the recording open in this process.
@Riverpod(keepAlive: true)
Future<List<RecoveredRecording>> recoveredRecordings(Ref ref) async {
  final paths = await ref.watch(storagePathsProvider.future);
  final open = ref.read(recordCaptureBackendProvider).recordingId;
  final recovery = RecordingRecovery(
    recordings: ref.watch(recordingsRepositoryProvider),
    paths: paths,
    codec: ref.watch(audioChunkCodecProvider),
    logger: ref.watch(loggerProvider),
  );
  final r = await recovery.recoverOrphans(skip: {?open});
  return r.valueOrNull ?? const [];
}

/// "Process now" for a recovered recording: queues it at the front of the
/// pipeline (FND-05).
@Riverpod(keepAlive: true)
Future<void> Function(String recordingId) recoveredRecordingProcessor(
  Ref ref,
) => (id) async {
  final client = await ref.read(pipelineClientProvider.future);
  await client.enqueue(id, userInitiated: true);
};

/// Microphone capture driven by [recordingController]; tests override it
/// with `FakeCaptureBackend`.
@Riverpod(keepAlive: true)
CaptureBackend captureBackend(Ref ref) =>
    ref.watch(recordCaptureBackendProvider);

/// Platform channel behind the OS recording indicator (Android foreground
/// service notification — AUD-05; iOS — AUD-04).
@Riverpod(keepAlive: true)
MethodChannelRecordingIndicator platformRecordingIndicator(Ref ref) =>
    MethodChannelRecordingIndicator();

/// The always-visible OS recording indicator; tests override it.
@Riverpod(keepAlive: true)
RecordingIndicator recordingIndicator(Ref ref) =>
    ref.watch(platformRecordingIndicatorProvider);

/// Battery-optimization state for the OEM guidance card (Android; null
/// elsewhere).
@riverpod
Future<BatteryStatus?> batteryStatus(Ref ref) =>
    ref.watch(platformRecordingIndicatorProvider).batteryStatus();

/// The single recording entry point (SEC-09).
@Riverpod(keepAlive: true)
RecordingController recordingController(Ref ref) {
  final controller = RecordingController(
    capture: ref.watch(captureBackendProvider),
    callGuard: ref.watch(callGuardProvider),
    clock: ref.watch(clockProvider),
    isAppInForeground: isAppInForeground,
    // "Still recording (1h 00m)" while backgrounded (SEC-09 §6, AUD-05).
    reminders: ref.watch(recordingIndicatorProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
}

/// Whether the app is visible and interactive. Fails closed: an unknown
/// lifecycle state (e.g. a headless engine) is not foreground, so no
/// background/headless start is possible.
bool isAppInForeground() =>
    WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
