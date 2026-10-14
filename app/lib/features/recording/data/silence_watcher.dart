import 'dart:async';
import 'dart:typed_data';

import 'package:vaultvoice/core/logging/logger.dart';
import 'package:vaultvoice/features/recording/domain/audio_format.dart';
import 'package:vaultvoice/features/recording/domain/recording_controller.dart';
import 'package:vaultvoice/features/recording/domain/silence_monitor.dart';

/// Live PCM of the open capture (16 kHz mono PCM16 blocks as written).
abstract interface class LivePcmSource {
  Stream<Uint8List> get pcm;
}

/// One streaming-VAD result: windows analysed / of which speech.
typedef VadCounts = ({int windows, int speech});

/// Streaming VAD running off the UI isolate (`VvVadStream`).
abstract interface class LiveVad {
  void feed(Int16List pcm);

  /// One result per [feed], in order.
  Stream<VadCounts> get results;

  Future<void> close();
}

/// Auto-pause / auto-stop after continuous silence (AUD-03), driven by a
/// streaming VAD over the recording's own PCM.
///
/// SEC-09: this class can only call [RecordingController.pauseForSilence]
/// and [RecordingController.stop] — it never starts or resumes a recording.
/// It never opens the microphone either: it only listens to audio the user
/// is already recording. While a silence pause lasts, the stop deadline
/// keeps running on the wall clock (the microphone is closed then).
class SilenceWatcher {
  SilenceWatcher({
    required this.controller,
    required this.pcm,
    required this.policy,
    required this.openVad,
    this.feedBlock = const Duration(seconds: 1),
    Logger? logger,
  }) : _log = logger;

  final RecordingController controller;
  final LivePcmSource pcm;

  /// Reads the user's silence settings at the start of each recording.
  final Future<SilencePolicy> Function() policy;

  /// Loads the streaming VAD; null when no VAD model is installed.
  final Future<LiveVad?> Function() openVad;

  /// PCM is batched to this length per VAD call.
  final Duration feedBlock;
  final Logger? _log;

  static const _tag = 'silence';

  StreamSubscription<RecordingState>? _states;
  StreamSubscription<Uint8List>? _pcmSub;
  StreamSubscription<VadCounts>? _resultsSub;
  LiveVad? _vad;
  SilenceMonitor? _monitor;
  Timer? _pausedStop;
  final _buffer = BytesBuilder(copy: false);
  RecordingPhase _phase = RecordingPhase.idle;
  int _session = 0;

  /// Starts watching the controller.
  void attach() {
    _states ??= controller.states.listen(_onState);
  }

  Future<void> dispose() async {
    await _states?.cancel();
    _states = null;
    await _end();
  }

  void _onState(RecordingState s) {
    final previous = _phase;
    _phase = s.phase;
    switch (s.phase) {
      case RecordingPhase.recording:
        _pausedStop?.cancel();
        if (previous == RecordingPhase.idle ||
            previous == RecordingPhase.stopped) {
          unawaited(_begin());
        } else if (previous == RecordingPhase.paused) {
          // A user tap resumed: silence counts from zero again.
          _monitor?.restart();
        }
      case RecordingPhase.paused:
        _buffer.clear();
        _armPausedStop(s.pauseCause);
      case RecordingPhase.stopped || RecordingPhase.idle:
        unawaited(_end());
    }
  }

  Future<void> _begin() async {
    await _end();
    final session = ++_session;
    final p = await policy();
    if (!p.enabled) return;
    final vad = await openVad();
    if (vad == null) {
      _log?.info(_tag, 'silence detection off: no VAD model');
      return;
    }
    // The recording may have ended while the model loaded.
    if (session != _session || _phase == RecordingPhase.stopped) {
      await vad.close();
      return;
    }
    _vad = vad;
    _monitor = SilenceMonitor(p);
    _resultsSub = vad.results.listen(_onResult, onError: (Object _) {});
    _pcmSub = pcm.pcm.listen(_onPcm);
    _log?.info(
      _tag,
      'silence detection on',
      fields: {
        'pause_s': p.autoPauseAfter?.inSeconds,
        'stop_s': p.autoStopAfter?.inSeconds,
      },
    );
  }

  Future<void> _end() async {
    _session++;
    _pausedStop?.cancel();
    _pausedStop = null;
    await _pcmSub?.cancel();
    _pcmSub = null;
    await _resultsSub?.cancel();
    _resultsSub = null;
    _buffer.clear();
    _monitor = null;
    final vad = _vad;
    _vad = null;
    await vad?.close();
  }

  void _onPcm(Uint8List block) {
    if (_phase != RecordingPhase.recording) return;
    _buffer.add(block);
    final want = AudioFormat.samplesFor(feedBlock) * AudioFormat.bytesPerSample;
    if (_buffer.length < want) return;
    final bytes = _buffer.takeBytes();
    final samples = Int16List(bytes.length ~/ 2);
    final view = ByteData.sublistView(bytes);
    for (var i = 0; i < samples.length; i++) {
      samples[i] = view.getInt16(i * 2, Endian.little);
    }
    _vad?.feed(samples);
  }

  void _onResult(VadCounts r) {
    final monitor = _monitor;
    if (monitor == null || _phase != RecordingPhase.recording) return;
    switch (monitor.add(r.windows, r.speech)) {
      case SilenceAction.pause:
        _log?.info(_tag, 'auto-pause after silence');
        unawaited(controller.pauseForSilence());
      case SilenceAction.stop:
        _log?.info(_tag, 'auto-stop after silence');
        unawaited(controller.stop(cause: StopCause.silence));
      case null:
        break;
    }
  }

  /// During a silence pause the stop deadline keeps running.
  void _armPausedStop(PauseCause? cause) {
    _pausedStop?.cancel();
    final monitor = _monitor;
    final stopAfter = monitor?.policy.autoStopAfter;
    if (cause != PauseCause.silence || monitor == null || stopAfter == null) {
      return;
    }
    final left = stopAfter - monitor.silence;
    _pausedStop = Timer(left.isNegative ? Duration.zero : left, () {
      if (controller.state.phase == RecordingPhase.paused &&
          controller.state.pauseCause == PauseCause.silence) {
        _log?.info(_tag, 'auto-stop after silence (paused)');
        unawaited(controller.stop(cause: StopCause.silence));
      }
    });
  }
}
