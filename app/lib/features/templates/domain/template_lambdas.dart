import 'package:mustache_template/mustache.dart';
import 'package:vaultvoice/features/profiles/domain/template_variables.dart';
import 'package:vaultvoice/features/templates/domain/markdown_sanitizer.dart';

/// Per-render inputs of the lambdas that are not part of the context.
class LambdaOptions {
  const LambdaOptions({
    this.audioAttachment,
    this.transcriptTitle = 'Transcript',
  });

  /// File name of the exported audio sidecar inside `attachments/`, or null
  /// when no audio was exported (`audio_link` then renders nothing).
  final String? audioAttachment;

  /// Title of the collapsible `transcript_block` callout.
  final String transcriptTitle;
}

String _renderRaw(LambdaContext ctx) => renderRaw(ctx.renderString);

/// The lambdas, keyed by name. Every name is in PRF-01's
/// `kTemplateLambdas` (the template-variable check); a test enforces it.
Map<String, Object> buildLambdas([
  LambdaOptions options = const LambdaOptions(),
]) {
  final lambdas = <String, Object>{
    'yaml': (LambdaContext ctx) => yamlQuote(_renderRaw(ctx)),
    'yaml_list': (LambdaContext ctx) => yamlList(_texts(_list(ctx))),
    'wikilink': (LambdaContext ctx) {
      final target = wikilinkTarget(_renderRaw(ctx));
      return target.isEmpty ? '' : '[[$target]]';
    },
    'slug': (LambdaContext ctx) => slugify(_renderRaw(ctx)),
    'upper': (LambdaContext ctx) => ctx.renderString().toUpperCase(),
    'lower': (LambdaContext ctx) => ctx.renderString().toLowerCase(),
    'trim': (LambdaContext ctx) => ctx.renderString().trim(),
    'date': _date,
    'duration': _duration,
    'checkbox': (LambdaContext ctx) {
      final text = ctx.renderString().replaceAll(RegExp(r'\s*\n\s*'), ' ');
      final checked =
          ctx.lookup('done') == true || ctx.lookup('checked') == true;
      return '- [${checked ? 'x' : ' '}] ${text.trim()}';
    },
    'md_table': _mdTable,
    'bullets': (LambdaContext ctx) => [
      for (final item in _list(ctx))
        if (_bulletText(item) case final t? when t.isNotEmpty) '- $t',
    ].join('\n'),
    'transcript_block': (LambdaContext ctx) =>
        _transcriptBlock(ctx, options.transcriptTitle),
    'audio_link': (LambdaContext ctx) {
      final file = options.audioAttachment;
      if (file == null) return '';
      final target = wikilinkTarget(file).replaceAll('/', '');
      return target.isEmpty ? '' : '![[attachments/$target]]';
    },
    'code_block': (LambdaContext ctx) => codeFence(_renderRaw(ctx)),
  };
  assert(
    lambdas.keys.toSet().containsAll(kTemplateLambdas) &&
        kTemplateLambdas.containsAll(lambdas.keys),
    'lambdas out of sync with kTemplateLambdas',
  );
  return lambdas;
}

/// `path|args` split of a lambda's literal section text.
(String path, String args) _splitArg(String text) {
  final t = text.trim();
  final bar = t.indexOf('|');
  return bar < 0 ? (t, '') : (t.substring(0, bar).trim(), t.substring(bar + 1));
}

Iterable<Object?> _list(LambdaContext ctx) {
  final (path, _) = _splitArg(ctx.source);
  final value = ctx.lookup(path);
  // The missing-property sentinel and every non-list count as empty.
  return value is Iterable<Object?> ? value : const [];
}

Iterable<String> _texts(Iterable<Object?> items) => [
  for (final item in items)
    ?rawText(item),
];

String? _bulletText(Object? item) {
  if (item is Map<Object?, Object?>) {
    final parts = [
      for (final e in item.entries)
        if (e.key is String && !(e.key! as String).startsWith('has_'))
          if (rawText(e.value) case final t?) sanitizeInline(t),
    ].where((p) => p.isNotEmpty);
    return parts.join(' — ');
  }
  final t = rawText(item);
  return t == null ? null : sanitizeInline(t);
}

final RegExp _isoDate = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2}))?)?',
);
final RegExp _dateTokens = RegExp('YYYY|YY|MM|M|DD|D|HH|H|mm|ss');

