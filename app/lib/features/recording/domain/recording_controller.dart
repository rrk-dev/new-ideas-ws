import 'dart:async';

import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/audio_recorder.dart';
import 'package:vaultvoice/core/platform/call_guard.dart';
import 'package:vaultvoice/core/platform/clock.dart';
import 'package:vaultvoice/features/recording/domain/capture_backend.dart';
import 'package:vaultvoice/features/recording/domain/recording_limits.dart';
import 'package:vaultvoice/features/recording/domain/start_source.dart';

/// Lifecycle of one recording session.
enum RecordingPhase { idle, recording, paused, stopped }

/// Why a recording is paused.
enum PauseCause { user, call, audioInterruption, captureSilenced }

/// Why a recording stopped.
enum StopCause { user, maxDuration, silence }

/// Immutable snapshot of the controller.
final class RecordingState {
  const RecordingState({
    required this.phase,
    this.pauseCause,
    this.stopCause,
    this.elapsed = Duration.zero,
  });

  final RecordingPhase phase;
  final PauseCause? pauseCause;
  final StopCause? stopCause;

  /// Recorded time, paused spans excluded.
  final Duration elapsed;

  @override
  String toString() =>
      'RecordingState(${phase.name}, pause: ${pauseCause?.name}, '
      'stop: ${stopCause?.name}, $elapsed)';
}

/// The **only** entry point that may open the microphone (SEC-09,
/// ADR-SEC-09-recording-policy).
///
/// * [start] takes a [StartSource] — an enum of user-tap sources only — and
///   refuses while a call is ringing/active, while the call state is unknown
///   (fail closed) and while the app is not in the foreground.
/// * A blocking [CallGuardEvent] while recording suspends capture
///   synchronously, discarding audio from the event time on and writing a
///   gap marker. The recording then stays paused until the user taps Resume;
///   "call ended" / "interruption ended" never resume it.
/// * Long-session safeguards: automatic stop at [RecordingLimits.maxDuration]
///   and after configured continuous silence; a "Still recording" reminder
///   every [RecordingLimits.reminderInterval] while the app is backgrounded.
class RecordingController {
  RecordingController({
    required this._capture,
    required CallGuard callGuard,
    required this._clock,
    required bool Function() isAppInForeground,
    RecordingLimits? limits,
    this._reminders,
    this._tick = const Duration(seconds: 1),
  }) : _guard = callGuard,
       _isForeground = isAppInForeground,
       limits = limits ?? RecordingLimits();

  final CaptureBackend _capture;
  final CallGuard _guard;
  final Clock _clock;
  final bool Function() _isForeground;
  final RecordingReminderSink? _reminders;
  final Duration _tick;

  /// Active long-session limits.
  final RecordingLimits limits;

  final _states = StreamController<RecordingState>.broadcast();
  RecordingPhase _phase = RecordingPhase.idle;
  PauseCause? _pauseCause;
  StopCause? _stopCause;

  /// True while the microphone is being (re)opened; blocking guard events
  /// that arrive meanwhile are applied as soon as it is open.
  bool _opening = false;
  CallGuardEvent? _pendingBlock;

  StreamSubscription<CallGuardEvent>? _guardSub;
  Timer? _ticker;
  Duration _accumulated = Duration.zero;
  DateTime? _activeSince;
  late Duration _nextReminderAt;

  /// Current snapshot.
  RecordingState get state => RecordingState(
    phase: _phase,
    pauseCause: _pauseCause,
    stopCause: _stopCause,
    elapsed: elapsed,
  );

  /// Snapshots on every phase change.
  Stream<RecordingState> get states => _states.stream;

  /// Recorded time, paused spans excluded.
  Duration get elapsed => switch (_activeSince) {
    final since? => _accumulated + _clock.now().difference(since),
    null => _accumulated,
  };

  /// Starts a new recording from a user tap.
  Future<Result<void>> start(StartSource source) async {
    if (!allowedStartSources.contains(source)) {
      return _blocked(RecordingBlockReason.sourceNotAllowed);
    }
    final canStart =
        _phase == RecordingPhase.idle || _phase == RecordingPhase.stopped;
    if (!canStart || _opening) {
      return _blocked(RecordingBlockReason.invalidState);
    }
    if (!_isForeground()) return _blocked(RecordingBlockReason.notForeground);

    _opening = true;
    _pendingBlock = null;
    // Subscribe before asking so a call that starts during the check is seen.
    _guardSub = _guard.events.listen(_onGuardEvent);
    final refused = await _callCheck();
    if (refused != null) {
      _endGuardWatch();
      _opening = false;
      return _blocked(refused);
    }
    final opened = await _capture.openMicrophone();
    _opening = false;
    if (opened case Err(:final failure)) {
      _endGuardWatch();
      return Err(failure);
    }
    _accumulated = Duration.zero;
    _nextReminderAt = limits.reminderInterval;
    _stopCause = null;
    _enterRecording();
    _applyPendingBlock();
    return const Ok<void>(null);
  }

  /// User tapped Pause.
  Future<Result<void>> pause() async {
    if (_phase != RecordingPhase.recording || _opening) {
      return _blocked(RecordingBlockReason.invalidState);
    }
    _enterPaused(PauseCause.user);
    return await _capture.suspend(gap: GapKind.userPause);
  }

