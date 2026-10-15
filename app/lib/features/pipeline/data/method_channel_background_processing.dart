import 'package:flutter/services.dart';
import 'package:vaultvoice/features/pipeline/domain/background_platform.dart';
import 'package:vaultvoice/features/pipeline/domain/processing_conditions.dart';

/// [BackgroundProcessingPlatform] over
/// `android/.../ProcessingPlugin.kt` and `ios/Runner/ProcessingPlugin.swift`
/// (FND-08).
///
/// Methods on `vaultvoice/processing`: `conditions()` → `{charging,
/// lowPower, thermal}`, `begin({title, text})`, `progress({percent})`,
/// `end()`, `scheduleDeferred()`, `completeDeferred({success})`.
/// Events on `vaultvoice/processing/events`: `{kind: conditions, …}`,
/// `{kind: expiring}`, `{kind: deferredStarted}`; unknown events are
/// dropped.
class MethodChannelBackgroundProcessing
    implements BackgroundProcessingPlatform {
  MethodChannelBackgroundProcessing({
    MethodChannel methods = const MethodChannel(methodChannelName),
    EventChannel events = const EventChannel(eventChannelName),
  }) : _channel = methods,
       _eventChannel = events;

  static const methodChannelName = 'vaultvoice/processing';
  static const eventChannelName = 'vaultvoice/processing/events';

  final MethodChannel _channel;
  final EventChannel _eventChannel;
  Stream<BackgroundEvent>? _events;

  @override
  Stream<BackgroundEvent> get events => _events ??= _eventChannel
      .receiveBroadcastStream()
      .map(decode)
      .where((e) => e != null)
      .cast<BackgroundEvent>();

  /// Decodes one event payload (null for unknown ones).
  static BackgroundEvent? decode(Object? raw) {
    if (raw is! Map) return null;
    return switch (raw['kind']) {
      'conditions' => ConditionsChanged(DeviceConditions.fromMap(raw)),
      'expiring' => const BackgroundTimeExpiring(),
      'deferredStarted' => const DeferredProcessingStarted(),
      _ => null,
    };
  }

  @override
  Future<DeviceConditions> conditions() async => DeviceConditions.fromMap(
    await _channel.invokeMethod<Object?>('conditions'),
  );

  @override
  Future<void> beginProcessing({required String title, required String text}) =>
      _channel.invokeMethod<void>('begin', {'title': title, 'text': text});

  @override
  Future<void> updateProgress(int percent) =>
      _channel.invokeMethod<void>('progress', {'percent': percent});

  @override
  Future<void> endProcessing() => _channel.invokeMethod<void>('end');

  @override
  Future<void> scheduleDeferred() =>
      _channel.invokeMethod<void>('scheduleDeferred');

  @override
  Future<void> completeDeferred({required bool success}) =>
      _channel.invokeMethod<void>('completeDeferred', {'success': success});
}
