import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/crash/crash_reporting.dart';
import 'package:vaultvoice/core/crash/crash_store.dart';
import 'package:vaultvoice/core/crash/dart_crash_recorder.dart';
import 'package:vaultvoice/core/crash/native_crash_capture.dart';
import 'package:vaultvoice/core/errors/error_boundary.dart';
import 'package:vaultvoice/core/flavor.dart';
import 'package:vaultvoice/core/logging/logger.dart';

import '../../fakes/fake_clock.dart';
import '../../helpers/sensitive_samples.dart';

/// Fake handler that behaves like `vv_crash_install`: truncates the file.
class _RecordingNativeCapture implements NativeCrashCapture {
  String? installedAt;
  String? contentAtInstall;
  bool result = true;

  @override
  bool install({required String reportPath, required String appBuild}) {
    final f = File(reportPath);
    contentAtInstall = f.existsSync() ? f.readAsStringSync() : null;
    installedAt = reportPath;
    f.writeAsStringSync('');
    return result;
  }

  @override
  void forceCrash() {}
}

class _MemorySink implements LogSink {
  final records = <LogRecord>[];

  @override
  void write(LogRecord record) => records.add(record);

  @override
  Future<void> close() async {}
}

const _nativeReport =
    '*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***\n'
    'VaultVoice native crash report v1\n'
    'signal 11 (SIGSEGV), code 1, fault addr 0x0000000000000000\n'
    'backtrace:\n'
    '    #00 pc 0000000000001f40  libvv_native.so (BuildId: ab)\n'
    'end of report\n';

