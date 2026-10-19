import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/export/domain/filename_sanitizer.dart';
import 'package:vaultvoice/features/templates/domain/markdown_sanitizer.dart'
    show slugify;

/// Default note path pattern (vv-markdown-vault-export).
const String kDefaultFilenamePattern =
    '{{date:YYYY-MM-DD}}-{{profile}}-{{slug}}.md';

/// Values a filename pattern can use.
class FilenameValues {
  const FilenameValues({
    required this.recordingId,
    required this.createdAt,
    required this.profileId,
    this.title,
  });

  final String recordingId;

  /// Recording start, in the zone the user sees (local time).
  final DateTime createdAt;
  final String profileId;

  /// Note title (extraction `title`, else the recording title); may be
  /// null — `{{title}}`/`{{slug}}` then render empty.
  final String? title;
}

/// A rendered note location: [folder] (`''` = vault root) + [file].
class NotePath {
  const NotePath(this.folder, this.file);

  final String folder;
  final VaultFileName file;

  String get path => join(file.name);

  /// The path with collision suffix `-n`.
  String withSuffix(int n) => join(file.withSuffix(n));

  String join(String name) => folder.isEmpty ? name : '$folder/$name';
}

sealed class _Part {
  const _Part();
}

final class _Literal extends _Part {
  const _Literal(this.text);

  final String text;
}

final class _Token extends _Part {
  const _Token(this.name, this.arg);

  final String name;
  final String? arg;
}

/// Date format tokens allowed in `{{date:FMT}}`.
final RegExp _dateToken = RegExp('YYYY|MM|DD|HH|mm|ss');

/// Characters allowed between date tokens.
final RegExp _dateSeparators = RegExp(r'^[-_. ]*$');

/// Separators dropped next to a token that renders empty.
const String _joiners = '-_. ';

/// A parsed filename pattern (own token syntax, **not** Mustache):
/// `{{date:FMT}}` (FMT from `YYYY MM DD HH mm ss` and `- _ .` / space),
/// `{{date}}` (= `YYYY-MM-DD`), `{{time}}` (= `HHmm`), `{{title}}`,
/// `{{slug}}` (slugified title, ≤ 60 chars), `{{profile}}`, `{{id}}`
/// (first 8 characters of the recording id). A literal `/` starts a
/// sub-folder; token values can never create folders.
class FilenamePattern {
  FilenamePattern._(this.source, this._segments);

  /// Parses [source]; errors name the 1-based column.
  static Result<FilenamePattern> parse(String source) {
    Err<FilenamePattern> fail(int index, String message) =>
        Err(FilenamePatternFailure(index + 1, message));

    if (source.trim().isEmpty) return fail(0, 'pattern is empty');
    if (source.startsWith('/')) return fail(0, 'must not start with "/"');
    if (source.endsWith('/')) {
      return fail(source.length - 1, 'must end with a file name, not "/"');
    }
    final segments = <List<_Part>>[[]];
    var literal = StringBuffer();
    var segmentStart = 0;
    void flushLiteral() {
      if (literal.isNotEmpty) segments.last.add(_Literal(literal.toString()));
      literal = StringBuffer();
    }

    var i = 0;
    while (i < source.length) {
      if (source.startsWith('{{', i)) {
        final end = source.indexOf('}}', i + 2);
        if (end < 0) return fail(i, 'token "{{" is never closed with "}}"');
        final body = source.substring(i + 2, end).trim();
        final colon = body.indexOf(':');
        final name = colon < 0 ? body : body.substring(0, colon).trim();
        final arg = colon < 0 ? null : body.substring(colon + 1).trim();
        final problem = _checkToken(name, arg);
        if (problem != null) return fail(i, problem);
        flushLiteral();
        segments.last.add(_Token(name, arg));
        i = end + 2;
        continue;
      }
      final c = source[i];
      if (c == '/') {
        flushLiteral();
        final text = source.substring(segmentStart, i).trim();
        if (segments.last.isEmpty || text == '.' || text == '..') {
          return fail(i, 'empty, "." or ".." folder names are not allowed');
        }
        segments.add([]);
        segmentStart = i + 1;
      } else {
        literal.write(c);
      }
      i++;
    }
    flushLiteral();
    final last = source.substring(segmentStart).trim();
    if (last == '.' || last == '..') {
      return fail(segmentStart, '"." and ".." are not file names');
    }
    return Ok(FilenamePattern._(source, segments));
  }

