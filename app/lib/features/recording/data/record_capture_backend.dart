import 'dart:async';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/repositories/recordings_repository.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/logging/logger.dart';
import 'package:vaultvoice/core/platform/audio_recorder.dart';
import 'package:vaultvoice/core/platform/clock.dart';
import 'package:vaultvoice/core/platform/id_generator.dart';
import 'package:vaultvoice/features/recording/data/recording_chunk_writer.dart';
import 'package:vaultvoice/features/recording/data/silence_watcher.dart';
import 'package:vaultvoice/features/recording/data/wav_chunk_codec.dart';
import 'package:vaultvoice/features/recording/domain/audio_chunk_codec.dart';
import 'package:vaultvoice/features/recording/domain/audio_format.dart';
import 'package:vaultvoice/features/recording/domain/audio_processing.dart';
import 'package:vaultvoice/features/recording/domain/audio_session_monitor.dart';
import 'package:vaultvoice/features/recording/domain/capture_backend.dart';
import 'package:vaultvoice/features/recording/domain/level_meter.dart';
import 'package:vaultvoice/features/recording/domain/pcm_converter.dart';
import 'package:vaultvoice/features/recording/domain/pcm_mic_source.dart';
import 'package:vaultvoice/features/recording/domain/recording_session.dart';
import 'package:vaultvoice/features/recording/domain/software_agc.dart';
import 'package:vaultvoice/features/recording/domain/storage_policy.dart';

