// failWith mirrors the vv-testing fake contract; a setter reads poorly.
// ignore_for_file: use_setters_to_change_properties

import 'dart:async';

import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/audio_recorder.dart';

/// In-memory [AudioRecorder]; [emitLevel] simulates metering.
class FakeAudioRecorder implements AudioRecorder {
  final _levels = StreamController<double>.broadcast();
  Failure? _failure;
  bool _recording = false;
  Duration elapsed = const Duration(seconds: 3);

  void failWith(Failure failure) => _failure = failure;

  void emitLevel(double level) => _levels.add(level);

  @override
  bool get isRecording => _recording;

  @override
  Stream<double> get levels => _levels.stream;

  @override
  Future<Result<void>> start() async {
    if (_failure case final failure?) return Err(failure);
    if (_recording) return const Err(StorageFailure('already recording'));
    _recording = true;
    return const Ok<void>(null);
  }

  @override
  Future<Result<RecordedAudio>> stop() async {
    if (!_recording) return const Err(StorageFailure('not recording'));
    _recording = false;
    return Ok(RecordedAudio(path: 'fake/recording.wav', duration: elapsed));
  }
}
