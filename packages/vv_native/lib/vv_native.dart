/// Typed access to the VaultVoice native bridge.
///
/// Only the C ABI in `native/bridge/vv_bridge.h` is exposed; heavy engine
/// work is added by the STT/LLM tasks behind the same bridge and must run on
/// native threads or a background isolate, never the UI isolate.
library;

import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:vv_native/src/llm_backend.dart';
import 'package:vv_native/src/llm_engine.dart';
import 'package:vv_native/src/loader.dart';
import 'package:vv_native/src/vv_bindings.g.dart';

export 'src/llm_backend.dart'
    show LlmBackendParams, LlmBenchResult, VvLlmException;
export 'src/llm_engine.dart'
    show LlmGenParams, LlmGenResult, LlmGeneration, LlmInfo, VvLlm;
export 'src/vv_bindings.g.dart'
    show
        VV_E_BACKEND,
        VV_E_BUSY,
        VV_E_CANCELLED,
        VV_E_INVALID_ARG,
        VV_E_MODEL_LOAD,
        VV_E_OOM,
        VV_LLM_FALLBACK_GPU_TO_CPU,
        VV_LLM_FALLBACK_KV_TO_F16,
        VV_OK;

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
  VvNative._(this._b, this._hostPath);

  /// Loads the bridge and checks its ABI version.
  factory VvNative.open({String? hostPath}) {
    final bindings = VvBindings(openVvNative(hostPath: hostPath));
    final abi = bindings.vv_abi_version();
    if (abi != expectedAbiVersion) throw VvAbiMismatch(abi);
    return VvNative._(bindings, hostPath);
  }

  final VvBindings _b;
  final String? _hostPath;

  /// Loads an LLM (LLM-04) on a background isolate. See [VvLlm].
  Future<VvLlm> loadLlm(String modelPath, LlmBackendParams params) =>
      VvLlm.load(modelPath, params, hostPath: _hostPath);

  /// JSON Schema → GBNF (LLM-05, llama.cpp converter in `vv_jsg`). Pure
  /// CPU, no model. Throws [VvLlmException] (`VV_E_INVALID_ARG`) when the
  /// text is not JSON or the schema cannot be converted.
  String jsonSchemaToGbnf(String schemaJson) => using((arena) {
    final out = arena<Pointer<Char>>();
    final rc = _b.vv_json_schema_to_gbnf(
      schemaJson.toNativeUtf8(allocator: arena).cast(),
      out,
    );
    if (rc != VV_OK) throw VvLlmException(rc);
    try {
      return out.value.cast<Utf8>().toDartString();
    } finally {
      _b.vv_free_string(out.value);
    }
  });

  /// `(total, available)` device RAM in bytes (`vv_device_memory`, LLM-07).
  (int, int) get deviceMemory => using((arena) {
    final total = arena<Uint64>();
    final avail = arena<Uint64>();
    _b.vv_device_memory(total, avail);
    return (total.value, avail.value);
  });

  /// Current and peak process memory in bytes (`vv_proc_memory`).
  (int, int) get processMemory => using((arena) {
    final cur = arena<Uint64>();
    final peak = arena<Uint64>();
    _b.vv_proc_memory(cur, peak);
    return (cur.value, peak.value);
  });

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

  /// False when this build's ggml CPU kernels need features (dotprod/i8mm)
  /// the CPU lacks: never start whisper/llama then (SIGILL), ADR-LLM-03.
  bool get cpuSupported => _b.vv_cpu_supported() == 1;

  /// `(runtime, build)` `VV_CPU_FEATURE_*` bit sets (diagnostics).
  (int, int) get cpuFeatures => using((arena) {
    final rt = arena<Int32>();
    final b = arena<Int32>();
    _b.vv_cpu_features(rt, b);
    return (rt.value, b.value);
  });

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
