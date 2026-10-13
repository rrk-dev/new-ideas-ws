import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/platform/call_guard.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/features/recording/data/method_channel_call_guard.dart';
import 'package:vaultvoice/features/recording/domain/capture_backend.dart';
import 'package:vaultvoice/features/recording/domain/recording_controller.dart';

part 'recording_providers.g.dart';

/// Platform call guard (SEC-09); tests override it with `FakeCallGuard`.
@Riverpod(keepAlive: true)
CallGuard callGuard(Ref ref) => MethodChannelCallGuard();

/// Microphone capture; AUD-01 supplies the real implementation.
@Riverpod(keepAlive: true)
CaptureBackend captureBackend(Ref ref) =>
    throw UnimplementedError('captureBackendProvider: delivered by AUD-01');

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
