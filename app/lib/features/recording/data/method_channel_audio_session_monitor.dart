import 'package:flutter/services.dart';
import 'package:vaultvoice/features/recording/domain/audio_session_monitor.dart';

/// [AudioSessionMonitor] backed by `ios/Runner/AudioSessionPlugin.swift`
/// (AUD-04). Wire format: `{kind: AudioSessionEventKind name, reason?:
/// String, inputs: [String]}`; unknown payloads are dropped.
class MethodChannelAudioSessionMonitor implements AudioSessionMonitor {
  MethodChannelAudioSessionMonitor([
    this._channel = const EventChannel(channelName),
  ]);

  static const channelName = 'vaultvoice/audio_session/events';

  final EventChannel _channel;
  Stream<AudioSessionEvent>? _events;

  @override
  Stream<AudioSessionEvent> get events => _events ??= _channel
      .receiveBroadcastStream()
      .map(decode)
      .where((e) => e != null)
      .cast<AudioSessionEvent>();

  static AudioSessionEvent? decode(Object? raw) {
    if (raw is! Map) return null;
    final kind = AudioSessionEventKind.tryParse(raw['kind']);
    if (kind == null) return null;
    final reason = raw['reason'];
    final inputs = raw['inputs'];
    return AudioSessionEvent(
      kind,
      reason: reason is String ? reason : null,
      inputs: inputs is List ? inputs.whereType<String>().toList() : const [],
    );
  }
}
