/// Typed access to the VaultVoice native bridge.
///
/// Only the C ABI in `native/bridge/vv_bridge.h` is exposed; heavy engine
/// work is added by the STT/LLM tasks behind the same bridge and must run on
/// native threads or a background isolate, never the UI isolate.
library;

import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:vv_native/src/loader.dart';
import 'package:vv_native/src/vv_bindings.g.dart';

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
  VvNative._(this._b, this.cpuBackendStatus);

  /// Loads the bridge and checks its ABI version.
  factory VvNative.open({String? hostPath}) {
    final bindings = VvBindings(openVvNative(hostPath: hostPath));
    final abi = bindings.vv_abi_version();
    if (abi != expectedAbiVersion) throw VvAbiMismatch(abi);
    // CPU backends are always safe to register (no-op in static builds);
    // GPU modules are added later by the backend policy via [loadBackends].
    return VvNative._(bindings, bindings.vv_backends_load(nullptr, 0));
  }

  final VvBindings _b;

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

  /// Performance cores (default thread count input).
  int get perfCores => _b.vv_cpu_perf_cores();
}
