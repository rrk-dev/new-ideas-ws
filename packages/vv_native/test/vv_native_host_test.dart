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
}