/// The real [CaptureBackend] (AUD-01): microphone PCM from a [PcmMicSource]
/// (the `record` package) → [PcmConverter] (only when the platform did not
/// deliver 16 kHz mono) → [RecordingChunkWriter] (rolling chunk files through
/// the [AudioChunkCodec] seam + `recordings`/`audio_chunks`/`markers` rows).
///
/// * Called only by `RecordingController`, after its SEC-09 checks.
/// * [suspend] stops accepting audio **synchronously** (before any await), so
///   nothing captured after a call event is written; audio received after
///   `discardFrom − discardMargin` is removed from the chunk.
/// * Everything is flushed to disk at least every [flushInterval] (≤ 1 s,
///   AUD-07) and the recording row stays `recording`/`inProgress` until
///   [close] marks it `recorded`.
/// * Free space: refuse to start below the [StoragePolicy] minimum, warn,
///   and raise [CaptureNotice.lowStorageStop] below the stop threshold.
class RecordCaptureBackend
    implements
        CaptureBackend,
        LivePcmSource,
        AudioLevelSource,
        ActiveRecording {
  RecordCaptureBackend({
    required this._mic,
    required RecordingsRepository recordings,
    required this._paths,
    required this._disk,
    required this._clock,
    required this._ids,
    this._codec = const WavChunkCodec(),
    this._storage = const StoragePolicy(),
    this.chunkDuration = AudioFormat.defaultChunkDuration,
    this.flushInterval = const Duration(seconds: 1),
    this.discardMargin = defaultDiscardMargin,
    this._request = const MicRequest(),
    this._audioSession = const NoAudioSessionMonitor(),
    Future<ResolvedAudioProcessing> Function()? processing,
    Logger? logger,
  }) : assert(
         flushInterval <= const Duration(seconds: 1),
         'AUD-07 needs a flush at least every second',
       ),
       _repo = recordings,
       _resolveProcessing = processing,
       _log = logger;

  /// Extra audio dropped before a call event to cover delivery latency.
  // PRODUCT-DECISION: 250 ms (conservative: losing a quarter second of the
  // user's own speech is preferred over keeping any call audio).
  static const defaultDiscardMargin = Duration(milliseconds: 250);

  final PcmMicSource _mic;
  final RecordingsRepository _repo;
  final Future<StoragePaths> Function() _paths;
  final DiskSpaceProbe _disk;
  final Clock _clock;
  final IdGenerator _ids;
  final AudioChunkCodec _codec;
  final StoragePolicy _storage;
  final Logger? _log;
  final AudioSessionMonitor _audioSession;

  /// Resolves the user's AGC/NS/raw settings (AUD-02) before each open;
  /// null = no processing (AUD-01 behaviour).
  final Future<ResolvedAudioProcessing> Function()? _resolveProcessing;
  ResolvedAudioProcessing _processing = ResolvedAudioProcessing.none;
  SoftwareAgc? _agc;
  final _meter = LevelMeter();
  final _levels = StreamController<AudioLevel>.broadcast();
  StreamSubscription<AudioSessionEvent>? _sessionSub;

  final Duration chunkDuration;
  final Duration flushInterval;
  final Duration discardMargin;

  MicRequest _request;
  final _notices = StreamController<CaptureNotice>.broadcast();
  final _pcm = StreamController<Uint8List>.broadcast();

  _Session? _session;
  bool _accepting = false;
  // Cancelled in _closeMic().
  // ignore: cancel_subscriptions
  StreamSubscription<MicEvent>? _micSub;
  PcmConverter _converter = _contractConverter();
  DateTime? _lastReceivedAt;
  Timer? _flushTimer;
  Timer? _storageTimer;
  Future<void> _queue = Future<void>.value();

  static const _tag = 'recording';

  /// Id of the open recording, if any.
  @override
  String? get recordingId => _session?.id;

  /// Recorded duration of the open recording (gaps excluded).
  @override
  Duration get recorded => _session?.writer.recorded ?? Duration.zero;

  /// The microphone request used for the next open/resume.
  MicRequest get request => _request;

  /// Inputs the user can pick (built-in, wired, Bluetooth HFP, USB).
  Future<Result<List<AudioInputDevice>>> inputDevices() => _mic.inputDevices();

  /// Selects the input for the next open/resume (null = platform default).
  /// Never opens the microphone.
  void selectInput(AudioInputDevice? device) {
    _request = _request.withDevice(device);
  }

  /// Live input level of the open capture, one reading per 50 ms of audio
  /// (≥ 15 Hz meter, AUD-02); [AudioLevel.silent] when capture suspends.
  @override
  Stream<AudioLevel> get levels => _levels.stream;

  /// Processing applied to the current capture segment.
  ResolvedAudioProcessing get processing => _processing;

  @override
  Stream<CaptureNotice> get notices => _notices.stream;

  /// Contract-format (16 kHz mono PCM16) blocks as they are written, for
  /// live analysis (AUD-03 silence VAD). Only emits while listened to;
  /// listeners can never influence capture.
  @override
  Stream<Uint8List> get pcm => _pcm.stream;

  @override
  Future<Result<void>> openMicrophone() async {
    if (_session != null) {
      return const Err(UnexpectedFailure('capture already open'));
    }
    final paths = await _paths();
    final free = await _disk.freeBytes(paths.root);
    var warn = false;
    switch (free) {
      case Ok(:final value):
        switch (_storage.beforeStart(value)) {
          case StorageVerdict.refuse || StorageVerdict.stop:
            _log?.warning(_tag, 'start refused: low storage');
            return const Err(StorageFailure('low storage'));
          case StorageVerdict.warn:
            warn = true;
          case StorageVerdict.ok:
            break;
        }
      case Err():
        // PRODUCT-DECISION: an unknown free-space value does not block
        // recording (IO errors still stop it); the next check retries.
        _log?.warning(_tag, 'free space unknown');
    }
    if (!await _mic.hasPermission()) {
      return const Err(PermissionFailure('microphone'));
    }
    final id = _ids.next();
    final created = await _repo.create(
      RecordingsCompanion.insert(
        id: id,
        createdAt: _clock.now(),
        status: RecordingStatus.recording,
        source: RecordingSource.mic,
      ),
    );
    if (created case Err(:final failure)) return Err(failure);
    final session = _Session(
      id,
      RecordingChunkWriter(
        recordingId: id,
        paths: paths,
        codec: _codec,
        recordings: _repo,
        chunkDuration: chunkDuration,
      ),
      paths,
    );
    _session = session;
    final opened = await _openMic(session);
    if (opened case Err(:final failure)) {
      _session = null;
      await _repo.deleteById(id);
      return Err(failure);
    }
    _sessionSub = _audioSession.events.listen(_onSessionEvent);
    _log?.info(_tag, 'capture opened', fields: {'codec': _codec.id});
    if (warn) _notices.add(CaptureNotice.lowStorageWarning);
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> suspend({
    required GapKind gap,
    DateTime? discardFrom,
  }) async {
    final session = _session;
    if (session == null || !session.micOpen) return const Ok<void>(null);
    // Synchronous, before any await: nothing delivered from now on is kept.
    _accepting = false;
    session.micOpen = false;
    final discard = discardFrom == null
        ? 0
        : _samplesSince(discardFrom.subtract(discardMargin));
    _stopTimers();
    await _closeMic();
    // The resampler tail belongs to the discarded span after a call event.
    final tail = _dsp(_converter.flush());
    _silenceMeter();
    final keepTail = discardFrom == null;
    final writer = session.writer;
    final ended = await _serial(() async {
      if (keepTail && tail.isNotEmpty) {
        final r = await writer.append(tail);
        if (r case Err()) return r;
      }
      return await writer.endSegment(discardSamples: discard, gap: gap);
    });
    await _updateRow(session, RecordingStatus.inProgress);
    _log?.info(
      _tag,
      'capture suspended',
      fields: {'gap': gap, 'discarded_ms': AudioFormat.msOf(discard)},
    );
    return ended;
  }

  @override
  Future<Result<void>> resumeCapture() async {
    final session = _session;
    if (session == null) {
      return const Err(UnexpectedFailure('no capture open'));
    }
    if (session.micOpen) return const Ok<void>(null);
    final free = await _disk.freeBytes(session.paths.root);
    if (free case Ok(:final value)
        when _storage.beforeStart(value) == StorageVerdict.refuse) {
      return const Err(StorageFailure('low storage'));
    }
    final opened = await _openMic(session);
    if (opened case Err()) return opened;
    await _updateRow(session, RecordingStatus.recording);
    return const Ok<void>(null);
  }

  @override
  Future<Result<RecordedAudio>> close({
    StopCause cause = StopCause.user,
  }) async {
    final session = _session;
    if (session == null) {
      return const Err(UnexpectedFailure('no capture open'));
    }
    _accepting = false;
    final wasOpen = session.micOpen;
    session.micOpen = false;
    _stopTimers();
    await _closeMic();
    final tail = wasOpen ? _dsp(_converter.flush()) : Uint8List(0);
    _silenceMeter();
    final writer = session.writer;
    final ended = await _serial(() async {
      if (tail.isNotEmpty) {
        final r = await writer.append(tail);
        if (r case Err()) return r;
      }
      return await writer.endSegment();
    });
    _session = null;
    await _sessionSub?.cancel();
    _sessionSub = null;
    await _updateRow(
      session,
      RecordingStatus.recorded,
      stopReason: stopReasonOf(cause),
    );
    _log?.info(
      _tag,
      'capture closed',
      fields: {
        'duration_ms': writer.recorded.inMilliseconds,
        'chunks': writer.chunkCount,
        'cause': cause,
      },
    );
    if (ended case Err(:final failure)) return Err(failure);
    return Ok(
      RecordedAudio(
        path: writer.relativeDir,
        duration: writer.recorded,
        recordingId: session.id,
      ),
    );
  }

  /// Completes when every queued chunk write has finished.
  @visibleForTesting
  Future<void> get idle => _queue;

  /// Releases the notice stream (provider disposal).
  Future<void> dispose() async {
    await _sessionSub?.cancel();
    _stopTimers();
    await _closeMic();
    await _notices.close();
    await _pcm.close();
    await _levels.close();
  }

  // --- internals ------------------------------------------------------------

  Future<Result<void>> _openMic(_Session session) async {
    await _applyProcessing();
    final opened = await _mic.open(_request);
    switch (opened) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final events):
        _converter = _contractConverter();
        _lastReceivedAt = null;
        _meter.reset();
        _agc = _processing.softwareAgc ? SoftwareAgc() : null;
        session.writer.beginSegment();
        session.micOpen = true;
        _accepting = true;
        _micSub = events.listen(_onMic);
        _startTimers(session);
        return const Ok<void>(null);
    }
  }

  void _onMic(MicEvent event) {
    if (!_accepting) return; // suspended: drop everything still in flight
    final session = _session;
    if (session == null) return;
    switch (event) {
      case MicData(:final bytes, :final receivedAt):
        _lastReceivedAt = receivedAt;
        _append(session, _dsp(_converter.convert(bytes)));
      case MicFormatChanged(:final format):
        final tail = _converter.flush();
        _append(session, _dsp(tail));
        _converter = PcmConverter(
          inRate: format.sampleRate,
          inChannels: format.channels,
        );
        _log?.info(
          _tag,
          'mic format adjusted',
          fields: {'rate': format.sampleRate, 'channels': format.channels},
        );
      case MicInterrupted():
        _notices.add(CaptureNotice.interrupted);
      case MicFailed():
        _notices.add(CaptureNotice.captureFailed);
    }
  }

  /// Software AGC (when on) + level metering of a contract-format block.
  Uint8List _dsp(Uint8List pcm) {
    if (pcm.isEmpty) return pcm;
    final agc = _agc;
    final out = agc == null ? pcm : agc.process(pcm);
    if (_levels.hasListener) {
      _meter.add(out, input: pcm).forEach(_levels.add);
    }
    return out;
  }

  Future<void> _applyProcessing() async {
    final resolve = _resolveProcessing;
    if (resolve == null) return;
    try {
      _processing = await resolve();
    } on Object catch (e) {
      // Settings unreadable: record without processing rather than not at all.
      _processing = ResolvedAudioProcessing.none;
      _log?.warning(
        _tag,
        'audio processing settings unavailable',
        fields: {'error': e.runtimeType},
      );
    }
    _request = _request.withProcessing(_processing);
    _log?.info(
      _tag,
      'audio processing',
      fields: {
        'agc': _processing.autoGain,
        'ns': _processing.noiseSuppress,
        'vpio': _processing.echoCancel,
        'sw_agc': _processing.softwareAgc,
      },
    );
  }

  void _silenceMeter() {
    if (!_levels.isClosed) _levels.add(AudioLevel.silent);
  }

  /// iOS audio-session changes (AUD-04): an engine configuration change or a
  /// media-services reset stops the platform input — ask the controller to
  /// reopen it. Plain route changes are only logged (device kinds only).
  void _onSessionEvent(AudioSessionEvent event) {
    _log?.info(
      _tag,
      'audio session event',
      fields: {'kind': event.kind, 'inputs': event.inputs.length},
    );
    if (event.kind == AudioSessionEventKind.routeChanged) return;
    if (_accepting) _notices.add(CaptureNotice.inputRestartRequired);
  }

  void _append(_Session session, Uint8List pcm) {
    if (pcm.isEmpty) return;
    if (_pcm.hasListener && _accepting) _pcm.add(pcm);
    unawaited(
      _serial(() => session.writer.append(pcm)).then((r) {
        if (r case Err() when _accepting) {
          _notices.add(CaptureNotice.captureFailed);
        }
      }),
    );
  }

  int _samplesSince(DateTime from) {
    final last = _lastReceivedAt;
    if (last == null) return 0;
    final d = last.difference(from);
    return d.isNegative ? 0 : AudioFormat.samplesFor(d);
  }

  void _startTimers(_Session session) {
    _stopTimers();
    _flushTimer = Timer.periodic(flushInterval, (_) {
      unawaited(_flush(session));
    });
    _storageTimer = Timer.periodic(_storage.checkInterval, (_) {
      unawaited(_checkStorage(session));
    });
  }

  void _stopTimers() {
    _flushTimer?.cancel();
    _storageTimer?.cancel();
    _flushTimer = null;
    _storageTimer = null;
  }

  Future<void> _flush(_Session session) async {
    final r = await _serial(session.writer.flush);
    if (r case Err() when _accepting) {
      _notices.add(CaptureNotice.captureFailed);
      return;
    }
    await _repo.updateFields(
      session.id,
      RecordingsCompanion(
        durationMs: Value(session.writer.recorded.inMilliseconds),
      ),
    );
  }

  Future<void> _checkStorage(_Session session) async {
    final free = await _disk.freeBytes(session.paths.root);
    if (free case Ok(:final value) when _accepting) {
      switch (_storage.whileRecording(value)) {
        case StorageVerdict.stop || StorageVerdict.refuse:
          _log?.warning(_tag, 'low storage: stopping');
          _notices.add(CaptureNotice.lowStorageStop);
        case StorageVerdict.warn:
          if (!session.warned) {
            session.warned = true;
            _notices.add(CaptureNotice.lowStorageWarning);
          }
        case StorageVerdict.ok:
          break;
      }
    }
  }

  Future<void> _closeMic() async {
    final sub = _micSub;
    _micSub = null;
    await sub?.cancel();
    await _mic.close();
  }

  Future<void> _updateRow(
    _Session session,
    RecordingStatus status, {
    StopReason? stopReason,
  }) async {
    final r = await _repo.updateFields(
      session.id,
      RecordingsCompanion(
        status: Value(status),
        durationMs: Value(session.writer.recorded.inMilliseconds),
        stopReason: stopReason == null
            ? const Value.absent()
            : Value(stopReason),
      ),
    );
    if (r case Err(:final failure)) {
      _log?.error(_tag, 'recording row update failed', fields: {'f': failure});
    }
  }

  /// Runs [op] after every previously queued op (chunk IO is sequential).
  Future<Result<void>> _serial(Future<Result<void>> Function() op) {
    final done = Completer<Result<void>>();
    _queue = _queue.then((_) async {
      try {
        done.complete(await op());
      } on Object catch (e) {
        done.complete(Err(UnexpectedFailure(e.runtimeType.toString())));
      }
    });
    return done.future;
  }

  static PcmConverter _contractConverter() => PcmConverter(
    inRate: AudioFormat.sampleRate,
    inChannels: AudioFormat.channels,
  );
}

/// Persisted stop reason for a controller [StopCause].
StopReason stopReasonOf(StopCause cause) => switch (cause) {
  StopCause.user => StopReason.user,
  StopCause.maxDuration => StopReason.maxDuration,
  StopCause.silence => StopReason.silence,
  StopCause.lowStorage => StopReason.lowStorage,
};

final class _Session {
  _Session(this.id, this.writer, this.paths);

  final String id;
  final RecordingChunkWriter writer;
  final StoragePaths paths;
  bool micOpen = false;
  bool warned = false;
}