Object _date(LambdaContext ctx) {
  final (first, rest) = _splitArg(ctx.source);
  final String? value;
  final String format;
  if (ctx.source.contains('|')) {
    value = rawText(ctx.lookup(first));
    format = rest.trim();
  } else {
    final date = rawText(ctx.lookup('meta.date'));
    final time = rawText(ctx.lookup('meta.time'));
    value = date == null ? null : (time == null ? date : '${date}T$time');
    format = first;
  }
  final m = value == null ? null : _isoDate.firstMatch(value);
  if (m == null) return '';
  String two(int g) => m.group(g) ?? '00';
  final fmt = format.isEmpty ? 'YYYY-MM-DD' : format;
  return fmt.replaceAllMapped(_dateTokens, (t) {
    return switch (t[0]) {
      'YYYY' => m.group(1)!,
      'YY' => m.group(1)!.substring(2),
      'MM' => m.group(2)!,
      'M' => int.parse(m.group(2)!).toString(),
      'DD' => m.group(3)!,
      'D' => int.parse(m.group(3)!).toString(),
      'HH' => two(4),
      'H' => int.parse(two(4)).toString(),
      'mm' => two(5),
      _ => two(6),
    };
  });
}

Object _duration(LambdaContext ctx) {
  final (first, rest) = _splitArg(ctx.source);
  final hasPath = ctx.source.contains('|');
  final value = ctx.lookup(hasPath ? first : 'meta.duration_ms');
  if (value is! num) return '';
  return formatDuration(value.round(), hasPath ? rest.trim() : first);
}

/// Formats [ms] as `human` (default: `1h 05m`, `12m 03s`, `45s`),
/// `hh:mm:ss`, `h:mm:ss`, `mm:ss` (total minutes) or `minutes`.
String formatDuration(int ms, [String format = '']) {
  final total = (ms < 0 ? 0 : ms) ~/ 1000;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  String p2(int v) => v.toString().padLeft(2, '0');
  return switch (format) {
    'hh:mm:ss' => '${p2(h)}:${p2(m)}:${p2(s)}',
    'h:mm:ss' => '$h:${p2(m)}:${p2(s)}',
    'mm:ss' => '${p2(total ~/ 60)}:${p2(s)}',
    'minutes' => '${(ms / 60000).round()}',
    _ =>
      h > 0
          ? '${h}h ${p2(m)}m'
          : m > 0
          ? '${m}m ${p2(s)}s'
          : '${s}s',
  };
}

/// `open_questions` → `Open questions`.
String humanizeKey(String key) {
  final words = key.replaceAll('_', ' ').trim();
  if (words.isEmpty) return words;
  return words[0].toUpperCase() + words.substring(1);
}

Object _mdTable(LambdaContext ctx) {
  final (_, args) = _splitArg(ctx.source);
  final rows = [
    for (final item in _list(ctx))
      if (item is Map<Object?, Object?>) item,
  ];
  if (rows.isEmpty) return '';
  final requested = [
    for (final c in args.split(','))
      if (c.trim().isNotEmpty) c.trim(),
  ];
  final columns = requested.isNotEmpty
      ? requested
      : [
          for (final k in rows.first.keys)
            if (k is String && !k.startsWith('has_') && rows.first[k] is! Map)
              k,
        ];
  if (columns.isEmpty) return '';
  String cell(Object? v) => switch (v) {
    final Iterable<Object?> list => tableCell(_texts(list).join('; ')),
    _ => tableCell(rawText(v) ?? ''),
  };
  return [
    '| ${columns.map((c) => tableCell(humanizeKey(c))).join(' | ')} |',
    '| ${columns.map((_) => '---').join(' | ')} |',
    for (final r in rows) '| ${columns.map((c) => cell(r[c])).join(' | ')} |',
  ].join('\n');
}

Object _transcriptBlock(LambdaContext ctx, String title) {
  final segments = ctx.lookup('transcript.segments');
  if (segments is! Iterable<Object?>) return '';
  final lines = <String>[];
  for (final s in segments) {
    if (s is! Map<Object?, Object?>) continue;
    final text = rawText(s['text']);
    if (text == null) continue;
    final t = rawText(s['t']);
    final speaker = rawText(s['speaker']);
    final prefix = [
      if (t != null) '[${sanitizeInline(t)}]',
      if (speaker != null) '${sanitizeInline(speaker)}:',
    ].join(' ');
    final body = sanitizeInline(text);
    lines.add(
      '> ${[if (prefix.isNotEmpty) prefix, body].join(' ')}'.trimRight(),
    );
  }
  if (lines.isEmpty) return '';
  return ['> [!note]- ${sanitizeInline(title)}', ...lines].join('\n');
}
