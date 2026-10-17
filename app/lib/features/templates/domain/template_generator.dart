import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/domain/profile_schema.dart';
import 'package:vaultvoice/features/profiles/domain/render_context.dart';
import 'package:vaultvoice/features/templates/domain/template_lambdas.dart';

/// Strings longer than this (schema `maxLength`) get their own section
/// instead of a `**Label:** value` line.
const int kLongTextThreshold = 200;

const String _metaTitle =
    '{{#meta.has_title}}{{meta.title}}{{/meta.has_title}}'
    '{{^meta.has_title}}{{meta.profile_name}} '
    '{{meta.date}}{{/meta.has_title}}';

/// Generates an Obsidian template for [profile] from its schema (custom
/// profiles, PRF-07; editable in EXP-07): standard front-matter; a root
/// `title` string becomes the heading; short scalars become
/// `**Label:** value` lines (guarded by `has_`), long strings get a
/// section, string lists use `bullets`, lists of objects with a `task` /
/// `text` field become `checkbox` lists, other lists of objects `md_table`,
/// objects a section of their fields.
///
/// The output always passes the strict template-variable check for
/// [profile] (tested for the built-ins and a profile with every field kind).
String generateTemplate(Profile profile) {
  final shape = dataShapeFor(profile);
  final hasTitle = _isString(shape.fields['title']);
  final title = hasTitle
      ? '{{#has_title}}{{data.title}}{{/has_title}}'
            '{{^has_title}}$_metaTitle{{/has_title}}'
      : _metaTitle;
  final b = StringBuffer()
    ..writeln('---')
    ..writeln('title: {{#yaml}}$title{{/yaml}}')
    ..writeln('date: {{meta.date}}')
    ..writeln('time: {{#yaml}}{{meta.time}}{{/yaml}}')
    ..writeln('duration: {{#yaml}}{{meta.duration_human}}{{/yaml}}')
    ..writeln('type: {{#yaml}}{{meta.profile_id}}{{/yaml}}')
    ..writeln('tags: {{#yaml_list}}meta.tags{{/yaml_list}}')
    ..writeln('source: vaultvoice')
    ..writeln('recording_id: {{#yaml}}{{meta.recording_id}}{{/yaml}}')
    ..writeln('{{#meta.has_consent_at}}')
    ..writeln('consent_at: {{#yaml}}{{meta.consent_at}}{{/yaml}}')
    ..writeln('{{/meta.has_consent_at}}')
    ..writeln('---')
    ..writeln()
    ..writeln('# $title')
    ..writeln();

  final schemaProps = profile.schema.properties;
  final fields = [
    for (final e in shape.fields.entries)
      if (!(hasTitle && e.key == 'title')) e,
  ];

  // Short scalars: one "Details" list (never empty: the recording date).
  b
    ..writeln('## Details')
    ..writeln();
  for (final e in fields) {
    if (e.value is ScalarShape && !_isLong(e.key, schemaProps[e.key])) {
      b.writeln(_scalarLine(shape, e.key, 'data.${e.key}', e.key));
    }
  }
  b
    ..writeln('- **Recorded:** {{meta.date}} {{meta.time}}')
    ..writeln();

  for (final e in fields) {
    final name = e.key;
    final path = 'data.$name';
    final label = humanizeKey(name);
    switch (e.value) {
      case ScalarShape() when _isLong(name, schemaProps[name]):
        b
          ..writeln('{{#has_$name}}')
          ..writeln('## $label')
          ..writeln()
          ..writeln('{{$path}}')
          ..writeln()
          ..writeln('{{/has_$name}}');
      case ScalarShape():
        break;
      case final MapShape map:
        b
          ..writeln('{{#$path}}')
          ..writeln('## $label')
          ..writeln()
          ..write(_objectBody(map))
          ..writeln()
          ..writeln('{{/$path}}');
      case ListShape(:final item):
        b
          ..writeln('{{#has_$name}}')
          ..writeln('## $label')
          ..writeln()
          ..write(_listBody(path, item))
          ..writeln()
          ..writeln('{{/has_$name}}');
    }
  }
  b
    ..writeln('{{audio_link}}')
    ..writeln()
    ..writeln('---')
    ..writeln()
    ..writeln('_Generated on-device by Lumen._');
  return b.toString();
}

bool _isString(ContextShape? s) =>
    s is ScalarShape && s.kind == ScalarKind.string;

bool _isLong(String name, SchemaNode? node) =>
    node is StringSchema &&
    node.enumValues == null &&
    (node.maxLength ?? 0) > kLongTextThreshold;

/// `- **Label:** {{path}}`, guarded by `has_<name>` when [scope] has it.
String _scalarLine(MapShape scope, String name, String path, String key) {
  final line = '- **${humanizeKey(key)}:** {{$path}}';
  final dot = path.lastIndexOf('.');
  final helper = dot < 0 ? 'has_$name' : '${path.substring(0, dot)}.has_$name';
  return scope.helpersFor.contains(name)
      ? '{{#$helper}}\n$line\n{{/$helper}}'
      : line;
}

/// Body of an object section (rendered with the object as scope).
String _objectBody(MapShape map) {
  final b = StringBuffer();
  for (final e in map.fields.entries) {
    if (e.value is ScalarShape) {
      b.writeln(_scalarLine(map, e.key, e.key, e.key));
    }
  }
  for (final e in map.fields.entries) {
    if (e.value case ListShape(:final item) when item is ScalarShape) {
      b.writeln(
        '\n{{#has_${e.key}}}\n**${humanizeKey(e.key)}:**\n\n'
        '{{#bullets}}${e.key}{{/bullets}}\n{{/has_${e.key}}}',
      );
    }
    // Deeper nesting (lists of objects inside objects) is left to the
    // template editor (EXP-07).
  }
  return b.toString();
}

String _listBody(String path, ContextShape item) {
  if (item is! MapShape) return '{{#bullets}}$path{{/bullets}}\n';
  final textField = [
    'task',
    'text',
  ].firstWhere((f) => _isString(item.fields[f]), orElse: () => '');
  if (textField.isEmpty) return '{{#md_table}}$path{{/md_table}}\n';
  final b = StringBuffer('{{#$path}}\n{{#checkbox}}{{$textField}}');
  for (final e in item.fields.entries) {
    if (e.key == textField || e.value is! ScalarShape) continue;
    final s = e.value as ScalarShape;
    if (s.kind == ScalarKind.boolean && !item.helpersFor.contains(e.key)) {
      continue; // `done` / `checked` drive the checkbox itself.
    }
    final part = switch (e.key) {
      'owner' => ' (@{{owner}})',
      't' => ' [{{t}}]',
      final k when k.endsWith('_iso') => ' 📅 {{$k}}',
      final k => ' — ${humanizeKey(k)}: {{$k}}',
    };
    b.write(
      item.helpersFor.contains(e.key)
          ? '{{#has_${e.key}}}$part{{/has_${e.key}}}'
          : part,
    );
  }
  b.write('{{/checkbox}}\n{{/$path}}\n');
  return b.toString();
}
