import 'dart:convert';

import 'package:vaultvoice/features/profiles/domain/profile_schema.dart';

/// Field descriptions generated from a profile output schema (PRF-02): one
/// bullet per property in declaration order — key, type in words, limits,
/// `enum` values, nullability, then the schema `description`. Small models
/// follow these much better than raw JSON Schema.
String describeSchemaFields(ObjectSchema schema) {
  final out = StringBuffer();
  _describeObject(schema, 0, out);
  return out.toString().trimRight();
}

void _describeObject(ObjectSchema schema, int depth, StringBuffer out) {
  final indent = '  ' * depth;
  for (final e in schema.properties.entries) {
    final node = e.value;
    final optional = schema.required.contains(e.key) ? '' : ', optional';
    final desc = node.description == null ? '' : ': ${node.description}';
    out.writeln('$indent- ${e.key} (${_typeText(node)}$optional)$desc');
    final nested = _nestedObject(node);
    if (nested != null) _describeObject(nested, depth + 1, out);
  }
}

ObjectSchema? _nestedObject(SchemaNode node) => switch (node) {
  ObjectSchema() => node,
  ArraySchema(:final items) => _nestedObject(items),
  _ => null,
};

String _typeText(SchemaNode node) {
  final base = switch (node) {
    ObjectSchema() => 'object with the fields below',
    ArraySchema(:final items, :final maxItems, :final minItems) =>
      'list of ${_itemText(items)}, '
          '${minItems != null && minItems > 0 ? '$minItems to ' : 'at most '}'
          '$maxItems items',
    StringSchema() => _stringText(node),
    NumberSchema(:final integer, :final enumValues) =>
      enumValues != null
          ? 'one of ${enumValues.join(', ')}'
          : integer
          ? 'whole number'
          : 'number',
    BooleanSchema() => 'true or false',
  };
  return node.nullable ? '$base, or null if unknown' : base;
}

String _itemText(SchemaNode items) => switch (items) {
  ObjectSchema() => 'objects with the fields below',
  ArraySchema() => 'lists',
  StringSchema() => _stringText(items, plural: true),
  NumberSchema(:final integer) => integer ? 'whole numbers' : 'numbers',
  BooleanSchema() => 'true/false values',
};

String _stringText(StringSchema s, {bool plural = false}) {
  if (s.enumValues case final values?) {
    return 'one of ${values.map(jsonEncode).join(', ')}';
  }
  final noun = s.format == 'date'
      ? (plural ? 'dates as spoken' : 'date as spoken')
      : (plural ? 'texts' : 'text');
  return s.maxLength == null ? noun : '$noun, max ${s.maxLength} chars';
}

/// [value] re-encoded with object keys in schema declaration order (unknown
/// keys last, in their original order) — the canonical form of few-shot
/// outputs, so examples look exactly like what the grammar produces.
Object? canonicalizeToSchema(Object? value, SchemaNode? schema) {
  if (value is Map<String, Object?>) {
    final props = schema is ObjectSchema
        ? schema.properties
        : const <String, SchemaNode>{};
    return {
      for (final k in props.keys)
        if (value.containsKey(k)) k: canonicalizeToSchema(value[k], props[k]),
      for (final e in value.entries)
        if (!props.containsKey(e.key)) e.key: e.value,
    };
  }
  if (value is List) {
    final items = schema is ArraySchema ? schema.items : null;
    return [for (final v in value) canonicalizeToSchema(v, items)];
  }
  return value;
}
