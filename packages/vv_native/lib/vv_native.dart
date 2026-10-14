/// Typed access to the VaultVoice native bridge.
///
/// Only the C ABI in `native/bridge/vv_bridge.h` is exposed; heavy engine
/// work is added by the STT/LLM tasks behind the same bridge and must run on
/// native threads or a background isolate, never the UI isolate.
library;

import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:vv_native/src/llm_backend.dart';
import 'package:vv_native/src/llm_engine.dart';
import 'package:vv_native/src/loader.dart';
import 'package:vv_native/src/vv_bindings.g.dart';

export 'package:vv_native/src/llm_backend.dart'
    show LlmBackendParams, LlmBenchResult, VvLlmException;
export 'package:vv_native/src/llm_engine.dart'
    show LlmGenParams, LlmGenResult, LlmGeneration, LlmInfo, VvLlm;
export 'package:vv_native/src/vv_bindings.g.dart'
    show
        VV_E_BACKEND,
        VV_E_BUSY,
        VV_E_CANCELLED,
        VV_E_INTERNAL,
        VV_E_INVALID_ARG,
        VV_E_IO,
        VV_E_MODEL_LOAD,
        VV_E_OOM,
        VV_GPU_METAL,
        VV_GPU_OPENCL,
        VV_GPU_VULKAN,
        VV_LLM_FALLBACK_GPU_TO_CPU,
        VV_LLM_FALLBACK_KV_TO_F16,
        VV_OK;
export 'package:vv_native/src/whisper.dart';

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
  VvNative._(this._b, this.cpuBackendStatus, this._hostPath);

  /// Loads the bridge and checks its ABI version.
  factory VvNative.open({String? hostPath}) {
    final bindings = VvBindings(openVvNative(hostPath: hostPath));
    final abi = bindings.vv_abi_version();
    if (abi != expectedAbiVersion) throw VvAbiMismatch(abi);
    // CPU backends are always safe to register (no-op in static builds);
    // GPU modules are added later by the backend policy via [loadBackends].
    return VvNative._(
      bindings,
      bindings.vv_backends_load(nullptr, 0),
      hostPath,
    );
  }

  final VvBindings _b;
  final String? _hostPath;

  /// Loads an LLM (LLM-04) on a background isolate. See [VvLlm].
  Future<VvLlm> loadLlm(String modelPath, LlmBackendParams params) =>
      VvLlm.load(modelPath, params, hostPath: _hostPath);

  /// Current and peak process memory in bytes (`vv_proc_memory`).
  (int, int) get processMemory => using((arena) {
    final cur = arena<Uint64>();
    final peak = arena<Uint64>();
    _b.vv_proc_memory(cur, peak);
    return (cur.value, peak.value);
  });

  /// `VV_*` code of the CPU backend registration done by [VvNative.open]
  /// (`VV_E_BACKEND` = no usable CPU module found).
  final int cpuBackendStatus;

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

  /// Loads the ggml backends (STT-02): the best CPU variant plus the GPU
  /// modules in [gpuMask] (`VV_GPU_*`, decided by the app's backend policy).
  /// [libDir] defaults to the directory of the native library. Returns a
  /// `VV_*` code (`VV_OK` = 0).
  int loadBackends({int gpuMask = 0, String? libDir}) => using((arena) {
    final dir = libDir == null
        ? nullptr
        : libDir.toNativeUtf8(allocator: arena).cast<Char>();
    return _b.vv_backends_load(dir, gpuMask);
  });

  /// Registered ggml devices: `[{name, type, description}]` (hardware only).
  List<Map<String, Object?>> describeBackends() => using((arena) {
    final needed = arena<Size>();
    _b.vv_backends_describe(nullptr, 0, needed);
    final cap = needed.value;
    final buf = arena<Char>(cap);
    final rc = _b.vv_backends_describe(buf, cap, nullptr);
    if (rc != VV_OK) return const <Map<String, Object?>>[];
    final list = jsonDecode(buf.cast<Utf8>().toDartString()) as List<Object?>;
    return [for (final e in list) (e! as Map).cast<String, Object?>()];
  });

  /// Whether backends are runtime-loaded modules (`VV_GGML_BACKEND_DL`).
  bool get dynamicBackends => _b.vv_backends_dynamic() == 1;

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
