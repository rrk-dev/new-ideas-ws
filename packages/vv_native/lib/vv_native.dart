/// Typed access to the VaultVoice native bridge.
///
/// Only the C ABI in `native/bridge/vv_bridge.h` is exposed; heavy engine
/// work is added by the STT/LLM tasks behind the same bridge and must run on
/// native threads or a background isolate, never the UI isolate.
library;

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
}
