import 'package:vaultvoice/features/pipeline/domain/processing_conditions.dart';

/// Events from the OS background-execution layer (FND-08).
sealed class BackgroundEvent {
  const BackgroundEvent();
}

/// Charging / power-saving / thermal state changed.
final class ConditionsChanged extends BackgroundEvent {
  const ConditionsChanged(this.conditions);

  final DeviceConditions conditions;
}

/// The OS is about to end background execution (iOS background task /
/// BGProcessingTask expiration handler, Android foreground-service
/// `onTimeout`): checkpoint (pause) now.
final class BackgroundTimeExpiring extends BackgroundEvent {
  const BackgroundTimeExpiring();
}

/// The OS started deferred processing (iOS `BGProcessingTask`) while the
/// app is in the background.
final class DeferredProcessingStarted extends BackgroundEvent {
  const DeferredProcessingStarted();
}

/// Keeps processing alive within each OS's rules (vv-background-execution):
///
/// - iOS: `beginBackgroundTask` while work is pending (≈ 30 s after the app
///   leaves the foreground) and a `BGProcessingTaskRequest`
///   (`requiresExternalPower`) for the rest; never audio-session tricks.
/// - Android: a `dataSync` (API ≤ 34) / `mediaProcessing` (API 35+)
///   foreground service with a progress notification, started only while the
///   app is visible; `onTimeout` → [BackgroundTimeExpiring].
abstract interface class BackgroundProcessingPlatform {
  Stream<BackgroundEvent> get events;

  /// Current charging / power-saving / thermal state.
  Future<DeviceConditions> conditions();

  /// Work is pending: hold the OS keep-alive (idempotent). [title]/[text]
  /// are generic, content-free notification texts.
  Future<void> beginProcessing({required String title, required String text});

  /// Progress 0–100 of the running job (Android notification).
  Future<void> updateProgress(int percent);

  /// No work left (or paused): release the keep-alive.
  Future<void> endProcessing();

  /// Ask the OS to run deferred processing later (iOS BGProcessingTask
  /// requiring external power; no-op elsewhere).
  Future<void> scheduleDeferred();

  /// The deferred task finished (or was paused) — iOS `setTaskCompleted`.
  Future<void> completeDeferred({required bool success});
}

/// Platforms without background execution rules (host, tests).
final class NoBackgroundProcessingPlatform
    implements BackgroundProcessingPlatform {
  const NoBackgroundProcessingPlatform();

  @override
  Stream<BackgroundEvent> get events => const Stream.empty();

  @override
  Future<DeviceConditions> conditions() async =>
      const DeviceConditions(charging: true);

  @override
  Future<void> beginProcessing({
    required String title,
    required String text,
  }) async {}

  @override
  Future<void> updateProgress(int percent) async {}

  @override
  Future<void> endProcessing() async {}

  @override
  Future<void> scheduleDeferred() async {}

  @override
  Future<void> completeDeferred({required bool success}) async {}
}
