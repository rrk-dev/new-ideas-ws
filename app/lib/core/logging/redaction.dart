/// Content-free logging helpers (FND-07, `vv-privacy-security` → Logging).
///
/// The rule: at INFO and above a log line may contain only event names, IDs,
/// sizes, counts, timings and enum-like codes. Never transcript/LLM text,
/// prompts, file or folder names, vault paths, speaker names or profile field
/// values. These helpers enforce that even when a caller makes a mistake.
library;

/// Wraps user content (transcript text, LLM output, file names …) so it can
/// never be printed by accident: `toString()` only reveals the length.
///
/// The value is shown only by a DEBUG record in a debug build of the `dev`
/// flavor (see `Logger.contentLoggingAllowed`).
final class Sensitive {
  const Sensitive(this.value);

  final String value;

  @override
  String toString() => '<redacted:${value.length}>';
}

/// A safe identifier for log fields (job id, model id, step, error type).
///
/// Values that do not look like an identifier — or that look like a media /
/// document file name (`meeting_with_anna.wav`) — are replaced with
/// `<redacted-id>`.
final class LogId {
  LogId(String value) : value = isSafeId(value) ? value : redactedId;

  static const redactedId = '<redacted-id>';

  final String value;

  static final _idPattern = RegExp(r'^[A-Za-z0-9_.:\-]{1,64}$');

  /// Whether [value] is acceptable as an identifier in a log line.
  static bool isSafeId(String value) =>
      _idPattern.hasMatch(value) && !Redactor.fileName.hasMatch(value);

  @override
  String toString() => value;
}

/// Scrubs free text that ends up in a log message.
///
/// Heuristic safety net for structural leaks (paths, URIs, file names,
/// quoted/JSON text, e-mail, phone numbers). It cannot recognise free prose,
/// which is why log messages must be constants: interpolating values into a
/// message is rejected by `test/unit/log_call_guard_test.dart` (CI).
abstract final class Redactor {
  /// Longest message kept verbatim; longer text is most likely content.
  static const maxMessageLength = 160;

  static final _uri = RegExp(r'\b[A-Za-z][A-Za-z0-9+.\-]*://\S+');
  // Any token with a path separator (also catches "Anna Smith/notes" parts
  // of paths with spaces, and Windows paths). Over-redacts "3/5": fine.
  static final _pathToken = RegExp(r'''[^\s"'`]*[/\\][^\s"'`]*''');
  static final _email = RegExp(r'[\w.+\-]+@[\w\-]+\.[\w.\-]+');
  static final _phone = RegExp(r'\+?\d[\d \-().]{7,}\d');
  // Greedy on purpose: from the first to the last quote / bracket of the
  // message, so nested JSON (LLM output) cannot leave pieces between pairs.
  static final _quoted = RegExp(
    '".*"|\'.*\'|“.*”|‘.*’|«.*»|`.*`',
    dotAll: true,
  );
  static final _structured = RegExp(r'\{.*\}|\[.*\]', dotAll: true);

  /// File names with audio/text extensions (they often contain names).
  static final fileName = RegExp(
    r'[^\s/\\]+\.(?:wav|m4a|mp3|aac|ogg|opus|flac|caf|amr|3gp|webm|mp4|md|txt'
    r'|json|pdf|docx?)\b',
    caseSensitive: false,
  );

  // A media/document file name with spaces ("Call with Anna.m4a"): up to six
  // preceding words go with it.
  static final _fileWithSpaces = RegExp(
    '(?:[^\\s/\\\\<>]+ ){0,6}${fileName.pattern}',
    caseSensitive: false,
  );

  /// Returns [text] with URIs, paths, file names, e-mail addresses, phone
  /// numbers and quoted text replaced by placeholders, truncated to
  /// [maxMessageLength].
  static String redact(String text) {
    var out = text
        .replaceAll(_uri, '<uri>')
        .replaceAll(_email, '<email>')
        .replaceAll(_quoted, '<redacted>')
        .replaceAll(_structured, '<redacted>')
        .replaceAll(_pathToken, '<path>')
        .replaceAll(_fileWithSpaces, '<file>')
        .replaceAll(_phone, '<number>');
    if (out.length > maxMessageLength) {
      out =
          '${out.substring(0, maxMessageLength)}'
          '…<truncated:${out.length - maxMessageLength}>';
    }
    return out;
  }

  /// Turns a structured field value into something safe to persist.
  ///
  /// Numbers, booleans, enums, durations, dates and [LogId]s pass; plain
  /// strings are treated as content and replaced by their length; anything
  /// else is reduced to its type name. With [reveal] (debug content logging)
  /// strings and [Sensitive] values are kept.
  static Object? field(Object? value, {bool reveal = false}) => switch (value) {
    null || bool() || int() => value,
    final double d => d.isFinite ? d : d.toString(),
    final Enum e => e.name,
    final Duration d => d.inMicroseconds / 1000, // milliseconds
    final DateTime t => t.toUtc().toIso8601String(),
    final LogId id => id.value,
    final Sensitive s => reveal ? s.value : s.toString(),
    final String s => reveal ? s : '<redacted:${s.length}>',
    _ => '<redacted:${value.runtimeType}>',
  };
}
