@TestOn('mac-os || linux')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vv_native/vv_crash.dart';

/// Host FFI test for the crash API against `native/build/host` (run
/// `native/build.sh host` first). Forced crashes are covered by the C test
/// (`vv_crash` in ctest) and `tools/crash/tests` — they would kill this
/// test runner.
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

  test('install / uninstall through Dart FFI', () {
    final dir = Directory.systemTemp.createTempSync('vv_crash_ffi_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final report = File('${dir.path}/native-current.vvcrash')
      ..writeAsStringSync('stale report from the previous run');
    final crash = VvCrash.open(hostPath: lib);

    expect(crash.install(''), VvCrashInstallResult.invalidArgument);
    expect(
      crash.install('${dir.path}/missing/dir/report'),
      VvCrashInstallResult.io,
    );
    expect(
      crash.install(report.path, appBuild: '1.0.0+1 test'),
      VvCrashInstallResult.ok,
    );
    addTearDown(crash.uninstall);
    expect(crash.isInstalled, isTrue);
    expect(crash.moduleCount, greaterThan(0));
    expect(crash.install(report.path), VvCrashInstallResult.alreadyInstalled);
    // Install truncates: an empty file means "no crash in this run".
    expect(report.lengthSync(), 0);

    crash.uninstall();
    expect(crash.isInstalled, isFalse);
  }, skip: skip);
}
