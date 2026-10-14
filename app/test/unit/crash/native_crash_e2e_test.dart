@TestOn('mac-os || linux')
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/crash/crash_providers.dart';
import 'package:vaultvoice/core/crash/crash_reporting.dart';
import 'package:vaultvoice/core/crash/crash_store.dart';
import 'package:vaultvoice/core/crash/native_crash_capture.dart';
import 'package:vaultvoice/core/diagnostics/diagnostics_providers.dart';
import 'package:vaultvoice/core/logging/logger.dart';
import 'package:vaultvoice/core/platform/app_paths.dart';
import 'package:vaultvoice/core/platform/share_service.dart';

import '../../fakes/fake_share_service.dart';
import '../../helpers/test_container.dart';

/// Full REL-02 chain on the host: the real C signal handler crashes a
/// process and writes into the app's crash directory → next "launch"
/// harvests it → the user shares it (share sheet) → the shared file is
/// symbolicated with tools/crash/symbolize.py against private symbols.
void main() {
  final root = Directory.current.parent.path; // tests run in app/
  final cc = ['clang', 'cc', 'gcc'].firstWhere(
    (c) => Process.runSync('which', [c]).exitCode == 0,
    orElse: () => '',
  );
  final python = Process.runSync('which', ['python3']).exitCode == 0;
  final skip = cc.isEmpty
      ? 'no C compiler on PATH'
      : !python
      ? 'python3 not on PATH'
      : null;

  test('[REL-02/AC1] forced native crash → harvested → shared file → '
      'symbolicated report', () async {
    final tmp = Directory.systemTemp.createTempSync('vv_crash_e2e_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final build = Directory('${tmp.path}/symbols')..createSync();

    // 1. "Release build" with private symbols kept aside.
    final objects = <String>[];
    for (final src in [
      '$root/native/bridge/vv_crash.c',
      '$root/native/tests/crash_test.c',
    ]) {
      final obj = '${build.path}/${src.split('/').last}.o';
      final r = Process.runSync(cc, [
        '-g',
        '-O0',
        '-fno-omit-frame-pointer',
        '-I$root/native/bridge',
        '-c',
        src,
        '-o',
        obj,
      ]);
      expect(r.exitCode, 0, reason: '${r.stderr}');
      objects.add(obj);
    }
    final exe = '${build.path}/vv_crash_test';
    expect(Process.runSync(cc, ['-g', ...objects, '-o', exe]).exitCode, 0);
    if (Platform.isMacOS) {
      expect(Process.runSync('dsymutil', [exe]).exitCode, 0);
    }

    // 2. Previous run: the handler writes into the app's live report file.
    final paths = AppPaths(
      root: Directory('${tmp.path}/vv'),
      temp: Directory('${tmp.path}/tmp'),
    );
    final store = CrashReportStore(paths.crashReports)..ensureDirectory();
    final crashed = Process.runSync(exe, [
      'crash',
      '1',
      store.currentNativeFile.path,
    ]);
    expect(crashed.exitCode, anyOf(-11, -10, 139, 138));
    expect(store.currentNativeFile.lengthSync(), greaterThan(0));

    // 3. Next launch: harvest before re-arming the handler.
    final crash = CrashReporting.start(
      directory: paths.crashReports,
      native: const NoNativeCrashCapture(),
      appBuild: '1.0.0+1 prod',
      logger: Logger(),
      os: 'host',
    );
    final pending = crash.store.list();
    expect(pending.single.kind, CrashKind.native);

    // 4. User reviews and shares it (same notifier the Share button uses).
    final share = FakeShareService();
    final container = createContainer(
      overrides: [
        appPathsProvider.overrideWithValue(paths),
        crashReportStoreProvider.overrideWithValue(crash.store),
        shareServiceProvider.overrideWithValue(share),
      ],
    );
    final outcome = await container
        .read(crashReportsProvider.notifier)
        .share(pending.single);
    expect(outcome, ShareOutcome.shared);
    final sharedPath = share.shared.single.path;
    expect(share.shared.single.mimeType, 'text/plain');
    expect(sharedPath, endsWith('.vvcrash.txt'));
    // Only the user-shared copy exists now; the stored report is gone.
    expect(container.read(crashReportsProvider), isEmpty);

    // 5. Developer symbolicates the shared file with the private symbols.
    final inbox = File('${tmp.path}/inbox/report.txt')
      ..parent.createSync()
      ..writeAsBytesSync(File(sharedPath).readAsBytesSync());
    final sym = Process.runSync('python3', [
      '$root/tools/crash/symbolize.py',
      inbox.path,
      '--symbols',
      build.path,
    ]);
    expect(sym.exitCode, 0, reason: '${sym.stderr}');
    final out = sym.stdout as String;
    final faultLine =
        File('$root/native/bridge/vv_crash.c')
            .readAsLinesSync()
            .indexWhere((l) => l.contains('*p = 42;')) +
        1;
    final frame0 = out.split('\n').firstWhere((l) => l.contains('#00 pc'));
    if (!Platform.isMacOS && !frame0.contains('->')) {
      markTestSkipped('no llvm-symbolizer/addr2line on this host');
      return;
    }
    expect(frame0, contains('vv_crash_force_segv'));
    expect(frame0, contains('vv_crash.c:$faultLine'));
    expect(out, contains('crash_test_level1'));
  }, skip: skip);
}
