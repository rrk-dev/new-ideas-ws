import 'package:vaultvoice/core/crash/crash_store.dart';
import 'package:vaultvoice/core/errors/error_boundary.dart';
import 'package:vaultvoice/core/platform/clock.dart';

/// Turns uncaught Dart errors into local, content-free report files.
///
/// Recorded: error *type*, where it was caught, the stack trace (code
/// locations; in release builds obfuscated frames that only our private
/// `--split-debug-info` symbols can decode), app build and OS version.
/// Never recorded: the error message or `toString()` — it can quote user
/// content (e.g. a `FormatException` with transcript text).
class DartCrashRecorder {
  DartCrashRecorder({
    required this.store,
    required this.appBuild,
    required this.os,
    this.clock = const SystemClock(),
    this.maxPerSession = 3,
  });

  static const header = '*** VaultVoice Dart error report v1';
  static const maxStackLines = 200;
  static const maxLineLength = 300;

  final CrashReportStore store;
  final String appBuild;
  final String os;
  final Clock clock;

  /// Stops an error loop (e.g. a failing build every frame) from filling the
  /// disk; the first reports carry the useful stack.
  final int maxPerSession;

  int _recorded = 0;
  String? _lastSignature;

  /// Writes a report; returns it, or `null` when skipped (duplicate, session
  /// cap) or when writing failed. Never throws.
  CrashReport? record(Object error, StackTrace? stack, ErrorSource source) {
    try {
      final stackText = sanitizeStack(stack);
      final signature = '${error.runtimeType}\n$stackText';
      if (_recorded >= maxPerSession || signature == _lastSignature) {
        return null;
      }
      _lastSignature = signature;
      _recorded++;
      return store.writeDart(
        format(
          errorType: error.runtimeType.toString(),
          source: source,
          stack: stackText,
        ),
      );
    } on Object {
      return null;
    }
  }

  String format({
    required String errorType,
    required ErrorSource source,
    required String stack,
  }) =>
      '$header\n'
      'app: ${_oneLine(appBuild)}\n'
      'os: ${_oneLine(os)}\n'
      'time: ${clock.now().toUtc().toIso8601String()}\n'
      'source: ${source.name}\n'
      'error_type: ${_oneLine(errorType)}\n'
      'stack:\n'
      '$stack'
      'end of report\n';

  /// Stack trace text, bounded in size. Frames are code locations only.
  static String sanitizeStack(StackTrace? stack) {
    final text = stack?.toString().trim() ?? '';
    if (text.isEmpty) return '(no stack trace)\n';
    final buf = StringBuffer();
    final lines = text.split('\n');
    for (final line in lines.take(maxStackLines)) {
      final l = line.trimRight();
      buf.writeln(
        l.length > maxLineLength ? '${l.substring(0, maxLineLength)}…' : l,
      );
    }
    if (lines.length > maxStackLines) {
      buf.writeln('… ${lines.length - maxStackLines} more lines');
    }
    return buf.toString();
  }

  static String _oneLine(String s) => s.replaceAll(RegExp(r'[\r\n]+'), ' ');
}
