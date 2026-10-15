import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/flavor.dart';
import 'package:vaultvoice/core/logging/logger.dart';
import 'package:vaultvoice/core/logging/redaction.dart';
import 'package:vaultvoice/core/logging/rotating_file_sink.dart';

import '../fakes/fake_clock.dart';
import '../helpers/sensitive_samples.dart';

class MemorySink implements LogSink {
  final records = <LogRecord>[];

  @override
  void write(LogRecord record) => records.add(record);

  @override
  Future<void> close() async {}
}

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('vv_logs_'));
  tearDown(() => dir.deleteSync(recursive: true));

  LogRecord record(String msg, [int i = 0]) => LogRecord(
    time: DateTime.utc(2026),
    level: LogLevel.info,
    tag: 'test',
    message: '$msg $i',
  );

  group('[FND-07/AC1] rotation', () {
    test('[FND-07/AC1] log files rotate at the configured size', () {
      const config = LogRotationConfig(maxFileBytes: 1024, maxFiles: 3);
      final sink = RotatingFileSink(dir, config: config);
      final line = utf8.encode('${record('x' * 80).toJsonLine()}\n').length;
      final perFile = 1024 ~/ line;

      // Fill exactly one file: no rotation yet.
      for (var i = 0; i < perFile; i++) {
        sink.write(record('x' * 80));
      }
      expect(sink.files.map((f) => f.uri.pathSegments.last), ['vv.log']);
      expect(sink.currentFile.lengthSync(), lessThanOrEqualTo(1024));

      // The next line would exceed the cap → rotate to vv.1.log.
      sink.write(record('x' * 80, 1));
      expect(sink.files.map((f) => f.uri.pathSegments.last), [
        'vv.1.log',
        'vv.log',
      ]);

      // Keep writing: never more than maxFiles files, none above the cap.
      for (var i = 0; i < perFile * 10; i++) {
        sink.write(record('x' * 80, i));
      }
      expect(sink.files.map((f) => f.uri.pathSegments.last), [
        'vv.2.log',
        'vv.1.log',
        'vv.log',
      ]);
      for (final f in sink.files) {
        expect(f.lengthSync(), lessThanOrEqualTo(1024));
      }
      expect(dir.listSync().length, 3, reason: 'oldest file must be deleted');
    });

    test('[FND-07/AC1] rotation keeps newest lines and resumes size after '
        'restart', () async {
      const config = LogRotationConfig(maxFileBytes: 600, maxFiles: 2);
      var sink = RotatingFileSink(dir, config: config);
      for (var i = 0; i < 40; i++) {
        sink.write(record('line', i));
      }
      await sink.close();
      final last = sink.currentFile.readAsLinesSync().last;
      expect(LogRecord.tryParse(last)!.message, 'line 39');

      // A new sink (app restart) appends and respects the existing size.
      sink = RotatingFileSink(dir, config: config);
      for (var i = 40; i < 60; i++) {
        sink.write(record('line', i));
      }
      await sink.close();
      for (final f in sink.files) {
        expect(f.lengthSync(), lessThanOrEqualTo(600));
      }
      expect(sink.files, hasLength(2));
      expect(
        LogRecord.tryParse(sink.currentFile.readAsLinesSync().last)!.message,
        'line 59',
      );
    });

    test('[FND-07/AC1] an oversized record never exceeds the per-file or '
        'total cap (regression: Codex FAIL 2026-10-14)', () async {
      const config = LogRotationConfig(maxFileBytes: 256, maxFiles: 2);
      final sink = RotatingFileSink(dir, config: config);
      final logger = Logger(sinks: [sink]);
      // 100 numeric fields: one INFO line of ~1.3 kB.
      final fields = {for (var i = 0; i < 100; i++) 'count_$i': i * 1000};
      expect(
        utf8
            .encode(
              LogRecord(
                time: DateTime.utc(2026),
                level: LogLevel.info,
                tag: 'test',
                message: 'big',
                fields: fields,
              ).toJsonLine(),
            )
            .length,
        greaterThan(256),
        reason: 'the probe record must really be oversized',
      );

      // On an empty file, after a normal line, and right after a rotation.
      logger.info('test', 'big', fields: fields);
      logger.info('test', 'small');
      logger.info('test', 'big', fields: fields);
      for (var i = 0; i < 20; i++) {
        logger.info('test', 'small', fields: {'i': i});
      }
      logger.info('test', 'big', fields: fields);
      // A sink-level record whose message alone is too long (the Logger caps
      // messages at 160 chars, but other writers may not) is bounded too.
      sink
        ..write(record('m' * 2000))
        ..write(record('big'));
      await sink.close();

      var total = 0;
      for (final f in sink.files) {
        final len = f.lengthSync();
        expect(len, lessThanOrEqualTo(256), reason: f.path);
        total += len;
        // Every line stays parseable JSON-lines.
        for (final line in f.readAsLinesSync()) {
          expect(LogRecord.tryParse(line), isNotNull, reason: line);
        }
      }
      expect(total, lessThanOrEqualTo(256 * 2));
      expect(sink.files.length, lessThanOrEqualTo(2));

      // Oversized records are replaced by content-free markers that keep the
      // level, tag, original size and — when it fits — the event name.
      final records = [
        for (final f in sink.files)
          ...f.readAsLinesSync().map(LogRecord.tryParse).whereType<LogRecord>(),
      ];
      final markers = records
          .where((r) => r.fields['truncated'] == true)
          .toList();
      expect(markers, hasLength(2), reason: 'last big INFO + long message');
      final big = markers.first;
      expect(big.level, LogLevel.info);
      expect(big.tag, 'test');
      expect(big.message, 'big');
      expect(big.fields['dropped_fields'], 100);
      expect(big.fields['bytes']! as int, greaterThan(256));
      final long = markers.last;
      expect(long.message, 'record truncated');
      expect(long.fields.containsKey('dropped_fields'), isFalse);
      expect(long.fields['bytes']! as int, greaterThan(2000));
      // Logging continues normally after a marker.
      expect(records.last.message, 'big 0');
      expect(records.last.fields, isEmpty);
    });

    test(
      '[FND-07/AC1] a cap too small for even the marker drops the record',
      () async {
        const config = LogRotationConfig(maxFileBytes: 16, maxFiles: 1);
        final sink = RotatingFileSink(dir, config: config)
          ..write(record('x' * 100));
        await sink.close();
        expect(
          sink.currentFile.existsSync() ? sink.currentFile.lengthSync() : 0,
          lessThanOrEqualTo(16),
        );
      },
    );

    test('[FND-07/AC1] default cap is 5 files x 2 MB', () {
      const config = LogRotationConfig();
      expect(config.maxFileBytes, 2 * 1024 * 1024);
      expect(config.maxFiles, 5);
    });
  });

  group('[FND-07/AC1] redaction', () {
    test('[FND-07/AC1] Redactor scrubs paths, URIs, names in files, e-mail, '
        'phone and quoted text', () {
      for (final sample in [
        audioPath,
        vaultUri,
        email,
        phone,
        windowsPath,
        'loaded "$transcript"',
        "prompt '$llmOutput'",
        'file Anna_Zephyr_1on1.wav ready',
        'saved to /storage/emulated/0/Anna Zephyr/notes/today.md',
      ]) {
        final out = Redactor.redact(sample);
        expectNoSentinel(out);
      }
      expect(Redactor.redact('job started'), 'job started');
      expect(Redactor.redact('x' * 500).length, lessThan(200));
    });

    test('[FND-07/AC1] fields: plain strings and Sensitive are redacted, '
        'ids/numbers/enums pass', () {
      expect(Redactor.field(transcript), '<redacted:${transcript.length}>');
      expect(
        Redactor.field(const Sensitive(transcript)),
        '<redacted:${transcript.length}>',
      );
      expect('${const Sensitive(transcript)}', isNot(contains('Anna')));
      expect(Redactor.field(LogId('job-42')), 'job-42');
      expect(Redactor.field(LogId('Anna Zephyr.m4a')), LogId.redactedId);
      expect(Redactor.field(LogId('meeting_with_anna.wav')), LogId.redactedId);
      expect(Redactor.field(42), 42);
      expect(Redactor.field(LogLevel.warning), 'warning');
      expect(Redactor.field(const Duration(milliseconds: 1500)), 1500);
      expect(Redactor.field(Uri.parse(vaultUri)), startsWith('<redacted:'));
      expect(
        '${Redactor.field(Uri.parse(vaultUri))}',
        isNot(contains('Zephyr')),
      );
    });

    test('[FND-07/AC1] nothing sensitive reaches the log file at INFO+', () {
      final sink = RotatingFileSink(dir);
      // Every way a careless caller could leak content:
      Logger(sinks: [sink], clock: FakeClock())
        ..info('stt', 'transcribed', fields: {'text': transcript})
        ..info('stt', 'audio $audioPath', fields: {'path': audioPath})
        ..warning('export', 'write to $vaultUri', fields: {'uri': vaultUri})
        ..error(
          'llm',
          'bad json "$llmOutput"',
          fields: {'output': const Sensitive(llmOutput), 'text': transcript},
        )
        ..info('share', 'mail $email call $phone')
        ..info(
          'job',
          'job finished',
          fields: {'job': LogId('job-7'), 'ms': 1200, 'file': LogId(audioPath)},
        )
        ..failure('export', const StorageFailure('vault not writable'));
      final text = sink.currentFile.readAsStringSync();
      expectNoSentinel(text);
      // Useful, content-free data survives.
      expect(text, contains('"job":"job-7"'));
      expect(text, contains('"ms":1200'));
      expect(text, contains('StorageFailure'));
      expect(text.trim().split('\n'), hasLength(7));
    });

    test('[FND-07/AC1] content only at DEBUG in dev; prod drops DEBUG', () {
      final devSink = MemorySink();
      Logger.forFlavor(Flavor.dev, sinks: [devSink])
        ..debug('stt', 'segment', fields: {'text': const Sensitive(transcript)})
        ..info('stt', 'segment', fields: {'text': const Sensitive(transcript)});
      // Tests run in debug mode: dev may show content at DEBUG only.
      expect(devSink.records.first.fields['text'], transcript);
      expect(devSink.records.last.fields['text'], isNot(contains('Anna')));

      final prodSink = MemorySink();
      Logger.forFlavor(Flavor.prod, sinks: [prodSink])
        ..debug('stt', 'segment', fields: {'text': const Sensitive(transcript)})
        ..info('stt', 'segment', fields: {'text': const Sensitive(transcript)});
      expect(prodSink.records, hasLength(1));
      expect(prodSink.records.single.level, LogLevel.info);
      expectNoSentinel(prodSink.records.single.toJsonLine());
    });

    test('[FND-07/AC1] a failing sink never throws into the caller', () {
      final logger = Logger(sinks: [_ThrowingSink()]);
      expect(() => logger.error('app', 'boom'), returnsNormally);
    });
  });
}

class _ThrowingSink implements LogSink {
  @override
  void write(LogRecord record) => throw const FileSystemException('full');

  @override
  Future<void> close() async {}
}
