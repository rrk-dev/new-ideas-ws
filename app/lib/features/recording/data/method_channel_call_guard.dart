import 'package:flutter/services.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/call_guard.dart';

/// [CallGuard] backed by the app's own platform code:
/// `ios/Runner/CallGuardPlugin.swift` and
/// `android/.../CallGuardPlugin.kt` (ADR-SEC-09). macOS answers `false`
/// without any call API (`macos/Runner/MacHostChannels.swift`).
///
/// Plain method/event channels rather than Pigeon: two calls, no generated
/// code, no new dependency (ADR-SEC-09 → "Channel").
class MethodChannelCallGuard implements CallGuard {
  MethodChannelCallGuard({
    this._methods = const MethodChannel(methodChannelName),
    this._events = const EventChannel(eventChannelName),
  });

  static const methodChannelName = 'vaultvoice/call_guard';
  static const eventChannelName = 'vaultvoice/call_guard/events';

  final MethodChannel _methods;
  final EventChannel _events;

  Stream<CallGuardEvent>? _stream;

  @override
  Future<Result<bool>> isInCall() async {
    try {
      final inCall = await _methods.invokeMethod<bool>('isInCall');
      if (inCall == null) {
        return const Err(UnexpectedFailure('call guard returned null'));
      }
      return Ok(inCall);
    } on Object catch (e) {
      // MissingPluginException / PlatformException: state unknown → the
      // caller fails closed.
      return Err(UnexpectedFailure(e.runtimeType.toString()));
    }
  }

  @override
  Stream<CallGuardEvent> get events => _stream ??= _events
      .receiveBroadcastStream()
      .map(decode)
      .where((e) => e != null)
      .cast<CallGuardEvent>();

  /// Decodes one platform event `{signal: String, atMs: int}`; unknown or
  /// malformed payloads are dropped.
  static CallGuardEvent? decode(Object? raw) {
    if (raw is! Map) return null;
    final signal = CallGuardSignal.tryParse(raw['signal']);
    final atMs = raw['atMs'];
    if (signal == null || atMs is! int) return null;
    return CallGuardEvent(
      signal,
      DateTime.fromMillisecondsSinceEpoch(atMs, isUtc: true),
    );
  }
}
