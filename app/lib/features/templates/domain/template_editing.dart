import 'package:flutter/foundation.dart' show immutable;
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/domain/profile_issue.dart';
import 'package:vaultvoice/features/profiles/domain/profile_schema.dart';
import 'package:vaultvoice/features/profiles/domain/render_context.dart';
import 'package:vaultvoice/features/profiles/domain/template_variables.dart';
import 'package:vaultvoice/features/templates/domain/note_context.dart';
import 'package:vaultvoice/features/templates/domain/template_engine.dart';

/// Kind of a completion entry (shown next to it in the editor).
enum CompletionKind { scalar, list, map, helper, lambda }

/// One autocomplete entry: a full variable path (`data.title`) or a bare
/// name valid inside a section (`owner` inside `{{#data.action_items}}`).
@immutable
class TemplateCompletion {
  const TemplateCompletion(this.path, this.kind);

  final String path;
  final CompletionKind kind;

  @override
  bool operator ==(Object other) =>
      other is TemplateCompletion && other.path == path && other.kind == kind;

  @override
  int get hashCode => Object.hash(path, kind);

  @override
  String toString() => '$path(${kind.name})';
}

/// Every variable a template for [root] can use (EXP-07 autocomplete):
/// full paths from the root (`data.*`, `meta.*`, `transcript.*`, root
/// `has_*` aliases), the fields of list items as bare names (they are in
/// scope inside the list's section), then the lambdas. Sorted within each
/// group, no duplicates.
List<TemplateCompletion> templateCompletions(MapShape root) {
  final paths = <String, CompletionKind>{};
  final bare = <String, CompletionKind>{};

  CompletionKind kindOf(ContextShape s) => switch (s) {
    ScalarShape() => CompletionKind.scalar,
    ListShape() => CompletionKind.list,
    MapShape() => CompletionKind.map,
  };

  void walkItem(ContextShape item) {
    if (item is! MapShape) return;
    for (final e in item.fields.entries) {
      bare.putIfAbsent(e.key, () => kindOf(e.value));
      if (item.helpersFor.contains(e.key)) {
        bare.putIfAbsent('has_${e.key}', () => CompletionKind.helper);
      }
      final v = e.value;
      if (v is ListShape) walkItem(v.item);
    }
  }

  void walk(MapShape map, String prefix) {
    for (final e in map.fields.entries) {
      final path = '$prefix${e.key}';
      paths[path] = kindOf(e.value);
      if (map.helpersFor.contains(e.key)) {
        paths['${prefix}has_${e.key}'] = CompletionKind.helper;
      }
      switch (e.value) {
        case final MapShape m:
          walk(m, '$path.');
        case ListShape(:final item):
          walkItem(item);
        case ScalarShape():
          break;
      }
    }
  }

  walk(root, '');
  for (final h in root.helpersFor) {
    paths['has_$h'] = CompletionKind.helper;
  }
  final sortedPaths = paths.keys.toList()..sort();
  final sortedBare = [
    for (final k in bare.keys)
      if (!paths.containsKey(k)) k,
  ]..sort();
  final lambdas = kTemplateLambdas.toList()..sort();
  return [
    for (final p in sortedPaths) TemplateCompletion(p, paths[p]!),
    for (final b in sortedBare) TemplateCompletion(b, bare[b]!),
    for (final l in lambdas) TemplateCompletion(l, CompletionKind.lambda),
  ];
}

final RegExp _tagStart = RegExp(r'\{\{\{?[#^/&>!]?\s*$');

/// The partial variable name being typed inside an open `{{` tag at the
/// end of [beforeCursor] (the current line up to the cursor), or null when
/// the cursor is not inside a tag. `{{#data.ti` → `data.ti`.
String? mustacheInput(String beforeCursor) {
  final open = beforeCursor.lastIndexOf('{{');
  if (open < 0) return null;
  if (beforeCursor.indexOf('}}', open) >= 0) return null;
  final tail = beforeCursor.substring(open);
  final m = RegExp(r'^\{\{\{?[#^/&]?\s*([A-Za-z0-9_.]*)$').firstMatch(tail);
  if (m == null) return _tagStart.hasMatch(tail) ? '' : null;
  return m.group(1);
}

