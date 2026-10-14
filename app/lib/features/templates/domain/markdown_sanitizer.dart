import 'dart:async';

import 'package:characters/characters.dart';

/// A string value from the LLM, the transcript or the user, as it sits in
/// the Mustache rendering context.
///
/// Templates run with `htmlEscapeValues: false`, so every value is made safe
/// here instead (vv-markdown-vault-export → "Template engine"):
/// `{{x}}` prints [toString], the Markdown-inline-safe form
/// ([sanitizeInline]); lambdas that quote or fence their input (`yaml`,
/// `yaml_list`, `code_block`, `wikilink`, `slug`, `md_table`) read [raw] and
/// apply their own, stricter escaping. Values are never re-parsed as
/// templates.
final class InlineText {
  InlineText(this.raw);

  /// The value exactly as produced (after context normalization).
  final String raw;

  late final String _inline = sanitizeInline(raw);

  /// The sanitized form, or [raw] while a quoting lambda renders
  /// ([renderRaw]).
  @override
  String toString() => inRawSection ? raw : _inline;
}

/// Zone key that switches [InlineText.toString] to the raw value.
const Symbol _rawZoneKey = #vaultvoiceRawText;

/// Whether the current render runs inside [renderRaw].
bool get inRawSection => Zone.current[_rawZoneKey] == true;

/// Runs [render] (synchronous) with every [InlineText] printing its raw
/// value — for lambdas that quote or fence their whole output.
String renderRaw(String Function() render) =>
    runZoned(render, zoneValues: {_rawZoneKey: true});

/// The raw string behind a context value, or null when [value] is not
/// text (numbers and bools are formatted with `toString`).
String? rawText(Object? value) => switch (value) {
  final InlineText t => t.raw,
  final String s => s,
  final num n => n.toString(),
  final bool b => b.toString(),
  _ => null,
};

/// Recursively wraps every string of a normalized render context in
/// [InlineText]. Maps and lists are copied; other values pass through.
Object? wrapContextValues(Object? value) => switch (value) {
  final String s => InlineText(s),
  final Map<String, Object?> m => <String, Object?>{
    for (final e in m.entries) e.key: wrapContextValues(e.value),
  },
  final List<Object?> l => [for (final e in l) wrapContextValues(e)],
  _ => value,
};

final RegExp _lineBreaks = RegExp(r'\s*[\r\n\u2028\u2029\u0085]+\s*');

/// C0 controls (except tab/newline), DEL and the bidi *override*
/// characters LRO/RLO, which can visually reorder the rest of a line
/// ("Trojan Source"); embeddings/isolates used by RTL text are kept.
final RegExp _controls = RegExp(
  r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F\u202D\u202E]',
);

/// Block-level Markdown markers that would change the structure of the
/// note if the value starts a line: ATX headings, block quotes / callouts,
/// list markers, thematic breaks / setext underlines / front-matter
/// fences, fenced-code openers, tables and HTML blocks.
final RegExp _leadingBlockMarker = RegExp(
  r'^(?:#{1,6}(?=\s|$)|>|[-*+](?=\s|$)|[-*_=]{3,}|`{3,}|~{3,}|\|)\s*',
);

/// Makes [text] safe to splice into a Markdown line of a template.
///
/// - line breaks (any kind) collapse to one space — a value can never start
///   a new line, so it cannot open a heading, list, fence or a second
///   front-matter block (`---`);
/// - control characters are removed, unpaired surrogates become U+FFFD;
/// - leading block markers (`#`, `>`, `-`, `*`, `+`, `---`, `===`, fences,
///   `|`) are stripped repeatedly, trailing whitespace is trimmed;
/// - `[[` / `]]` are escaped (no accidental wikilinks / transclusions),
///   `{{` is neutralized to `{\{` (no template syntax when the note is pasted
///   into a custom template or a templating plugin), and `<` and backticks
///   are backslash-escaped (no HTML comments / code spans swallowing the
///   rest of the note).
///
/// Backslash escapes are CommonMark-standard, so Obsidian/Logseq display the
/// original characters.
String sanitizeInline(String text) {
  var s = fixSurrogates(text).replaceAll(_lineBreaks, ' ');
  s = s.replaceAll(_controls, '').replaceAll('\t', ' ').trim();
  while (true) {
    final m = _leadingBlockMarker.firstMatch(s);
    if (m == null || m.end == 0) break;
    s = s.substring(m.end);
  }
  s = s.trimRight();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    final next = i + 1 < s.length ? s[i + 1] : '';
    switch (c) {
      case '[' when next == '[':
        out.write(r'\[\[');
        i++;
      case ']' when next == ']':
        out.write(r'\]\]');
        i++;
      case '{' when next == '{':
        out.write(r'{\{');
        i++;
      case '<':
        out.write(r'\<');
      case '`':
        out.write(r'\`');
      default:
        out.write(c);
    }
  }
  return out.toString();
}

