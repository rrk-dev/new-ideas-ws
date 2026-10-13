import 'package:vv_native/vv_crash.dart';

/// Installs the native signal handler that writes a report to a pre-opened
/// file when the process dies (REL-02, `native/bridge/vv_crash.h`).
abstract interface class NativeCrashCapture {
  /// Opens/truncates [reportPath] and installs the handler. Returns `false`
  /// when native capture is unavailable (library missing, unsupported
  /// platform); the app must keep working without it.
  bool install({required String reportPath, required String appBuild});

  /// Deliberately crashes the process. Dev flavor / device verification only.
  void forceCrash();
}

/// The real handler from `libvv_native` via FFI.
class VvNativeCrashCapture implements NativeCrashCapture {
  const VvNativeCrashCapture();

  @override
  bool install({required String reportPath, required String appBuild}) {
    try {
      return VvCrash.open().install(reportPath, appBuild: appBuild) ==
          VvCrashInstallResult.ok;
    } on Object {
      return false;
    }
  }

  @override
  void forceCrash() => VvCrash.open().force(VvCrashKind.segv);
}

/// No native capture (tests, platforms without the bridge).
class NoNativeCrashCapture implements NativeCrashCapture {
  const NoNativeCrashCapture();

  @override
  bool install({required String reportPath, required String appBuild}) => false;

  @override
  void forceCrash() {}
}
