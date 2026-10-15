import 'dart:convert';

import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/domain/profile_schema.dart';
import 'package:vaultvoice/features/profiles/domain/profile_validator.dart';

/// Field types the custom profile editor offers (PRF-07,
/// vv-extraction-profiles → "Custom profile editor"). Users never see JSON
/// Schema: each kind maps to one bounded schema node.
enum FieldKind {
  text,
  longText,
  textList,
  date,
  number,
  boolean,
  checkboxList,
  table,

  /// A field the builder cannot express (e.g. from a duplicated built-in);
  /// kept verbatim, shown read-only, removable.
  advanced,
}

/// Column types of a [FieldKind.table].
enum ColumnKind { text, number, date, boolean }

/// Default limits of generated schemas (small-model friendly, grammar-bounded).
abstract final class DraftLimits {
  static const int maxFields = 25;
  static const int textMaxLength =
      200; // ≤ kLongTextThreshold: a "Details" line
  static const int longTextMaxLength = 2000;
  static const int itemMaxLength = 200;
  static const int dateMaxLength = 40;
  static const int listMaxItems = 30;
  static const int tableMaxRows = 50;
  static const int maxColumns = 8;
}

/// One table column.
final class ColumnSpec {
  const ColumnSpec({required this.name, this.kind = ColumnKind.text});

  final String name;
  final ColumnKind kind;

  ColumnSpec copyWith({String? name, ColumnKind? kind}) =>
      ColumnSpec(name: name ?? this.name, kind: kind ?? this.kind);
}

/// One field of a custom profile.
final class FieldSpec {
  const FieldSpec({
    required this.name,
    required this.kind,
    this.description = '',
    this.columns = const [],
    this.rawSchema,
  });

  /// Best-effort inverse of [toSchema]; anything else is [FieldKind.advanced].
  factory FieldSpec.fromSchema(String name, SchemaNode node) {
    final desc = node.description ?? '';
    FieldSpec of(FieldKind k, {List<ColumnSpec> columns = const []}) =>
        FieldSpec(name: name, kind: k, description: desc, columns: columns);
    switch (node) {
      case StringSchema(:final enumValues, :final format, :final maxLength)
          when enumValues == null:
        if (format == 'date') return of(FieldKind.date);
        return of(
          (maxLength ?? 0) > DraftLimits.textMaxLength
              ? FieldKind.longText
              : FieldKind.text,
        );
      case NumberSchema(:final enumValues) when enumValues == null:
        return of(FieldKind.number);
      case BooleanSchema():
        return of(FieldKind.boolean);
      case ArraySchema(:final items):
        switch (items) {
          case StringSchema(:final enumValues) when enumValues == null:
            return of(FieldKind.textList);
          case ObjectSchema(:final properties)
              when properties.length == 2 &&
                  properties['task'] is StringSchema &&
                  properties['done'] is BooleanSchema:
            return of(FieldKind.checkboxList);
          case ObjectSchema(:final properties)
              when properties.isNotEmpty &&
                  properties.length <= DraftLimits.maxColumns &&
                  properties.values.every(_isColumn):
            return of(
              FieldKind.table,
              columns: [
                for (final e in properties.entries)
                  ColumnSpec(name: e.key, kind: _columnKind(e.value)),
              ],
            );
          default:
        }
      default:
    }
    return FieldSpec(
      name: name,
      kind: FieldKind.advanced,
      description: desc,
      rawSchema: node.toJson(),
    );
  }

  /// JSON key (`^[a-z][a-z0-9_]{0,39}$`, unique).
  final String name;
  final FieldKind kind;

  /// Shown to the model as the field description (≤ 300 chars).
  final String description;

  /// [FieldKind.table] columns.
  final List<ColumnSpec> columns;

  /// [FieldKind.advanced]: the original schema node JSON.
  final Map<String, Object?>? rawSchema;

  FieldSpec copyWith({
    String? name,
    FieldKind? kind,
    String? description,
    List<ColumnSpec>? columns,
  }) => FieldSpec(
    name: name ?? this.name,
    kind: kind ?? this.kind,
    description: description ?? this.description,
    columns: columns ?? this.columns,
    rawSchema: rawSchema,
  );