void main() {
  late Directory dir;
  late FakeClock clock;
  late CrashReportStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('vv_crash_');
    clock = FakeClock(DateTime.utc(2026, 10, 13, 10, 15, 0, 123));
    store = CrashReportStore(Directory('${dir.path}/crash'), clock: clock)
      ..ensureDirectory();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  group('CrashReportStore', () {
    test('empty or missing live file harvests nothing', () {
      expect(store.harvestNative(), isNull);
      store.currentNativeFile.writeAsStringSync('');
      expect(store.harvestNative(), isNull);
      expect(store.list(), isEmpty);
    });

    test('harvests a non-empty native report under a timestamped name', () {
      store.currentNativeFile
        ..writeAsStringSync(_nativeReport)
        ..setLastModifiedSync(DateTime.utc(2026, 10, 12, 8, 30, 1, 5));
      final r = store.harvestNative()!;
      expect(r.kind, CrashKind.native);
      expect(r.name, 'native-20261012T083001005Z.vvcrash');
      expect(r.createdAt, DateTime.utc(2026, 10, 12, 8, 30, 1, 5));
      expect(r.readText(), _nativeReport);
      expect(store.currentNativeFile.existsSync(), isFalse);
      expect(store.list(), [r]);
    });

    test('list is newest first, excludes the live file and markers', () {
      final a = store.writeDart('a');
      clock.advance(const Duration(seconds: 1));
      final b = store.writeDart('b');
      store.currentNativeFile.writeAsStringSync('live');
      File('${store.directory.path}/notes.txt').writeAsStringSync('x');
      expect(store.list(), [b, a]);
      expect(a.name, 'dart-20261013T101500123Z.vvdart');
    });

    test('same timestamp gets a unique name', () {
      final a = store.writeDart('a');
      final b = store.writeDart('b');
      expect(a.name, isNot(b.name));
      expect(store.list(), hasLength(2));
    });

    test('markSeen / unseen / delete', () {
      final a = store.writeDart('a');
      expect(store.unseen(), [a]);
      store.markSeen(a);
      expect(store.unseen(), isEmpty);
      expect(store.list().single.seen, isTrue);
      store.delete(a);
      expect(store.list(), isEmpty);
      expect(store.directory.listSync(), isEmpty, reason: 'marker removed');
    });

    test('keeps at most maxReports (oldest pruned)', () {
      final small = CrashReportStore(store.directory, clock: clock);
      final created = <CrashReport>[];
      for (var i = 0; i < small.maxReports + 3; i++) {
        created.add(small.writeDart('$i'));
        clock.advance(const Duration(minutes: 1));
      }
      final kept = small.list();
      expect(kept, hasLength(small.maxReports));
      expect(kept.last, created[3]);
    });
  });

  group('DartCrashRecorder', () {
    DartCrashRecorder recorder() => DartCrashRecorder(
      store: store,
      appBuild: '1.2.3+45 prod',
      os: 'ios 18.1',
      clock: clock,
    );

    test('records type, source and stack — never the message', () {
      final r = recorder().record(
        const FormatException('$transcript $audioPath $email'),
        StackTrace.current,
        ErrorSource.platform,
      )!;
      final text = r.readText();
      expect(text, startsWith(DartCrashRecorder.header));
      expect(text, contains('app: 1.2.3+45 prod'));
      expect(text, contains('source: platform'));
      expect(text, contains('error_type: FormatException'));
      expect(text, contains('crash_store_test.dart'), reason: 'stack frames');
      expect(text.trimRight(), endsWith('end of report'));
      expectNoSentinel(text);
    });

    test('missing stack, huge stack lines and line count are bounded', () {
      final rec = recorder();
      final none = rec.record(StateError('x'), null, ErrorSource.flutter)!;
      expect(none.readText(), contains('(no stack trace)'));
      final long = StackTrace.fromString(
        List.generate(500, (i) => '#$i ${'f' * 1000}').join('\n'),
      );
      final text = rec
          .record(ArgumentError('y'), long, ErrorSource.flutter)!
          .readText();
      expect(text, contains('… 300 more lines'));
      expect(
        text.split('\n').every((l) => l.length <= 301 + 1),
        isTrue,
        reason: 'lines truncated',
      );
    });

    test('duplicates and errors beyond the session cap are skipped', () {
      final rec = recorder();
      final stack = StackTrace.current;
      expect(
        rec.record(StateError('a'), stack, ErrorSource.flutter),
        isNotNull,
      );
      expect(rec.record(StateError('b'), stack, ErrorSource.flutter), isNull);
      expect(rec.record(TypeError(), stack, ErrorSource.flutter), isNotNull);
      expect(
        rec.record(RangeError('c'), stack, ErrorSource.flutter),
        isNotNull,
      );
      expect(
        rec.record(UnsupportedError('d'), null, ErrorSource.flutter),
        isNull,
      );
      expect(store.list(), hasLength(3));
    });

    test('never throws when the directory is gone', () {
      store.directory.deleteSync(recursive: true);
      File(store.directory.path).writeAsStringSync('not a dir');
      expect(
        recorder().record(StateError('x'), null, ErrorSource.flutter),
        isNull,
      );
    });
  });

  group('CrashReporting.start', () {
    test('harvests the previous native report before arming the handler', () {
      store.currentNativeFile.writeAsStringSync(_nativeReport);
      final native = _RecordingNativeCapture();
      final sink = _MemorySink();
      final crash = CrashReporting.start(
        directory: store.directory,
        native: native,
        appBuild: CrashBuildInfo.describe(Flavor.prod),
        logger: Logger(sinks: [sink]),
        os: 'test',
        clock: clock,
      );
      expect(native.installedAt, crash.store.currentNativeFile.path);
      expect(native.contentAtInstall, isNull, reason: 'moved aside first');
      expect(crash.nativeInstalled, isTrue);
      final reports = crash.store.list();
      expect(reports.single.kind, CrashKind.native);
      expect(reports.single.readText(), _nativeReport);
      final ready = sink.records.singleWhere(
        (r) => r.message == 'crash capture ready',
      );
      expect(ready.fields, {
        'native': true,
        'harvested_native': true,
        'pending': 1,
      });
    });

    test('works without native capture and records Dart errors', () {
      final crash = CrashReporting.start(
        directory: store.directory,
        native: const NoNativeCrashCapture(),
        appBuild: '0.0.0+0 dev',
        logger: Logger(),
        os: 'test',
        clock: clock,
      );
      expect(crash.nativeInstalled, isFalse);
      crash.recordDart(StateError(transcript), null, ErrorSource.flutter);
      expect(crash.store.list().single.kind, CrashKind.dart);
      expectNoSentinel(crash.store.list().single.readText());
    });

    test('a broken crash directory never breaks startup', () {
      File('${dir.path}/blocked').writeAsStringSync('file, not a directory');
      final sink = _MemorySink();
      final crash = CrashReporting.start(
        directory: Directory('${dir.path}/blocked'),
        native: _RecordingNativeCapture(),
        appBuild: 'x',
        logger: Logger(sinks: [sink]),
        os: 'test',
      );
      expect(crash.nativeInstalled, isFalse);
      expect(
        sink.records.map((r) => r.message),
        contains('crash capture setup failed'),
      );
    });
  });

  group('installErrorBoundary(onCrash:)', () {
    late FlutterExceptionHandler? savedFlutter;
    late ErrorCallback? savedPlatform;

    setUp(() {
      savedFlutter = FlutterError.onError;
      savedPlatform = PlatformDispatcher.instance.onError;
    });
    tearDown(() {
      FlutterError.onError = savedFlutter;
      PlatformDispatcher.instance.onError = savedPlatform;
    });

    test('passes error, stack and source; a failing sink is contained', () {
      final got = <(Type, StackTrace?, ErrorSource)>[];
      installErrorBoundary(
        onCrash: (e, s, src) => got.add((e.runtimeType, s, src)),
      );
      final stack = StackTrace.current;
      expect(
        PlatformDispatcher.instance.onError!(StateError('x'), stack),
        isTrue,
      );
      FlutterError.onError!(
        FlutterErrorDetails(exception: ArgumentError('y'), stack: stack),
      );
      expect(got, [
        (StateError, stack, ErrorSource.platform),
        (ArgumentError, stack, ErrorSource.flutter),
      ]);

      installErrorBoundary(onCrash: (_, _, _) => throw StateError('sink'));
      expect(
        PlatformDispatcher.instance.onError!(StateError('x'), stack),
        isTrue,
      );
    });
  });
}
