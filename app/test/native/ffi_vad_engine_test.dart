@TestOn('mac-os || linux')
@Timeout(Duration(minutes: 2))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/recording/data/ffi_live_vad.dart';
import 'package:vaultvoice/features/transcription/data/ffi_vad_engine.dart';

/// Real Silero VAD through the host bridge (AUD-03): `native/build.sh host`
/// + `tools/ci/fetch_test_models.sh ggml-silero-v6.2.0.bin jfk.wav`.
String? _hostLib() {
  final fromEnv = Platform.environment['VV_NATIVE_LIB'];
  if (fromEnv != null) return fromEnv;
  final ext = Platform.isMacOS ? 'dylib' : 'so';
  final f = File('../native/build/host/libvv_native.$ext');
  return f.existsSync() ? f.absolute.path : null;
}

String _modelsDir() =>
    Platform.environment['VV_TEST_MODELS_DIR'] ??
    '${Platform.environment['HOME']}/.cache/vaultvoice/test-models';

void main() {
  final lib = _hostLib();
  final model = '${_modelsDir()}/ggml-silero-v6.2.0.bin';
  final jfk = '${_modelsDir()}/jfk.wav';
  final skip = lib == null
      ? 'run native/build.sh host first'
      : !File(model).existsSync() || !File(jfk).existsSync()
      ? 'run tools/ci/fetch_test_models.sh'
      : null;

  test('[AUD-03] FfiVadEngine: speech spans of jfk.wav; missing model is a '
      'failure, not a crash', () async {
    final engine = FfiVadEngine(hostLibPath: lib);
    addTearDown(engine.dispose);
    final spans = (await engine.speechSegments(model, jfk)).valueOrNull!;
    expect(spans, isNotEmpty);
    expect(spans.first.startMs, lessThan(1500));
    expect(await engine.speechSegments('/nope.bin', jfk), isA<Err<Object>>());
    // Still usable with the right model afterwards.
    expect((await engine.speechSegments(model, jfk)).valueOrNull, isNotEmpty);
  }, skip: skip);

  test('FfiLiveVad: null for a missing model', () async {
    expect(await FfiLiveVad.open('/nope.bin', hostPath: lib), isNull);
  }, skip: lib == null ? 'run native/build.sh host first' : null);
}
