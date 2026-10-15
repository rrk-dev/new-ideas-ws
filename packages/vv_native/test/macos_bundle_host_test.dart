@TestOn('mac-os')
library;

import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vv_native/src/loader.dart';
import 'package:vv_native/src/vv_bindings.g.dart';
import 'package:vv_native/vv_native.dart';

/// Built library the loader should open. Prefers the FND-10 framework, then
/// the host dylib, so the assertion does not need a Flutter macOS bundle.
String? _builtLibrary() {
  final fromEnv = Platform.environment['VV_NATIVE_LIB'];
  if (fromEnv != null && File(fromEnv).existsSync()) return fromEnv;
  const candidates = <String>[
    '../../native/build/macos/vv_native.framework/vv_native',
    '../../native/build/macos/vv_native.framework/Versions/A/vv_native',
    '../../native/build/host/libvv_native.dylib',
  ];
  for (final rel in candidates) {
    final file = File(rel);
    if (file.existsSync()) return file.absolute.path;
  }
  return null;
}

File? _macosBundleBinary() {
  const candidates = <String>[
    '../../native/build/macos/vv_native.framework/vv_native',
    '../../native/build/macos/vv_native.framework/Versions/A/vv_native',
  ];
  for (final rel in candidates) {
    final file = File(rel);
    if (file.existsSync()) return file;
  }
  return null;
}

void main() {
  final lib = _builtLibrary();
  final skip = lib == null
      ? 'run native/build.sh host or native/build.sh macos first'
      : null;

  test(
    '[FND-10/AC1] FFI loader opens the macOS library and vv_version is 0.1.0',
    () {
      final path = lib;
      expect(path, isNotNull);
      // Bindings only: VvNative.open also registers backends, which a library
      // built before those symbols existed cannot answer. vv_version is the
      // stable ABI this task must not change.
      final bindings = VvBindings(openVvNative(hostPath: path));
      expect(bindings.vv_version().cast<Utf8>().toDartString(), '0.1.0');
      expect(bindings.vv_abi_version(), expectedAbiVersion);
      final info = Process.runSync('file', [path!]);
      expect(info.exitCode, 0, reason: info.stderr.toString());
      expect(info.stdout.toString(), contains('arm64'));
    },
    skip: skip,
  );

  test(
    '[FND-10/AC3] VERSIONS.md lists the macOS arm64 framework size',
    () {
      final bin = _macosBundleBinary();
      expect(bin, isNotNull, reason: 'run native/build.sh macos first');
      final rows = File('../../native/VERSIONS.md')
          .readAsStringSync()
          .split('\n')
          .where((line) => line.contains('macOS app arm64'))
          .toList();
      expect(rows, hasLength(1));
      expect(rows.single, contains('${bin!.lengthSync()}'));
      expect(rows.single, isNot(contains('not measured')));
    },
    skip: _macosBundleBinary() == null
        ? 'run native/build.sh macos and record the size first'
        : null,
  );
}