  static String? _checkToken(String name, String? arg) {
    switch (name) {
      case 'date':
        if (arg == null) return null;
        if (arg.isEmpty) return 'date format is empty';
        if (arg.contains('/')) {
          return 'use "{{date:YYYY}}/{{date:MM}}" for folders, not "/" '
              'inside a date format';
        }
        if (!_dateSeparators.hasMatch(arg.replaceAll(_dateToken, ''))) {
          return 'date format may only use YYYY MM DD HH mm ss and - _ . '
              'or space';
        }
        return null;
      case 'time' || 'title' || 'slug' || 'profile' || 'id':
        return arg == null ? null : '"$name" takes no argument';
      default:
        return 'unknown token "$name" (date, time, title, slug, profile, id)';
    }
  }

  final String source;
  final List<List<_Part>> _segments;

  /// Renders the relative note path: each segment sanitized
  /// ([sanitizeSegment]), the last one a `.md` file name.
  String render(FilenameValues v) => renderPath(v).path;

  /// [render] split into folder and (suffixable) file name.
  NotePath renderPath(FilenameValues v) {
    final rendered = [for (final s in _segments) _renderSegment(s, v)];
    return NotePath(
      [for (final s in rendered.take(rendered.length - 1)) sanitizeSegment(s)]
          .join('/'),
      VaultFileName.parse(rendered.last),
    );
  }

  static String _renderSegment(List<_Part> parts, FilenameValues v) {
    final withProfile = parts.any((p) => p is _Token && p.name == 'profile');
    final texts = [
      for (final p in parts)
        switch (p) {
          _Literal(:final text) => text,
          _Token(:final name, :final arg) => _value(
            name,
            arg,
            v,
            dropProfilePrefix: withProfile,
          ),
        },
    ];
    // Drop one joiner next to an empty token: "date--slug" → "date-slug",
    // "-slug" at the start → "slug".
    for (var i = 0; i < parts.length; i++) {
      if (parts[i] is! _Token || texts[i].isNotEmpty) continue;
      if (i > 0 && parts[i - 1] is _Literal && _endsWithJoiner(texts[i - 1])) {
        texts[i - 1] = texts[i - 1].substring(0, texts[i - 1].length - 1);
      } else if (i + 1 < parts.length &&
          parts[i + 1] is _Literal &&
          texts[i + 1].isNotEmpty &&
          _joiners.contains(texts[i + 1][0])) {
        texts[i + 1] = texts[i + 1].substring(1);
      }
    }
    return texts.join();
  }

  static bool _endsWithJoiner(String s) =>
      s.isNotEmpty && _joiners.contains(s[s.length - 1]);

  static String _value(
    String name,
    String? arg,
    FilenameValues v, {
    bool dropProfilePrefix = false,
  }) {
    String two(int n) => n.toString().padLeft(2, '0');
    final t = v.createdAt;
    String date(String fmt) => fmt.replaceAllMapped(
      _dateToken,
      (m) => switch (m[0]) {
        'YYYY' => t.year.toString().padLeft(4, '0'),
        'MM' => two(t.month),
        'DD' => two(t.day),
        'HH' => two(t.hour),
        'mm' => two(t.minute),
        _ => two(t.second),
      },
    );
    return switch (name) {
      'date' => date(arg ?? 'YYYY-MM-DD'),
      'time' => date('HHmm'),
      'title' => v.title ?? '',
      'slug' => _slug(v, dropProfilePrefix),
      'profile' => v.profileId,
      _ =>
        v.recordingId.length > 8
            ? v.recordingId.substring(0, 8)
            : v.recordingId,
    };
  }

  /// "meeting-meeting-notes" → "meeting-notes" when the pattern already
  /// prints the profile before the slug.
  static String _slug(FilenameValues v, bool dropProfilePrefix) {
    final slug = slugify(v.title ?? '');
    final prefix = '${slugify(v.profileId)}-';
    if (dropProfilePrefix &&
        slug.startsWith(prefix) &&
        slug.length > prefix.length) {
      return slug.substring(prefix.length);
    }
    return slug;
  }
}
