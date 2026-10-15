import 'dart:ffi';
import 'dart:io';

/// Opens the native bridge for the current platform.
///
/// [hostPath] overrides the lookup (host tests / benches point it at
/// `native/build/host/libvv_native.*` or the macOS framework binary).
///
/// macOS uses the same framework-relative name as iOS. `native/build.sh macos`
/// copies `vv_native.framework` into `packages/vv_native/macos/Frameworks`,
/// and the Flutter macOS runner embeds that into
/// `Contents/Frameworks` (rpath `@executable_path/../Frameworks`).
DynamicLibrary openVvNative({String? hostPath}) {
  if (hostPath != null) return DynamicLibrary.open(hostPath);
  if (Platform.isAndroid) return DynamicLibrary.open('libvv_native.so');
  if (Platform.isIOS || Platform.isMacOS) {
    return DynamicLibrary.open('vv_native.framework/vv_native');
  }
  throw UnsupportedError(
    'vv_native is bundled for Android, iOS, and macOS only; '
    'pass hostPath on host.',
  );
}
