@TestOn('mac-os || linux')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vv_native/vv_native.dart';

/// Host-side FFI test against `native/build/host` (run
/// `native/build.sh host` first; CI does this in the native-host job).
String? _hostLib() {
  final fromEnv = Platform.environment['VV_NATIVE_LIB'];
  if (fromEnv != null) return fromEnv;
  final ext = Platform.isMacOS ? 'dylib' : 'so';
  final f = File('../../native/build/host/libvv_native.$ext');
  return f.existsSync() ? f.absolute.path : null;
}

void main() {
  final lib = _hostLib();
  final skip = lib == null ? 'run native/build.sh host first' : null;

  test('[FND-06/AC2] vv_version() through Dart FFI on the host', () {
    final native = VvNative.open(hostPath: lib);
    expect(native.version, '0.1.0');
    expect(native.abiVersion, expectedAbiVersion);
    expect(native.whisperVersion, isNotEmpty);
    expect(native.ggmlVersion, isNotEmpty);
    expect(native.whisperSystemInfo, isNotEmpty);
    expect(native.llamaSystemInfo, isNotEmpty);
  }, skip: skip);

  test('[STT-02/AC2] CPU-only backend load works and lists a CPU device', () {
    final native = VvNative.open(hostPath: lib);
    expect(native.loadBackends(), 0);
    final devices = native.describeBackends();
    expect(devices.map((d) => d['type']), contains('cpu'));
    if (native.dynamicBackends) {
      // gpuMask 0 must not load any GPU module (safe fallback).
      expect(devices.map((d) => d['type']), isNot(contains('gpu')));
    }
  }, skip: skip);

  test('loading a missing library fails loudly', () {
    expect(
      () => VvNative.open(hostPath: '/nonexistent/libvv_native.so'),
      throwsA(isA<ArgumentError>()),
    );
  });

  group('LLM-02 llama.cpp backend over FFI (host)', () {
    final modelsDir = Platform.environment['VV_TEST_MODELS_DIR'];
    final model = modelsDir == null
        ? null
        : File('$modelsDir/SmolLM2-135M-Instruct-Q8_0.gguf');
    final modelSkip =
        skip ??
        (model != null && model.existsSync()
            ? null
            : 'set VV_TEST_MODELS_DIR (tools/ci/fetch_test_models.sh)');

    test('lists GPU devices and perf cores', () {
      final native = VvNative.open(hostPath: lib);
      expect(native.perfCores, greaterThanOrEqualTo(1));
      final gpus = native.gpuDevices();
      if (Platform.isMacOS) expect(gpus.first.$2, startsWith('MTL'));
    }, skip: skip);

    test('LLM-03 CPU feature guard: host build runs on host CPU', () {
      final native = VvNative.open(hostPath: lib);
      final (runtime, build) = native.cpuFeatures;
      expect(build & ~runtime, 0);
      expect(native.cpuSupported, isTrue);
    }, skip: skip);

    test('missing model -> VV_E_MODEL_LOAD', () {
      final native = VvNative.open(hostPath: lib);
      expect(
        () => native.llmBench(
          '/nonexistent/m.gguf',
          const LlmBackendParams(nCtx: 64),
          nPrompt: 8,
          nGen: 8,
        ),
        throwsA(
          isA<VvLlmException>().having((e) => e.code, 'code', VV_E_MODEL_LOAD),
        ),
      );
    }, skip: skip);

    test('GPU and CPU-only runs; CPU greedy output is deterministic', () {
      final native = VvNative.open(hostPath: lib);
      final gpu = native.llmBench(
        model!.path,
        const LlmBackendParams(nCtx: 256, nBatch: 64),
        nPrompt: 64,
        nGen: 16,
      );
      expect(gpu.nGen, 16);
      expect(gpu.decodeTps, greaterThan(0));
      expect(gpu.usedGpu, Platform.isMacOS);
      const cpuParams = LlmBackendParams(
        useGpu: false,
        nCtx: 256,
        nBatch: 64,
        nThreads: 2,
      );
      final a = native.llmBench(model.path, cpuParams, nPrompt: 64, nGen: 16);
      final b = native.llmBench(model.path, cpuParams, nPrompt: 64, nGen: 16);
      expect(a.usedGpu, isFalse);
      expect(a.fellBackToCpu, isFalse);
      expect(a.outputHash, b.outputHash);
      expect(a.toJson().keys, contains('peak_mem_bytes'));
    }, skip: modelSkip);
  });
}
