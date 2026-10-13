import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/flavor.dart';
import 'package:vaultvoice/core/logging/redaction.dart';
import 'package:vaultvoice/core/platform/clock.dart';

/// Log severity, lowest first.
enum LogLevel { debug, info, warning, error }

/// One structured, already-sanitized log line.
@immutable
final class LogRecord {
  const LogRecord({
    required this.time,
    required this.level,
    required this.tag,
    required this.message,
    this.fields = const {},
  });

  /// Parses a line written by [toJsonLine]; `null` when it is not one.
  static LogRecord? tryParse(String line) {
    try {
      final json = jsonDecode(line);
      if (json is! Map<String, Object?>) return null;
      final level = LogLevel.values.asNameMap()[json['l']];
      final time = DateTime.tryParse('${json['t']}');
      final tag = json['tag'];
      final msg = json['msg'];
      final fields = json['f'] ?? const <String, Object?>{};
      if (level == null || time == null || tag is! String || msg is! String) {
        return null;
      }
      if (fields is! Map<String, Object?>) return null;
      return LogRecord(
        time: time,
        level: level,
        tag: tag,
        message: msg,
        fields: fields,
      );
    } on FormatException {
      return null;
    }
  }

  final DateTime time;
  final LogLevel level;
  final String tag;
  final String message;

  /// Sanitized values only (see [Redactor.field]).
  final Map<String, Object?> fields;

  String toJsonLine() => jsonEncode({
    't': time.toUtc().toIso8601String(),
    'l': level.name,
    'tag': tag,
    'msg': message,
    if (fields.isNotEmpty) 'f': fields,
  });
}

/// Destination of log records (file, console, memory in tests).
abstract interface class LogSink {
  void write(LogRecord record);

  Future<void> close();
}

/// Writes to `dart:developer` (IDE / `flutter logs`). Debug builds only.
class DeveloperLogSink implements LogSink {
  const DeveloperLogSink();

  @override
  void write(LogRecord record) => developer.log(
    '${record.message}${record.fields.isEmpty ? '' : ' ${record.fields}'}',
    name: 'vv.${record.tag}',
    level: switch (record.level) {
      LogLevel.debug => 500,
      LogLevel.info => 800,
      LogLevel.warning => 900,
      LogLevel.error => 1000,
    },
  );

  @override
  Future<void> close() async {}
}

/// Structured, content-free logger (FND-07).
///
/// Messages should be constant event names (`'job started'`); variable data
/// goes in `fields` as numbers, enums, durations or [LogId]s. Everything is
/// sanitized before it reaches a sink: messages via [Redactor.redact], fields
/// via [Redactor.field]. Only a DEBUG record with [contentLoggingAllowed]
/// (debug build of the `dev` flavor) may carry [Sensitive] content.
class Logger {
  Logger({
    List<LogSink> sinks = const [],
    this.minLevel = LogLevel.info,
    this.clock = const SystemClock(),
    bool contentLoggingAllowed = false,
  }) : _sinks = List.unmodifiable(sinks),
       // `kDebugMode` is a const: in release/profile builds the content
       // branch is compiled out.
       contentLoggingAllowed = kDebugMode && contentLoggingAllowed;

  /// The app logger for [flavor]: DEBUG + content logging only in a debug
  /// build of `dev`; `prod` logs INFO and above, never content.
  factory Logger.forFlavor(
    Flavor flavor, {
    required List<LogSink> sinks,
    Clock clock = const SystemClock(),
  }) {
    final dev = kDebugMode && flavor.isDev;
    return Logger(
      sinks: sinks,
      clock: clock,
      minLevel: dev ? LogLevel.debug : LogLevel.info,
      contentLoggingAllowed: dev,
    );
  }

  final List<LogSink> _sinks;
  final Clock clock;
  final LogLevel minLevel;

  /// Whether DEBUG records may show [Sensitive] values and plain strings.
  final bool contentLoggingAllowed;

  static final _tagPattern = RegExp(r'^[a-z0-9_.]{1,32}$');

  bool isEnabled(LogLevel level) => level.index >= minLevel.index;

  void debug(String tag, String message, {Map<String, Object?>? fields}) =>
      log(LogLevel.debug, tag, message, fields: fields);

  void info(String tag, String message, {Map<String, Object?>? fields}) =>
      log(LogLevel.info, tag, message, fields: fields);

  void warning(String tag, String message, {Map<String, Object?>? fields}) =>
      log(LogLevel.warning, tag, message, fields: fields);

  void error(String tag, String message, {Map<String, Object?>? fields}) =>
      log(LogLevel.error, tag, message, fields: fields);

  /// Logs a [Failure]: its type and content-free message.
  void failure(
    String tag,
    Failure failure, {
    LogLevel level = LogLevel.error,
  }) => log(
    level,
    tag,
    failure.message,
    fields: {'failure': LogId(failure.runtimeType.toString())},
  );

  void log(
    LogLevel level,
    String tag,
    String message, {
    Map<String, Object?>? fields,
  }) {
    if (!isEnabled(level)) return;
    final reveal = contentLoggingAllowed && level == LogLevel.debug;
    final record = LogRecord(
      time: clock.now(),
      level: level,
      tag: _tagPattern.hasMatch(tag) ? tag : 'untagged',
      message: reveal ? message : Redactor.redact(message),
      fields: {
        for (final MapEntry(:key, :value) in (fields ?? const {}).entries)
          (LogId.isSafeId(key) ? key : 'field'): Redactor.field(
            value,
            reveal: reveal,
          ),
      },
    );
    for (final sink in _sinks) {
      try {
        sink.write(record);
      } on Object {
        // Logging must never crash the app (or an in-progress recording).
      }
    }
  }

  Future<void> close() async {
    for (final sink in _sinks) {
      await sink.close();
    }
  }
}
