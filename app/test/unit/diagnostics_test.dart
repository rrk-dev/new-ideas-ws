import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/diagnostics/diagnostics_bundle.dart';
import 'package:vaultvoice/core/diagnostics/diagnostics_exporter.dart';
import 'package:vaultvoice/core/diagnostics/job_metrics.dart';
import 'package:vaultvoice/core/flavor.dart';
import 'package:vaultvoice/core/logging/logger.dart';
import 'package:vaultvoice/core/logging/redaction.dart';
import 'package:vaultvoice/core/logging/rotating_file_sink.dart';
import 'package:vaultvoice/core/platform/share_service.dart';

import '../fakes/fake_clock.dart';
import '../fakes/fake_share_service.dart';
import '../helpers/sensitive_samples.dart';

class _Battery implements BatteryProbe {
  _Battery(this.levels);

  final List<int> levels;

  @override
  Future<int?> levelPercent() async => levels.removeAt(0);
}

class _Memory implements MemoryProbe {
  @override
  int? peakRssBytes() => 512 * 1024 * 1024;
}

void main() {
  late Directory dir;
  late FakeClock clock;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('vv_diag_');
    clock = FakeClock(DateTime.utc(2026, 10, 12, 9, 30));
  });
  tearDown(() => dir.deleteSync(recursive: true));

  group('job metrics', () {
    test('[FND-07/AC2] recorder captures RTF, tokens/s, peak RAM, battery '
        'delta and thermal states per job', () async {
      final store = JsonlMetricsStore(File('${dir.path}/m/metrics.jsonl'));
      final recorder = JobMetricsRecorder(
        store: store,
        clock: clock,
        battery: _Battery([80, 77, 77, 76]),
        memory: _Memory(),
      );
      final session = await recorder.start('job-1', 'transcribe');
      clock.advance(const Duration(seconds: 30));
      session
        ..thermalState('nominal')
        ..thermalState('nominal')
        ..thermalState('fair');
      final m = await session.finish(audioDuration: const Duration(minutes: 2));
      expect(m.realTimeFactor, 0.25);
      expect(m.batteryDeltaPercent, 3);
      expect(m.peakRssBytes, 512 * 1024 * 1024);
      expect(m.thermalStates, ['nominal', 'fair']);

      final llm = await recorder.start('job-1', 'extract');
      clock.advance(const Duration(seconds: 10));
      final l = await llm.finish(
        promptTokens: 2000,
        prefillTime: const Duration(seconds: 4),
        generatedTokens: 256,
        decodeTime: const Duration(seconds: 8),
      );
      expect(l.prefillTokensPerSecond, 500);
      expect(l.decodeTokensPerSecond, 32);

      // Persisted and parsed back.
      final all = await store.all();
      expect(all, hasLength(2));
      expect(all.first.realTimeFactor, 0.25);
      expect(all.last.decodeTokensPerSecond, 32);
    });

    test(
      '[FND-07/AC2] metrics store is bounded and never stores names',
      () async {
        final store = JsonlMetricsStore(
          File('${dir.path}/metrics.jsonl'),
          maxRecords: 3,
        );
        for (var i = 0; i < 5; i++) {
          await store.add(
            JobMetrics(
              jobId: i == 4 ? 'Anna Zephyr.m4a' : 'job-$i',
              step: 'transcribe',
              startedAt: DateTime.utc(2026),
              wallTime: Duration(seconds: i),
            ),
          );
        }
        final all = await store.all();
        expect(all.map((m) => m.jobId), ['job-2', 'job-3', LogId.redactedId]);
        expectNoSentinel(store.file.readAsStringSync());
      },
    );
  });

  group('diagnostics export', () {
    Future<DiagnosticsBundle> buildBundle() async {
      final logDir = Directory('${dir.path}/logs');
      final sink = RotatingFileSink(
        logDir,
        config: const LogRotationConfig(maxFileBytes: 2048, maxFiles: 3),
      );
      // A dev debug build: DEBUG may carry content in the log file …
      final logger = Logger.forFlavor(Flavor.dev, sinks: [sink], clock: clock);
      for (var i = 0; i < 20; i++) {
        logger
          ..info('job', 'job started', fields: {'job': LogId('job-$i')})
          ..debug(
            'stt',
            'segment',
            fields: {'text': const Sensitive(transcript)},
          )
          ..debug('llm', 'raw output $llmOutput');
      }
      logger.warning(
        'export',
        'write failed $audioPath',
        fields: {'uri': vaultUri},
      );
      await sink.close();
      // … and a corrupted / foreign line must not slip through either.
      sink.currentFile.writeAsStringSync(
        '$transcript\n',
        mode: FileMode.append,
      );
      expect(sink.files.length, greaterThan(1), reason: 'rotated logs too');
      expect(
        sink.files.map((f) => f.readAsStringSync()).join(),
        contains('Zephyr'),
        reason: 'precondition: dev debug content is in the raw log files',
      );

      final metrics = InMemoryMetricsStore();
      await metrics.add(
        JobMetrics(
          jobId: 'job-1',
          step: 'transcribe',
          startedAt: DateTime.utc(2026),
          wallTime: const Duration(seconds: 30),
          audioDuration: const Duration(minutes: 2),
          peakRssBytes: 1000,
        ),
      );
      return await DiagnosticsBundleBuilder(
        logFiles: () => sink.files,
        metrics: metrics,
        deviceInfo: () => DeviceInfo.current(
          flavor: Flavor.dev,
          nativeVersions: const {'bridge': '0.1.0'},
        ),
        clock: clock,
      ).build();
    }

    test('[FND-07/AC2] export contains logs + device info + metrics and no '
        'transcript content', () async {
      final bundle = await buildBundle();
      final zipFile = await bundle.writeZip(Directory('${dir.path}/out'));
      expect(
        zipFile.uri.pathSegments.last,
        'vaultvoice-diagnostics-20261012-093000.zip',
      );

      final archive = ZipDecoder().decodeBytes(zipFile.readAsBytesSync());
      final files = {
        for (final f in archive.files)
          f.name: utf8.decode(f.readBytes()!, allowMalformed: true),
      };
      expect(
        files.keys,
        containsAll(['device.json', 'metrics.jsonl', 'manifest.json']),
      );
      final logNames = files.keys.where((n) => n.startsWith('logs/'));
      expect(logNames, containsAll(['logs/vv.log', 'logs/vv.1.log']));

      // Logs: INFO+ records present, DEBUG content and garbage dropped.
      final logs = logNames.map((n) => files[n]!).join();
      expect(logs, contains('"msg":"job started"'));
      expect(logs, contains('"job":"job-19"'));
      expect(logs, isNot(contains('"l":"debug"')));

      // Device info + metrics.
      final device = jsonDecode(files['device.json']!) as Map<String, Object?>;
      expect(device['app'], 'VaultVoice');
      expect(device['os'], Platform.operatingSystem);
      expect(device['native'], {'bridge': '0.1.0'});
      final metric =
          jsonDecode(files['metrics.jsonl']!.trim()) as Map<String, Object?>;
      expect(metric['rtf'], 0.25);
      final manifest =
          jsonDecode(files['manifest.json']!) as Map<String, Object?>;
      expect(manifest['log_records_dropped'], greaterThan(0));
      expect(manifest['metrics_records'], 1);

      // No transcript / LLM / path content anywhere in the zip.
      files.values.forEach(expectNoSentinel);
      // Only the four kinds of files: nothing else is ever added.
      expect(
        files.keys.every(
          (n) =>
              n.startsWith('logs/') ||
              ['device.json', 'metrics.jsonl', 'manifest.json'].contains(n),
        ),
        isTrue,
      );
    });

    test('[FND-07/AC2] export scrubs fields that were not written by the '
        'logger', () async {
      final logDir = Directory('${dir.path}/logs')..createSync();
      // A line in the log format but not produced by Logger (e.g. an older
      // app version or a manual edit).
      final foreign = LogRecord(
        time: DateTime.utc(2026),
        level: LogLevel.info,
        tag: 'x',
        message: 'saved "$transcript"',
        fields: const {'text': transcript, 'n': 3},
      );
      File('${logDir.path}/vv.log')
          .writeAsStringSync('${foreign.toJsonLine()}\n');
      final bundle = await DiagnosticsBundleBuilder(
        logFiles: () => [File('${logDir.path}/vv.log')],
        metrics: InMemoryMetricsStore(),
        deviceInfo: () => DeviceInfo.current(flavor: Flavor.prod),
        clock: clock,
      ).build();
      final log = bundle['logs/vv.log']!.text;
      expectNoSentinel(log);
      expect(log, contains('"n":3'));
    });

    test('[FND-07/AC2] exporter zips into app temp storage, replaces old '
        'exports and hands the zip to the share sheet', () async {
      final bundle = await buildBundle();
      final out = Directory('${dir.path}/export')..createSync();
      File('${out.path}/vaultvoice-diagnostics-old.zip').writeAsStringSync('x');
      final share = FakeShareService();
      final exporter = DiagnosticsExporter(
        builder: DiagnosticsBundleBuilder(
          logFiles: () => const [],
          metrics: InMemoryMetricsStore(),
          deviceInfo: () => DeviceInfo.current(flavor: Flavor.prod),
        ),
        shareService: share,
        exportDirectory: out,
        logger: Logger(),
      );
      final outcome = await exporter.share(bundle);
      expect(outcome, ShareOutcome.shared);
      expect(share.shared.single.mimeType, 'application/zip');
      expect(out.listSync().map((f) => f.uri.pathSegments.last), [
        'vaultvoice-diagnostics-20261012-093000.zip',
      ]);
      expect(share.shared.single.path, endsWith('-093000.zip'));
    });
  });
}