  /// The schema node for this field.
  Map<String, Object?> toSchema() {
    final desc = description.trim();
    Map<String, Object?> withDesc(Map<String, Object?> node) => {
      ...node,
      if (desc.isNotEmpty) 'description': desc,
    };
    return switch (kind) {
      FieldKind.text => withDesc({
        'type': ['string', 'null'],
        'maxLength': DraftLimits.textMaxLength,
      }),
      FieldKind.longText => withDesc({
        'type': ['string', 'null'],
        'maxLength': DraftLimits.longTextMaxLength,
      }),
      FieldKind.date => withDesc({
        'type': ['string', 'null'],
        'maxLength': DraftLimits.dateMaxLength,
        'format': 'date',
      }),
      FieldKind.number => withDesc({
        'type': ['number', 'null'],
      }),
      FieldKind.boolean => withDesc({
        'type': ['boolean', 'null'],
      }),
      FieldKind.textList => withDesc({
        'type': 'array',
        'maxItems': DraftLimits.listMaxItems,
        'items': {'type': 'string', 'maxLength': DraftLimits.itemMaxLength},
      }),
      FieldKind.checkboxList => withDesc({
        'type': 'array',
        'maxItems': DraftLimits.listMaxItems,
        'items': {
          'type': 'object',
          'required': ['task', 'done'],
          'properties': {
            'task': {'type': 'string', 'maxLength': DraftLimits.itemMaxLength},
            'done': {
              'type': 'boolean',
              'description': 'true only if stated as already done',
            },
          },
        },
      }),
      FieldKind.table => withDesc({
        'type': 'array',
        'maxItems': DraftLimits.tableMaxRows,
        'items': {
          'type': 'object',
          'required': [for (final c in columns) c.name],
          'properties': {for (final c in columns) c.name: _columnSchema(c)},
        },
      }),
      FieldKind.advanced => rawSchema ?? const {'type': 'string'},
    };
  }

  static Map<String, Object?> _columnSchema(ColumnSpec c) => switch (c.kind) {
    ColumnKind.text => {
      'type': ['string', 'null'],
      'maxLength': DraftLimits.itemMaxLength,
    },
    ColumnKind.number => {
      'type': ['number', 'null'],
    },
    ColumnKind.date => {
      'type': ['string', 'null'],
      'maxLength': DraftLimits.dateMaxLength,
      'format': 'date',
    },
    ColumnKind.boolean => {
      'type': ['boolean', 'null'],
    },
  };

  static bool _isColumn(SchemaNode n) => switch (n) {
    StringSchema(:final enumValues) => enumValues == null,
    NumberSchema(:final enumValues) => enumValues == null,
    BooleanSchema() => true,
    _ => false,
  };

  static ColumnKind _columnKind(SchemaNode n) => switch (n) {
    NumberSchema() => ColumnKind.number,
    BooleanSchema() => ColumnKind.boolean,
    StringSchema(:final format) when format == 'date' => ColumnKind.date,
    _ => ColumnKind.text,
  };
}

/// One few-shot example as the editor holds it: a transcript plus a value
/// per field, typed in plain text (lists: one item per line; tables: one
/// row per line, cells separated by `|`; checkbox lists: `[x] task`).
final class ExampleDraft {
  const ExampleDraft({required this.transcript, this.values = const {}});

  /// Inverse of [toOutput] for editing an existing example.
  factory ExampleDraft.fromExample(ProfileExample e, List<FieldSpec> fields) {
    String text(FieldSpec f, Object? v) {
      if (v == null) return '';
      return switch (f.kind) {
        FieldKind.textList when v is List => v.join('\n'),
        FieldKind.checkboxList when v is List => [
          for (final i in v.whereType<Map<String, Object?>>())
            '[${i['done'] == true ? 'x' : ' '}] ${i['task'] ?? ''}',
        ].join('\n'),
        FieldKind.table when v is List => [
          for (final r in v.whereType<Map<String, Object?>>())
            [for (final c in f.columns) '${r[c.name] ?? ''}'].join(' | '),
        ].join('\n'),
        FieldKind.boolean => v == true ? 'yes' : 'no',
        FieldKind.advanced => jsonEncode(v),
        _ => '$v',
      };
    }

    return ExampleDraft(
      transcript: e.transcript,
      values: {for (final f in fields) f.name: text(f, e.output[f.name])},
    );
  }

  final String transcript;
  final Map<String, String> values;

  /// The example output JSON for [fields] (unknown → null / empty).
  Map<String, Object?> toOutput(List<FieldSpec> fields) => {
    for (final f in fields) f.name: _value(f, values[f.name]?.trim() ?? ''),
  };

