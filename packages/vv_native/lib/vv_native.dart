/// Typed access to the VaultVoice native bridge.
///
/// Only the C ABI in `native/bridge/vv_bridge.h` is exposed; heavy engine
/// work is added by the STT/LLM tasks behind the same bridge and must run on
/// native threads or a background isolate, never the UI isolate.
library;

import 'package:ffi/ffi.dart';
import 'package:vv_native/src/llm_backend.dart';
import 'package:vv_native/src/loader.dart';
import 'package:vv_native/src/vv_bindings.g.dart';

export 'src/llm_backend.dart'
    show LlmBackendParams, LlmBenchResult, VvLlmException;
export 'src/vv_bindings.g.dart'
    show
        VV_E_BACKEND,
        VV_E_INVALID_ARG,
        VV_E_MODEL_LOAD,
        VV_E_OOM,
        VV_LLM_FALLBACK_GPU_TO_CPU,
        VV_LLM_FALLBACK_KV_TO_F16;

/// ABI revision this Dart code was generated against (`VV_ABI_VERSION`).
const int expectedAbiVersion = 1;

/// Thrown when the loaded library's ABI differs from [expectedAbiVersion].
class VvAbiMismatch implements Exception {
  const VvAbiMismatch(this.actual);

  final int actual;

  @override
  String toString() =>
      'VvAbiMismatch(expected $expectedAbiVersion, got $actual)';
}

/// Loaded native bridge.
class VvNative {
  VvNative._(this._b);

  /// Loads the bridge and checks its ABI version.
  factory VvNative.open({String? hostPath}) {
    final bindings = VvBindings(openVvNative(hostPath: hostPath));
    final abi = bindings.vv_abi_version();
    if (abi != expectedAbiVersion) throw VvAbiMismatch(abi);
    return VvNative._(bindings);
  }

  final VvBindings _b;

  int get abiVersion => _b.vv_abi_version();

  /// Bridge semver, e.g. `0.1.0`.
  String get version => _b.vv_version().cast<Utf8>().toDartString();

  String get whisperVersion =>
      _b.vv_whisper_version().cast<Utf8>().toDartString();

  String get ggmlVersion => _b.vv_ggml_version().cast<Utf8>().toDartString();

  /// CPU/GPU backend summary from whisper.cpp (diagnostics only).
  String get whisperSystemInfo =>
      _b.vv_whisper_system_info().cast<Utf8>().toDartString();

  /// CPU/GPU backend summary from llama.cpp (diagnostics only).
  String get llamaSystemInfo =>
      _b.vv_llama_system_info().cast<Utf8>().toDartString();

  /// Performance CPU cores (thread count default for llama.cpp/whisper.cpp).
  int get perfCores => _b.vv_cpu_perf_cores();

  /// GPU devices ggml registered: `(index, name, description)`, e.g.
  /// `(0, 'MTL0', 'Apple A17 Pro GPU')`. Diagnostics/allowlisting only.
  List<(int, String, String)> gpuDevices() => listGpuDevices(_b);

  /// Loads [modelPath] with [params], prefills [nPrompt] synthetic tokens and
  /// decodes [nGen] greedy tokens (LLM-02/LLM-03 device benchmark). Blocking:
  /// run inside `Isolate.run`. Throws [VvLlmException] with a `VV_E_*` code.
  LlmBenchResult llmBench(
    String modelPath,
    LlmBackendParams params, {
    required int nPrompt,
    required int nGen,
  }) => runLlmBench(_b, modelPath, params, nPrompt: nPrompt, nGen: nGen);
}