/// Replaces unpaired UTF-16 surrogates with U+FFFD (they cannot be encoded
/// as UTF-8 and are invalid in YAML).
String fixSurrogates(String s) {
  StringBuffer? out;
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    final isHigh = c >= 0xD800 && c <= 0xDBFF;
    final isLow = c >= 0xDC00 && c <= 0xDFFF;
    var bad = false;
    if (isHigh) {
      final hasLow =
          i + 1 < s.length &&
          s.codeUnitAt(i + 1) >= 0xDC00 &&
          s.codeUnitAt(i + 1) <= 0xDFFF;
      if (hasLow) {
        out?.writeCharCode(c);
        out?.writeCharCode(s.codeUnitAt(i + 1));
        i++;
        continue;
      }
      bad = true;
    } else if (isLow) {
      bad = true;
    }
    if (bad) {
      out ??= StringBuffer(s.substring(0, i));
      out.write('�');
    } else {
      out?.writeCharCode(c);
    }
  }
  return out?.toString() ?? s;
}

/// A YAML 1.2 double-quoted scalar for [value] (also valid JSON).
///
/// Escapes `"` and `\`, every C0/C1 control, DEL, U+2028/U+2029 (line
/// breaks in YAML 1.1) and U+FEFF; unpaired surrogates become U+FFFD. The
/// result is always one line, so no value can end the front-matter block.
String yamlQuote(String value) {
  final s = fixSurrogates(value);
  final out = StringBuffer('"');
  for (final rune in s.runes) {
    switch (rune) {
      case 0x22:
        out.write(r'\"');
      case 0x5C:
        out.write(r'\\');
      case 0x0A:
        out.write(r'\n');
      case 0x0D:
        out.write(r'\r');
      case 0x09:
        out.write(r'\t');
      case < 0x20 || 0x7F || (>= 0x80 && <= 0x9F) || 0x2028 || 0x2029 || 0xFEFF:
        out.write('\\u${rune.toRadixString(16).padLeft(4, '0')}');
      default:
        out.writeCharCode(rune);
    }
  }
  out.write('"');
  return out.toString();
}

/// A YAML flow sequence of double-quoted strings: `["a", "b"]`.
String yamlList(Iterable<String> values) =>
    '[${values.map(yamlQuote).join(', ')}]';

/// Escapes a value for one GFM table cell: inline-sanitized, `|` escaped.
String tableCell(String text) => sanitizeInline(text).replaceAll('|', r'\|');

/// A wikilink target: inline line breaks collapsed and the characters
/// Obsidian forbids in link targets (`[ ] | # ^`) and `{{` removed.
String wikilinkTarget(String text) =>
    fixSurrogates(text)
        .replaceAll(_lineBreaks, ' ')
        .replaceAll(_controls, '')
        .replaceAll(RegExp(r'[\[\]|#^]'), '')
        .replaceAll('{{', '{')
        .replaceAll('}}', '}')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

final RegExp _slugSeparators = RegExp(r'[^\p{L}\p{N}\p{M}]+', unicode: true);

/// Lower-case, `-`-separated slug of [text]: letters, marks and digits of
/// any script are kept, everything else (spaces, punctuation, emoji)
/// separates; at most [maxLength] characters (graphemes), never ending in
/// `-`. Empty when nothing is left.
String slugify(String text, {int maxLength = 60}) {
  final s = fixSurrogates(text)
      .toLowerCase()
      .replaceAll(_slugSeparators, '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final chars = s.characters;
  final cut = chars.length > maxLength ? chars.take(maxLength).toString() : s;
  return cut.replaceAll(RegExp(r'-+$'), '');
}

/// A fenced code block whose fence is longer than any backtick run in
/// [text] (minimum three), so the text can never close it.
String codeFence(String text, {String info = ''}) {
  var longest = 0;
  var run = 0;
  for (final c in text.codeUnits) {
    run = c == 0x60 ? run + 1 : 0;
    if (run > longest) longest = run;
  }
  final fence = '`' * (longest < 3 ? 3 : longest + 1);
  final body = fixSurrogates(text).replaceAll('\r\n', '\n');
  final nl = body.endsWith('\n') ? '' : '\n';
  return '$fence$info\n$body$nl$fence';
}