  static Object? _value(FieldSpec f, String raw) {
    List<String> lines() => [
      for (final l in raw.split('\n'))
        if (l.trim().isNotEmpty) l.trim(),
    ];
    Object? cell(ColumnKind k, String s) {
      final v = s.trim();
      if (v.isEmpty) return null;
      return switch (k) {
        ColumnKind.number => num.tryParse(v),
        ColumnKind.boolean => _bool(v),
        _ => v,
      };
    }

    return switch (f.kind) {
      FieldKind.text ||
      FieldKind.longText ||
      FieldKind.date => raw.isEmpty ? null : raw,
      FieldKind.number => num.tryParse(raw),
      FieldKind.boolean => raw.isEmpty ? null : _bool(raw),
      FieldKind.textList => lines(),
      FieldKind.checkboxList => [
        for (final l in lines())
          if (RegExp(r'^\[( |x|X)\]\s*(.*)$').firstMatch(l) case final m?)
            {'task': m.group(2), 'done': m.group(1) != ' '}
          else
            {'task': l, 'done': false},
      ],
      FieldKind.table => [
        for (final l in lines())
          {
            for (final (i, c) in f.columns.indexed)
              c.name: cell(c.kind, _cells(l).elementAtOrNull(i) ?? ''),
          },
      ],
      FieldKind.advanced => raw.isEmpty ? null : _json(raw),
    };
  }

  static List<String> _cells(String line) => line.split('|');

  static bool? _bool(String v) => switch (v.toLowerCase()) {
    'yes' || 'true' || 'y' || 'x' => true,
    'no' || 'false' || 'n' => false,
    _ => null,
  };

  static Object? _json(String raw) {
    try {
      return jsonDecode(raw);
    } on FormatException {
      return raw;
    }
  }
}

/// A custom profile while it is being edited. [toDefinition] yields a
/// format-1 definition that `ProfileRegistry.save` validates.
final class ProfileDraft {
  const ProfileDraft({
    required this.id,
    required this.name,
    this.description = '',
    this.instructions = '',
    this.fields = const [],
    this.examples = const [],
    this.diarization = true,
    this.defaultTarget,
    this.version = 1,
    this.templateId,
  });

  /// A new, empty draft.
  factory ProfileDraft.empty() => const ProfileDraft(id: '', name: '');

  /// Editable draft of [profile] (a user profile, or a built-in/managed one
  /// being duplicated — the caller then assigns a new id).
  factory ProfileDraft.fromProfile(Profile profile) {
    final fields = [
      for (final e in profile.schema.properties.entries)
        FieldSpec.fromSchema(e.key, e.value),
    ];
    return ProfileDraft(
      id: profile.id,
      name: profile.name,
      description: profile.description,
      instructions: _unwrapInstructions(profile.instructions),
      fields: fields,
      examples: [
        for (final e in profile.examples) ExampleDraft.fromExample(e, fields),
      ],
      diarization: profile.stt.diarization ?? true,
      defaultTarget: profile.defaultTarget,
      version: profile.version,
      templateId: profile.templateId,
    );
  }

  final String id;
  final String name;
  final String description;
  final String instructions;
  final List<FieldSpec> fields;
  final List<ExampleDraft> examples;
  final bool diarization;

  /// Vault target id (EXP-05) or `ask`; null = app default.
  final String? defaultTarget;
  final int version;

  /// Bound template; null = `<id>-default` (generated on save).
  final String? templateId;

  String get effectiveTemplateId => templateId ?? defaultTemplateIdFor(id);

  ProfileDraft copyWith({
    String? id,
    String? name,
    String? description,
    String? instructions,
    List<FieldSpec>? fields,
    List<ExampleDraft>? examples,
    bool? diarization,
    String? defaultTarget,
    bool clearDefaultTarget = false,
    int? version,
    String? templateId,
  }) => ProfileDraft(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    instructions: instructions ?? this.instructions,
    fields: fields ?? this.fields,
    examples: examples ?? this.examples,
    diarization: diarization ?? this.diarization,
    defaultTarget: clearDefaultTarget
        ? null
        : (defaultTarget ?? this.defaultTarget),
    version: version ?? this.version,
    templateId: templateId ?? this.templateId,
  );

  /// Problems the editor shows inline (field names, columns, counts);
  /// everything else is checked by `ProfileValidator` on save.
  List<DraftIssue> check() {
    final issues = <DraftIssue>[];
    if (name.trim().isEmpty) issues.add(const DraftIssue.nameMissing());
    if (fields.isEmpty) issues.add(const DraftIssue.noFields());
    if (fields.length > DraftLimits.maxFields) {
      issues.add(const DraftIssue.tooManyFields());
    }
    final seen = <String>{};
    for (final (i, f) in fields.indexed) {
      if (!isValidFieldName(f.name)) {
        issues.add(DraftIssue.fieldName(i));
      } else if (!seen.add(f.name)) {
        issues.add(DraftIssue.duplicateField(i));
      }
      if (f.kind == FieldKind.table) {
        final cols = <String>{};
        if (f.columns.isEmpty || f.columns.length > DraftLimits.maxColumns) {
          issues.add(DraftIssue.columns(i));
        }
        for (final c in f.columns) {
          if (!isValidFieldName(c.name) || !cols.add(c.name)) {
            issues.add(DraftIssue.columns(i));
            break;
          }
        }
      }
    }
    return issues;
  }