  /// User tapped Resume. The only way out of a pause — including a pause
  /// forced by a call.
  Future<Result<void>> resume(ResumeSource source) async {
    if (!allowedResumeSources.contains(source)) {
      return _blocked(RecordingBlockReason.sourceNotAllowed);
    }
    if (_phase != RecordingPhase.paused || _opening) {
      return _blocked(RecordingBlockReason.invalidState);
    }
    if (!_isForeground() && source != ResumeSource.recordingNotification) {
      return _blocked(RecordingBlockReason.notForeground);
    }
    _opening = true;
    _pendingBlock = null;
    final refused = await _callCheck();
    if (refused != null) {
      _opening = false;
      return _blocked(refused);
    }
    final reopened = await _capture.resumeCapture();
    _opening = false;
    if (reopened case Err(:final failure)) return Err(failure);
    _enterRecording();
    _applyPendingBlock();
    return const Ok<void>(null);
  }

  /// Stops and finalizes the recording.
  Future<Result<RecordedAudio>> stop({StopCause cause = StopCause.user}) async {
    final active =
        _phase == RecordingPhase.recording || _phase == RecordingPhase.paused;
    if (!active || _opening) {
      return _blocked(RecordingBlockReason.invalidState);
    }
    _freezeElapsed();
    _phase = RecordingPhase.stopped;
    _pauseCause = null;
    _stopCause = cause;
    _endGuardWatch();
    _emit();
    return await _capture.close();
  }

  /// Fed by VAD (AUD-03): length of the current continuous silence.
  void reportContinuousSilence(Duration silence) {
    final limit = limits.silenceAutoStop;
    if (limit == null || _phase != RecordingPhase.recording) return;
    if (silence >= limit) unawaited(stop(cause: StopCause.silence));
  }

  /// Releases timers and subscriptions.
  Future<void> dispose() async {
    _ticker?.cancel();
    _endGuardWatch();
    await _states.close();
  }

  // --- internals ------------------------------------------------------------

  Future<RecordingBlockReason?> _callCheck() async {
    final inCall = await _guard.isInCall();
    return inCall.when<RecordingBlockReason?>(
      ok: (v) => v || _pendingBlock?.signal == CallGuardSignal.callActive
          ? RecordingBlockReason.inCall
          : null,
      err: (_) => RecordingBlockReason.callGuardUnavailable,
    );
  }

  void _onGuardEvent(CallGuardEvent event) {
    // Non-blocking signals (call ended, interruption ended, unsilenced) are
    // deliberately ignored: nothing ever resumes capture automatically.
    if (!event.signal.blocksCapture) return;
    if (_opening) {
      _pendingBlock ??= event;
      return;
    }
    if (_phase != RecordingPhase.recording) return;
    _forceSuspend(event);
  }

  void _applyPendingBlock() {
    final pending = _pendingBlock;
    _pendingBlock = null;
    if (pending != null && _phase == RecordingPhase.recording) {
      _forceSuspend(pending);
    }
  }

  void _forceSuspend(CallGuardEvent event) {
    final (cause, gap) = switch (event.signal) {
      CallGuardSignal.interruptionBegan => (
        PauseCause.audioInterruption,
        GapKind.audioInterruption,
      ),
      CallGuardSignal.captureSilenced => (
        PauseCause.captureSilenced,
        GapKind.captureSilenced,
      ),
      _ => (PauseCause.call, GapKind.callInterruption),
    };
    _enterPaused(cause);
    // Called synchronously from the event: capture stops now, not on a tick.
    unawaited(_capture.suspend(gap: gap, discardFrom: event.at));
  }

  void _enterRecording() {
    _phase = RecordingPhase.recording;
    _pauseCause = null;
    _activeSince = _clock.now();
    _ticker?.cancel();
    _ticker = Timer.periodic(_tick, (_) => _onTick());
    _emit();
  }

  void _enterPaused(PauseCause cause) {
    _freezeElapsed();
    _phase = RecordingPhase.paused;
    _pauseCause = cause;
    _emit();
  }

  void _freezeElapsed() {
    _accumulated = elapsed;
    _activeSince = null;
    _ticker?.cancel();
    _ticker = null;
  }

  void _onTick() {
    if (_phase != RecordingPhase.recording) return;
    final e = elapsed;
    if (e >= limits.maxDuration) {
      unawaited(stop(cause: StopCause.maxDuration));
      return;
    }
    if (e >= _nextReminderAt) {
      while (_nextReminderAt <= e) {
        _nextReminderAt += limits.reminderInterval;
      }
      if (!_isForeground()) _reminders?.stillRecording(e);
    }
  }

  /// Stops listening; the guard sees the cancel synchronously. The returned
  /// future is not awaited (it may complete outside the caller's zone).
  void _endGuardWatch() {
    unawaited(_guardSub?.cancel());
    _guardSub = null;
  }

  void _emit() {
    if (!_states.isClosed) _states.add(state);
  }

  Err<T> _blocked<T>(RecordingBlockReason reason) =>
      Err<T>(RecordingBlockedFailure(reason));
}
