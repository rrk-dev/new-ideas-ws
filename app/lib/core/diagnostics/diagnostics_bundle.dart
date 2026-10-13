import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:vaultvoice/core/app_info.dart';
import 'package:vaultvoice/core/diagnostics/job_metrics.dart';
import 'package:vaultvoice/core/flavor.dart';
import 'package:vaultvoice/core/logging/logger.dart';
import 'package:vaultvoice/core/logging/redaction.dart';
import 'package:vaultvoice/core/platform/clock.dart';

/// Non-identifying device/app facts for a diagnostics export.
@immutable
final class DeviceInfo {
  const DeviceInfo({
    required this.os,
    required this.osVersion,
    required this.processors,
    required this.locale,
    required this.dartVersion,
    required this.flavor,
    this.nativeVersions = const {},
  });

  /// Reads the facts from `dart:io` ([nativeVersions] from the bridge).
  factory DeviceInfo.current({
    required Flavor flavor,
    Map<String, String> nativeVersions = const {},
  }) => DeviceInfo(
    os: Platform.operatingSystem,
    osVersion: Platform.operatingSystemVersion,
    processors: Platform.numberOfProcessors,
    locale: Platform.localeName,
    dartVersion: Platform.version.split(' ').first,
    flavor: flavor,
    nativeVersions: nativeVersions,
  );

  final String os;
  final String osVersion;
  final int processors;
  final String locale;
  final String dartVersion;
  final Flavor flavor;

  /// Bridge / whisper.cpp / ggml versions and backend summaries.
  final Map<String, String> nativeVersions;

  Map<String, Object?> toJson() => {
    'app': kAppName,
    'flavor': flavor.name,
    'os': os,
    'os_version': osVersion,
    'processors': processors,
    'locale': locale,
    'dart': dartVersion,
    'native': nativeVersions,
  };
}

/// One file of the diagnostics zip.
@immutable
final class DiagnosticsEntry {
  const DiagnosticsEntry(this.name, this.bytes);

  /// Path inside the zip, e.g. `logs/vv.log`.
  final String name;
  final Uint8List bytes;

  /// Characters shown in the in-app preview per entry.
  static const previewChars = 4000;

  String get text => utf8.decode(bytes, allowMalformed: true);

  /// Head of the file for the preview dialog.
  String get preview => text.length <= previewChars
      ? text
      : '${text.substring(0, previewChars)}\n… '
            '(${text.length - previewChars} more characters)';
}

/// Everything the user is about to share, ready to preview and zip.
@immutable
final class DiagnosticsBundle {
  const DiagnosticsBundle(this.entries, {required this.createdAt});

  final List<DiagnosticsEntry> entries;
  final DateTime createdAt;

  int get totalBytes => entries.fold(0, (sum, e) => sum + e.bytes.length);

  DiagnosticsEntry? operator [](String name) =>
      entries.where((e) => e.name == name).firstOrNull;

  /// File name of the zip, e.g. `vaultvoice-diagnostics-20261012-093000.zip`.
  String get fileName {
    String two(int v) => v.toString().padLeft(2, '0');
    final t = createdAt.toUtc();
    return 'vaultvoice-diagnostics-${t.year}${two(t.month)}${two(t.day)}-'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}.zip';
  }

  Uint8List toZip() {
    final archive = Archive();
    for (final e in entries) {
      archive.addFile(ArchiveFile.bytes(e.name, e.bytes));
    }
    return ZipEncoder().encodeBytes(archive);
  }

  /// Writes the zip into [directory], deleting earlier exports there first.
  Future<File> writeZip(Directory directory) async {
    await directory.create(recursive: true);
    await for (final f in directory.list()) {
      final name = f.uri.pathSegments.last;
      if (f is File &&
          name.startsWith('vaultvoice-diagnostics-') &&
          name.endsWith('.zip')) {
        await f.delete();
      }
    }
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(toZip(), flush: true);
    return file;
  }
}

/// Assembles the export: logs + device info + metrics, nothing else.
///
/// Logs are re-checked on the way out (defense in depth): DEBUG records —
/// the only ones that may carry content in a `dev` debug build — and lines
/// that are not well-formed log records are dropped, and every remaining
/// message and string field passes through [Redactor.redact] again. The
/// export never reads recordings, transcripts, extractions or notes.
class DiagnosticsBundleBuilder {
  DiagnosticsBundleBuilder({
    required this.logFiles,
    required this.metrics,
    required this.deviceInfo,
    this.clock = const SystemClock(),
  });

  /// Current log files, oldest first.
  final List<File> Function() logFiles;
  final MetricsStore metrics;
  final DeviceInfo Function() deviceInfo;
  final Clock clock;

  Future<DiagnosticsBundle> build() async {
    final now = clock.now();
    final entries = <DiagnosticsEntry>[];
    var kept = 0;
    var dropped = 0;
    for (final file in logFiles()) {
      if (!file.existsSync()) continue;
      final out = StringBuffer();
      for (final line in await file.readAsLines()) {
        if (line.trim().isEmpty) continue;
        final record = LogRecord.tryParse(line);
        if (record == null || record.level == LogLevel.debug) {
          dropped++;
          continue;
        }
        out.writeln(_scrub(record).toJsonLine());
        kept++;
      }
      entries.add(_text('logs/${file.uri.pathSegments.last}', '$out'));
    }
    final all = await metrics.all();
    entries
      ..add(_json('device.json', deviceInfo().toJson()))
      ..add(
        _text(
          'metrics.jsonl',
          [for (final m in all) '${jsonEncode(m.toJson())}\n'].join(),
        ),
      )
      ..add(
        _json('manifest.json', {
          'created': now.toUtc().toIso8601String(),
          'log_records': kept,
          'log_records_dropped': dropped,
          'metrics_records': all.length,
          'contents':
              'logs (INFO+, redacted), device info, performance metrics. '
              'No audio, transcripts, extractions or notes.',
        }),
      );
    return DiagnosticsBundle(List.unmodifiable(entries), createdAt: now);
  }

  static final _placeholder = RegExp(r'^<redacted(?:-id|:[A-Za-z0-9_<>]+)>$');

  static LogRecord _scrub(LogRecord r) => LogRecord(
    time: r.time,
    level: r.level,
    tag: r.tag,
    message: Redactor.redact(r.message),
    fields: {
      for (final MapEntry(:key, :value) in r.fields.entries)
        key: switch (value) {
          // The logger only writes IDs and `<redacted…>` placeholders as
          // strings; anything else was not produced by it.
          final String s when LogId.isSafeId(s) || _placeholder.hasMatch(s) =>
            s,
          final String s => '<redacted:${s.length}>',
          num() || bool() || null => value,
          _ => '<redacted:${value.runtimeType}>',
        },
    },
  );

  static DiagnosticsEntry _text(String name, String text) =>
      DiagnosticsEntry(name, utf8.encode(text));

  static DiagnosticsEntry _json(String name, Map<String, Object?> json) =>
      _text(name, const JsonEncoder.withIndent('  ').convert(json));
}
