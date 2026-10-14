/// Native crash capture (REL-02): installs the async-signal-safe handler in
/// `native/bridge/vv_crash.c`, which writes a minimal report (signal, code
/// addresses, module build ids — no content) to an app-private file.
///
/// Separate Dart library from `vv_native.dart` (it must be usable before the
/// engines load); the bindings are the shared `vv_bindings.g.dart` generated
/// from the single `ffigen.yaml` (ADR-INT-W2-integration).
library;

import 'package:ffi/ffi.dart';
import 'package:vv_native/src/loader.dart';
import 'package:vv_native/src/vv_bindings.g.dart';

/// How [VvCrash.force] crashes the process.
enum VvCrashKind {
  /// Write through a null pointer (SIGSEGV / SIGBUS).
  segv(VV_CRASH_FORCE_SEGV),

  /// `abort()` (SIGABRT).
  abort(VV_CRASH_FORCE_ABORT),

  /// `__builtin_trap()` (SIGTRAP / SIGILL).
  trap(VV_CRASH_FORCE_TRAP);

  VvCrashKind(this.code);

  final int code;
}

/// Result of [VvCrash.install].
enum VvCrashInstallResult {
  ok,
  invalidArgument,
  io,
  alreadyInstalled,
  internal;

  static VvCrashInstallResult fromCode(int code) => switch (code) {
    VV_CRASH_OK => ok,
    VV_CRASH_E_INVALID_ARG => invalidArgument,
    VV_CRASH_E_IO => io,
    VV_CRASH_E_BUSY => alreadyInstalled,
    _ => internal,
  };
}

/// Thin wrapper over the `vv_crash_*` C functions.
class VvCrash {
  VvCrash._(this._b);

  /// Loads the bridge library (same loader as `VvNative.open`).
  factory VvCrash.open({String? hostPath}) =>
      VvCrash._(VvBindings(openVvNative(hostPath: hostPath)));

  final VvBindings _b;

  /// Opens [reportPath] (truncating it) and installs the signal handlers.
  /// Harvest the previous run's report before calling this.
  ///
  /// [appBuild] identifies the build (e.g. `1.0.0+42 prod`); never content.
  VvCrashInstallResult install(String reportPath, {String appBuild = ''}) =>
      using((arena) {
        final code = _b.vv_crash_install(
          reportPath.toNativeUtf8(allocator: arena).cast(),
          appBuild.toNativeUtf8(allocator: arena).cast(),
        );
        return VvCrashInstallResult.fromCode(code);
      });

  /// Restores the previous handlers and closes the report file.
  void uninstall() => _b.vv_crash_uninstall();

  bool get isInstalled => _b.vv_crash_is_installed() == 1;

  /// Modules snapshotted at install time (diagnostics only).
  int get moduleCount => _b.vv_crash_module_count();

  /// Crashes the process on purpose. Dev builds / tests only.
  void force(VvCrashKind kind) => _b.vv_crash_force(kind.code);
}