  /// Format-1 definition (tier `pro`; custom profiles are a Pro feature).
  Map<String, Object?> toDefinition() {
    final userInstructions = instructions.trim();
    return {
      'format': kProfileFormat,
      'id': id,
      'version': version,
      'name': name.trim(),
      'description': description.trim().isEmpty
          ? name.trim()
          : description.trim().replaceAll(RegExp(r'\s*\n\s*'), ' '),
      'tier': ProfileTier.pro.name,
      'stt': {'vocabulary': <String>[], 'diarization': diarization},
      'instructions': [
        _kLeadInstruction,
        if (userInstructions.isNotEmpty) userInstructions,
        _kAlwaysInstruction,
      ].join('\n'),
      'schema': {
        'type': 'object',
        'required': [for (final f in fields) f.name],
        'properties': {for (final f in fields) f.name: f.toSchema()},
      },
      if (examples.isNotEmpty)
        'examples': [
          for (final e in examples)
            {'transcript': e.transcript, 'output': e.toOutput(fields)},
        ],
      'template_id': effectiveTemplateId,
      if (defaultTarget case final t?) 'routing': {'default_target': t},
      'review_before_export': false,
      // SEC-07: a diarized (multi-person) profile asks for consent.
      'consent_confirmation': diarization ? 'required' : 'optional',
    };
  }
}

const String _kAlwaysInstruction =
    '- If a field has nothing, return an empty list or null.';

/// Removes the fixed lead/trailing lines [ProfileDraft.toDefinition] adds, so
/// reopening and re-saving a profile does not stack them.
String _unwrapInstructions(String saved) {
  var text = saved.trim();
  if (text.startsWith(_kLeadInstruction)) {
    text = text.substring(_kLeadInstruction.length).trim();
  }
  if (text.endsWith(_kAlwaysInstruction)) {
    text = text.substring(0, text.length - _kAlwaysInstruction.length).trim();
  }
  return text;
}

const String _kLeadInstruction =
    '- Extract only what is explicitly said in the transcript. Never invent '
    'people, numbers or dates.';

/// Why a draft cannot be saved yet (the UI localizes `DraftIssue.kind`).
enum DraftIssueKind {
  nameMissing,
  noFields,
  tooManyFields,
  fieldName,
  duplicateField,
  columns,
}

final class DraftIssue {
  const DraftIssue._(this.kind, [this.field]);
  const DraftIssue.nameMissing() : this._(DraftIssueKind.nameMissing);
  const DraftIssue.noFields() : this._(DraftIssueKind.noFields);
  const DraftIssue.tooManyFields() : this._(DraftIssueKind.tooManyFields);
  const DraftIssue.fieldName(int i) : this._(DraftIssueKind.fieldName, i);
  const DraftIssue.duplicateField(int i)
    : this._(DraftIssueKind.duplicateField, i);
  const DraftIssue.columns(int i) : this._(DraftIssueKind.columns, i);

  final DraftIssueKind kind;

  /// Index into [ProfileDraft.fields], when the issue is about one field.
  final int? field;

  @override
  String toString() => 'DraftIssue(${kind.name}, $field)';
}

/// Field/column name rule (same as the profile schema; `has_` is reserved).
bool isValidFieldName(String name) =>
    kFieldNamePattern.hasMatch(name) && !name.startsWith('has_');

/// `"Due date"` → `due_date` (a suggestion; the user may edit it).
String fieldNameFrom(String label) {
  var s = label
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  if (s.isEmpty || !RegExp('^[a-z]').hasMatch(s)) s = 'field_$s';
  if (s.startsWith('has_')) s = 'f_$s';
  return s.length > 40 ? s.substring(0, 40).replaceAll(RegExp(r'_+$'), '') : s;
}

/// Profile id for a new profile named [name], unique among [taken].
String profileIdFrom(String name, Set<String> taken) {
  var base = fieldNameFrom(name).replaceAll('_', '-');
  if (base.length > 32) base = base.substring(0, 32);
  base = base.replaceAll(RegExp(r'-+$'), '');
  if (base.length < 2 || base == 'field' || base.startsWith('field-')) {
    base = 'profile';
  }
  if (!taken.contains(base)) return base;
  for (var n = 2; ; n++) {
    final id = '$base-$n';
    if (!taken.contains(id)) return id;
  }
}

/// Template id bound to a custom profile by default.
String defaultTemplateIdFor(String profileId) => '$profileId-default';

/// Runs the full PRF-01 validator on [draft] (no grammar) — for the editor's
/// "save" button state and tests.
ProfileValidation validateDraft(
  ProfileDraft draft, {
  Set<String> takenIds = const {},
}) =>
    const ProfileValidator().validate(draft.toDefinition(), takenIds: takenIds);