/// Completions whose path starts with [input] (case-insensitive), best
/// first: exact-prefix paths, then segment matches (`ti` → `data.title`).
List<TemplateCompletion> matchCompletions(
  List<TemplateCompletion> all,
  String input, {
  int limit = 20,
}) {
  final q = input.toLowerCase();
  final prefix = <TemplateCompletion>[];
  final segment = <TemplateCompletion>[];
  for (final c in all) {
    final p = c.path.toLowerCase();
    if (p == q) continue;
    if (p.startsWith(q)) {
      prefix.add(c);
    } else if (q.isNotEmpty && !q.contains('.') && p.contains('.$q')) {
      segment.add(c);
    }
  }
  return [...prefix, ...segment].take(limit).toList();
}

/// Result of a live preview (EXP-07).
class TemplatePreview {
  const TemplatePreview({required this.markdown, required this.issues});

  /// Rendered note; null when the template does not parse.
  final String? markdown;

  /// Save-time issues (`name:line:col` + message), empty when valid.
  final List<ProfileIssue> issues;

  bool get isValid => issues.isEmpty;
}

/// A syntax/variable issue position, parsed from [ProfileIssue.path]
/// (`<name>:<line>:<col>`); null when the issue has no position.
({int line, int column})? issuePosition(ProfileIssue issue) {
  final m = RegExp(r':(\d+):(\d+)$').firstMatch(issue.path);
  if (m == null) return null;
  return (line: int.parse(m.group(1)!), column: int.parse(m.group(2)!));
}

/// Fixed sample `meta` + `transcript` for previews (no user content).
Map<String, Object?> sampleMeta(Profile profile) => buildNoteMeta(
  recordingId: '00000000-0000-4000-8000-000000000000',
  title: 'Sample note',
  createdAt: DateTime(2026, 1, 15, 9, 30),
  durationMs: 754000,
  profileId: profile.id,
  profileName: profile.name,
  appVersion: '1.0.0',
  speakers: const [(label: 'SPEAKER_00', name: 'Alex')],
  tags: const ['sample'],
);

/// Sample transcript lines for previews.
Map<String, Object?> sampleTranscript() => buildNoteTranscript(const [
  (startMs: 4000, speaker: 'Alex', text: 'Welcome, this is sample text.'),
  (startMs: 12000, speaker: 'Sam', text: 'The preview uses made-up data.'),
]);

/// The profile's first few-shot example output, else neutral placeholder
/// data shaped like its schema (built-in profiles ship no examples), so the
/// preview exercises every field.
Map<String, Object?> sampleDataFor(Profile profile) => profile.examples.isEmpty
    ? _sampleObject(profile.schema)
    : profile.examples.first.output;

Map<String, Object?> _sampleObject(ObjectSchema schema) => {
  for (final e in schema.properties.entries)
    e.key: _sampleValue(e.key, e.value),
};

Object? _sampleValue(String key, SchemaNode node) => switch (node) {
  ObjectSchema() => _sampleObject(node),
  ArraySchema() => [_sampleValue(key, node.items)],
  NumberSchema() => node.enumValues?.first ?? 1,
  BooleanSchema() => true,
  StringSchema() when node.enumValues != null => node.enumValues!.first,
  StringSchema() when node.format == 'date' || key.endsWith('date') =>
    '2026-01-15',
  StringSchema() when key == 't' => '00:00:04',
  StringSchema() => 'Sample $key',
};

/// Validates and renders [source] for [profile] with [data] (sample or a
/// past recording's extraction). Never throws.
TemplatePreview previewTemplate(
  String source, {
  required Profile profile,
  required Map<String, Object?> data,
  Map<String, Object?>? meta,
  Map<String, Object?>? transcript,
  MarkdownTemplateEngine engine = const MarkdownTemplateEngine(),
  String name = 'template',
}) {
  final issues = engine.validate(source, rootShapeFor(profile), name: name);
  final compiled = engine.compile(source, name: name);
  if (compiled case Err()) {
    return TemplatePreview(markdown: null, issues: issues);
  }
  final context = buildRenderContext(
    profile: profile,
    data: data,
    meta: meta ?? sampleMeta(profile),
    transcript: transcript ?? sampleTranscript(),
  );
  final note = engine.render(compiled.valueOrNull!, context);
  return TemplatePreview(markdown: note.markdown, issues: issues);
}
