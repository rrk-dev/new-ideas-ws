import 'dart:ffi';
import 'dart:io';

/// Opens the native bridge for the current platform.
///
/// [hostPath] overrides the lookup (host tests / benches point it at
/// `native/build/host/libvv_native.*`).
DynamicLibrary openVvNative({String? hostPath}) {
  if (hostPath != null) return DynamicLibrary.open(hostPath);
  if (Platform.isAndroid) return DynamicLibrary.open('libvv_native.so');
  if (Platform.isIOS) {
    return DynamicLibrary.open('vv_native.framework/vv_native');
  }
  throw UnsupportedError(
    'vv_native is only bundled for Android and iOS; pass hostPath on host.',
  );
}
