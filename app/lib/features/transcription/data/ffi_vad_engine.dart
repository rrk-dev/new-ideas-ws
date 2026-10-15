import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/native_failures.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/vad_engine.dart';
import 'package:vv_native/vv_native.dart';

/// [VadEngine] on `vv_vad_*` (AUD-03). The Silero model (~1 MB, CPU) stays
/// loaded per model path until [dispose]. Calls are synchronous native work
/// (~2 ms per second of audio on a laptop): use it from the pipeline worker
/// isolate only, never from the UI isolate.
class FfiVadEngine implements VadEngine {
  FfiVadEngine({this.hostLibPath, this.params = const VvVadParams()});

  /// Host tests/tools only.
  final String? hostLibPath;
  final VvVadParams params;

  VvVad? _vad;
  String? _modelPath;

  @override
  Future<Result<List<SpeechSpan>>> speechSegments(
    String modelPath,
    String wavPath,
  ) async {
    try {
      if (_vad == null || _modelPath != modelPath) {
        _vad?.dispose();
        _vad = VvVad.open(modelPath, params: params, hostPath: hostLibPath);
        _modelPath = modelPath;
      }
      final segs = _vad!.segments([VvAudioRange(wavPath)]);
      return Ok([for (final s in segs) SpeechSpan(s.startMs, s.endMs)]);
    } on VvVadException catch (e) {
      if (e.operation == 'create') {
        _vad = null;
        _modelPath = null;
      }
      return Err(failureFromVvCode(e.code, operation: 'vad ${e.operation}'));
    } on Object catch (e) {
      return Err(UnexpectedFailure(e.runtimeType.toString()));
    }
  }

  @override
  Future<void> dispose() async {
    _vad?.dispose();
    _vad = null;
    _modelPath = null;
  }
}
