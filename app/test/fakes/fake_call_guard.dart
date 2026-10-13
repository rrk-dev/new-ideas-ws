import 'dart:async';

import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/call_guard.dart';

/// Scriptable [CallGuard]: set [inCall] / [unavailable], push events with
/// [emit].
class FakeCallGuard implements CallGuard {
  final _events = StreamController<CallGuardEvent>.broadcast(sync: true);

  bool inCall = false;

  /// When true, [isInCall] fails (state unknown).
  bool unavailable = false;

  /// Runs inside [isInCall] before it answers (to inject races).
  void Function()? onQuery;

  int queries = 0;

  bool get hasListener => _events.hasListener;

  void emit(CallGuardSignal signal, DateTime at) {
    if (signal == CallGuardSignal.callActive) inCall = true;
    if (signal == CallGuardSignal.callEnded) inCall = false;
    _events.add(CallGuardEvent(signal, at));
  }

  @override
  Future<Result<bool>> isInCall() async {
    queries++;
    onQuery?.call();
    if (unavailable) {
      return const Err(UnexpectedFailure('MissingPluginException'));
    }
    return Ok(inCall);
  }

  @override
  Stream<CallGuardEvent> get events => _events.stream;
}
