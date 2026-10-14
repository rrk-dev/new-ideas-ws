import 'package:vaultvoice/features/profiles/domain/profile_issue.dart';

/// The JSON-Schema subset a profile output schema may use (profile spec
/// format 1, `vv-llm-inference` → "Constrained output"). Everything here
/// converts to a bounded GBNF grammar: every array has `maxItems`, every free
/// string has `maxLength`, no `$ref`/`oneOf`/recursion.
const Set<String> kSupportedSchemaKeywords = {
  'type',
  'properties',
  'required',
  'items',
  'enum',
  'maxItems',
  'minItems',
  'maxLength',
  'description',
  'format',
};

/// Field names: same rule as the custom profile editor (PRF-07). The `has_`
/// prefix is reserved for render-context helpers.
final RegExp kFieldNamePattern = RegExp(r'^[a-z][a-z0-9_]{0,39}$');

/// Limits that keep grammars and prompts small enough for on-device models.
abstract final class SchemaLimits {
  static const int maxDepth = 6;
  static const int maxProperties = 40;
  static const int maxItems = 200;
  static const int maxLength = 4000;
  static const int maxEnumValues = 50;
  static const int maxDescription = 300;
}

/// JSON types of the supported subset (`null` is expressed via
/// [SchemaNode.nullable]).
enum SchemaType { object, array, string, integer, number, boolean }

/// A parsed node of a profile output schema.
sealed class SchemaNode {
  const SchemaNode({required this.nullable, this.description});

  /// `type: [<t>, "null"]`.
  final bool nullable;
  final String? description;

  SchemaType get type;

  /// Canonical JSON (stable key order) — what is stored and sent to the
  /// grammar converter.
  Map<String, Object?> toJson() => {
    'type': nullable ? [type.name, 'null'] : type.name,
    'description': ?description,
    ..._extraJson(),
  };

  Map<String, Object?> _extraJson();
}

final class ObjectSchema extends SchemaNode {
  const ObjectSchema({
    required this.properties,
    this.required = const [],
    super.nullable = false,
    super.description,
  });

  /// Properties in declaration order (the prompt and templates use it).
  final Map<String, SchemaNode> properties;
  final List<String> required;

  @override
  SchemaType get type => SchemaType.object;

  @override
  Map<String, Object?> _extraJson() => {
    if (required.isNotEmpty) 'required': [...required],
    'properties': {for (final e in properties.entries) e.key: e.value.toJson()},
  };
}

final class ArraySchema extends SchemaNode {
  const ArraySchema({
    required this.items,
    required this.maxItems,
    this.minItems,
    super.description,
  }) : super(nullable: false);

  final SchemaNode items;
  final int maxItems;
  final int? minItems;

  @override
  SchemaType get type => SchemaType.array;

  @override
  Map<String, Object?> _extraJson() => {
    'maxItems': maxItems,
    'minItems': ?minItems,
    'items': items.toJson(),
  };
}

final class StringSchema extends SchemaNode {
  const StringSchema({
    this.maxLength,
    this.enumValues,
    this.format,
    super.nullable = false,
    super.description,
  });

  /// Required unless [enumValues] bounds the string.
  final int? maxLength;
  final List<String>? enumValues;

  /// Only `date` (a prompt hint; dates are resolved in Dart).
  final String? format;

  @override
  SchemaType get type => SchemaType.string;

  @override
  Map<String, Object?> _extraJson() => {
    'maxLength': ?maxLength,
    if (enumValues case final values?) 'enum': [...values],
    'format': ?format,
  };
}

final class NumberSchema extends SchemaNode {
  const NumberSchema({
    required this.integer,
    this.enumValues,
    super.nullable = false,
    super.description,
  });

  final bool integer;
  final List<num>? enumValues;

  @override
  SchemaType get type => integer ? SchemaType.integer : SchemaType.number;

  @override
  Map<String, Object?> _extraJson() => {
    if (enumValues case final values?) 'enum': [...values],
  };
}

final class BooleanSchema extends SchemaNode {
  const BooleanSchema({super.nullable = false, super.description});

  @override
  SchemaType get type => SchemaType.boolean;

  @override
  Map<String, Object?> _extraJson() => const {};
}

/// Path of the item node of the array at [path] (`schema.attendees[]`).
String itemsPath(String path) => '$path[]';

/// Parses [json] as a schema node of the supported subset, reporting every
/// problem to [sink]. Returns null when the node is unusable.
SchemaNode? parseSchemaNode(
  Object? json,
  String path,
  IssueSink sink, {
  int depth = 1,
}) {
  if (json is! Map<String, Object?>) {
    sink.add(path, 'must be a schema object (a map with "type")');
    return null;
  }
  if (depth > SchemaLimits.maxDepth) {
    sink.add(
      path,
      'nested deeper than ${SchemaLimits.maxDepth} levels; flatten the '
      'schema (small models and grammars need flat-ish schemas)',
    );
    return null;
  }
  for (final key in json.keys) {
    if (!kSupportedSchemaKeywords.contains(key)) {
      sink.add(
        path,
        'unsupported keyword "$key" (supported: '
        '${kSupportedSchemaKeywords.join(', ')})',
      );
    }
  }
  final typeInfo = _parseType(json['type'], path, sink);
  if (typeInfo == null) return null;
  final (type, nullable) = typeInfo;

  final description = _parseDescription(json['description'], path, sink);
  void notFor(String keyword, String appliesTo) {
    if (json.containsKey(keyword)) {
      sink.add(path, '"$keyword" applies to $appliesTo only, not ${type.name}');
    }
  }

  if (json.containsKey('format') && type != SchemaType.string) {
    notFor('format', 'strings');
  }
  switch (type) {
    case SchemaType.object:
      notFor('items', 'arrays');
      notFor('maxItems', 'arrays');
      notFor('minItems', 'arrays');
      notFor('maxLength', 'strings');
      notFor('enum', 'strings and numbers');
      return _parseObject(json, path, sink, depth, nullable, description);
    case SchemaType.array:
      notFor('properties', 'objects');
      notFor('required', 'objects');
      notFor('maxLength', 'strings');
      notFor('enum', 'strings and numbers');
      if (nullable) {
        sink.add(
          path,
          'arrays cannot be nullable; drop "null" from type — an empty list '
          'means "nothing found"',
        );
      }
      return _parseArray(json, path, sink, depth, description);
    case SchemaType.string:
      notFor('properties', 'objects');
      notFor('required', 'objects');
      notFor('items', 'arrays');
      notFor('maxItems', 'arrays');
      notFor('minItems', 'arrays');
      return _parseString(json, path, sink, nullable, description);
    case SchemaType.integer:
    case SchemaType.number:
    case SchemaType.boolean:
      notFor('properties', 'objects');
      notFor('required', 'objects');
      notFor('items', 'arrays');
      notFor('maxItems', 'arrays');
      notFor('minItems', 'arrays');
      notFor('maxLength', 'strings');
      if (type == SchemaType.boolean) {
        notFor('enum', 'strings and numbers');
        return BooleanSchema(nullable: nullable, description: description);
      }
      return NumberSchema(
        integer: type == SchemaType.integer,
        enumValues: _parseNumberEnum(json['enum'], path, sink),
        nullable: nullable,
        description: description,
      );
  }
}

(SchemaType, bool)? _parseType(Object? raw, String path, IssueSink sink) {
  const hint =
      'use one of object, array, string, integer, number, boolean, '
      'optionally with "null" (e.g. type: [string, "null"])';
  if (raw == null) {
    sink.add(path, 'missing "type"; $hint');
    return null;
  }
  final names = switch (raw) {
    final String s => [s],
    // YAML reads an unquoted `null` list entry as a real null.
    final List<Object?> l => [for (final e in l) e?.toString() ?? 'null'],
    _ => null,
  };
  if (names == null || names.isEmpty) {
    sink.add(path, 'invalid "type"; $hint');
    return null;
  }
  final nullable = names.contains('null');
  final rest = names.where((n) => n != 'null').toList();
  if (rest.length != 1 || names.length > 2) {
    sink.add(
      path,
      'invalid "type" ${names.join('|')}: exactly one non-null type is '
      'allowed (unions are not supported); $hint',
    );
    return null;
  }
  final type = SchemaType.values.where((t) => t.name == rest.single);
  if (type.isEmpty) {
    sink.add(path, 'unknown type "${rest.single}"; $hint');
    return null;
  }
  return (type.single, nullable);
}

String? _parseDescription(Object? raw, String path, IssueSink sink) {
  if (raw == null) return null;
  if (raw is! String) {
    sink.add(path, '"description" must be a string');
    return null;
  }
  if (raw.length > SchemaLimits.maxDescription) {
    sink.add(
      path,
      '"description" is ${raw.length} chars, max '
      '${SchemaLimits.maxDescription} (it is inserted into the prompt)',
    );
  }
  return raw;
}

ObjectSchema? _parseObject(
  Map<String, Object?> json,
  String path,
  IssueSink sink,
  int depth,
  bool nullable,
  String? description,
) {
  final rawProps = json['properties'];
  if (rawProps is! Map<String, Object?> || rawProps.isEmpty) {
    sink.add(path, 'object needs a non-empty "properties" map');
    return null;
  }
  if (rawProps.length > SchemaLimits.maxProperties) {
    sink.add(
      path,
      '${rawProps.length} properties, max ${SchemaLimits.maxProperties}',
    );
  }
  final properties = <String, SchemaNode>{};
  for (final entry in rawProps.entries) {
    final name = entry.key;
    final childPath = joinPath(path, name);
    if (!kFieldNamePattern.hasMatch(name)) {
      sink.add(
        childPath,
        'invalid field name; use lower_snake_case matching '
        '${kFieldNamePattern.pattern}',
      );
    } else if (name.startsWith('has_')) {
      sink.add(
        childPath,
        'field names must not start with "has_" (reserved for the '
        'render-context helpers generated for every field)',
      );
    }
    final child = parseSchemaNode(entry.value, childPath, sink, depth: depth);
    if (child != null) properties[name] = child;
  }

  final required = <String>[];
  final rawRequired = json['required'];
  if (rawRequired != null) {
    if (rawRequired is! List<Object?>) {
      sink.add(path, '"required" must be a list of property names');
    } else {
      for (final r in rawRequired) {
        if (r is! String || !rawProps.containsKey(r)) {
          sink.add(
            path,
            '"required" lists "$r", which is not a property; add it to '
            '"properties" or remove it from "required"',
          );
        } else if (required.contains(r)) {
          sink.add(path, '"required" lists "$r" twice');
        } else {
          required.add(r);
        }
      }
    }
  }
  return ObjectSchema(
    properties: properties,
    required: required,
    nullable: nullable,
    description: description,
  );
}

ArraySchema? _parseArray(
  Map<String, Object?> json,
  String path,
  IssueSink sink,
  int depth,
  String? description,
) {
  final maxItems = json['maxItems'];
  int? max;
  if (maxItems == null) {
    sink.add(
      path,
      'missing maxItems — every array needs one (e.g. maxItems: 20) so the '
      'grammar cannot loop',
    );
  } else if (maxItems is! int ||
      maxItems < 1 ||
      maxItems > SchemaLimits.maxItems) {
    sink.add(
      path,
      'maxItems must be an integer between 1 and ${SchemaLimits.maxItems}',
    );
  } else {
    max = maxItems;
  }
  final minItems = json['minItems'];
  int? min;
  if (minItems != null) {
    if (minItems is! int || minItems < 0) {
      sink.add(path, 'minItems must be a non-negative integer');
    } else if (max != null && minItems > max) {
      sink.add(path, 'minItems ($minItems) is larger than maxItems ($max)');
    } else {
      min = minItems;
    }
  }
  if (!json.containsKey('items')) {
    sink.add(path, 'array needs "items" describing each element');
    return null;
  }
  final items = parseSchemaNode(
    json['items'],
    itemsPath(path),
    sink,
    depth: depth + 1,
  );
  if (items == null || max == null) return null;
  return ArraySchema(
    items: items,
    maxItems: max,
    minItems: min,
    description: description,
  );
}

StringSchema _parseString(
  Map<String, Object?> json,
  String path,
  IssueSink sink,
  bool nullable,
  String? description,
) {
  List<String>? enumValues;
  final rawEnum = json['enum'];
  if (rawEnum != null) {
    if (rawEnum is! List<Object?> || rawEnum.isEmpty) {
      sink.add(path, '"enum" must be a non-empty list of strings');
    } else if (rawEnum.length > SchemaLimits.maxEnumValues) {
      sink.add(
        path,
        '"enum" has ${rawEnum.length} values, max '
        '${SchemaLimits.maxEnumValues}',
      );
    } else if (rawEnum.any((e) => e is! String || e.isEmpty)) {
      sink.add(path, '"enum" values of a string field must be non-empty text');
    } else if (rawEnum.toSet().length != rawEnum.length) {
      sink.add(path, '"enum" contains duplicate values');
    } else {
      enumValues = rawEnum.cast<String>();
    }
  }
  final rawMax = json['maxLength'];
  int? maxLength;
  if (rawMax == null) {
    // An enum already bounds the string; free text never is.
    if (rawEnum == null) {
      sink.add(
        path,
        'missing maxLength — every string needs one (e.g. maxLength: 200) so '
        'the grammar cannot loop',
      );
    }
  } else if (rawMax is! int || rawMax < 1 || rawMax > SchemaLimits.maxLength) {
    sink.add(
      path,
      'maxLength must be an integer between 1 and ${SchemaLimits.maxLength}',
    );
  } else {
    maxLength = rawMax;
  }
  final format = json['format'];
  if (format != null && format != 'date') {
    sink.add(path, 'unsupported format "$format" (only "date" is supported)');
  }
  return StringSchema(
    maxLength: maxLength,
    enumValues: enumValues,
    format: format == 'date' ? 'date' : null,
    nullable: nullable,
    description: description,
  );
}

List<num>? _parseNumberEnum(Object? raw, String path, IssueSink sink) {
  if (raw == null) return null;
  if (raw is! List<Object?> || raw.isEmpty || raw.any((e) => e is! num)) {
    sink.add(path, '"enum" of a number field must be a non-empty number list');
    return null;
  }
  return raw.cast<num>();
}

/// Checks that [value] conforms to [node] (used for few-shot examples and,
/// in LLM-05, for model output). Messages describe types and limits only,
/// never the offending value.
void validateInstance(
  SchemaNode node,
  Object? value,
  String path,
  IssueSink sink,
) {
  if (value == null) {
    if (!node.nullable) {
      sink.add(path, 'is null but the schema does not allow null');
    }
    return;
  }
  switch (node) {
    case ObjectSchema(:final properties, :final required):
      if (value is! Map<String, Object?>) {
        sink.add(path, 'expected an object, got ${_jsonType(value)}');
        return;
      }
      for (final name in required) {
        if (!value.containsKey(name)) {
          sink.add(joinPath(path, name), 'required field is missing');
        }
      }
      for (final entry in value.entries) {
        final child = properties[entry.key];
        final childPath = joinPath(path, entry.key);
        if (child == null) {
          sink.add(childPath, 'is not defined in the schema');
        } else {
          validateInstance(child, entry.value, childPath, sink);
        }
      }
    case ArraySchema(:final items, :final maxItems, :final minItems):
      if (value is! List<Object?>) {
        sink.add(path, 'expected an array, got ${_jsonType(value)}');
        return;
      }
      if (value.length > maxItems) {
        sink.add(path, 'has ${value.length} items, maxItems is $maxItems');
      }
      if (minItems != null && value.length < minItems) {
        sink.add(path, 'has ${value.length} items, minItems is $minItems');
      }
      for (var i = 0; i < value.length; i++) {
        validateInstance(items, value[i], '$path[$i]', sink);
      }
    case StringSchema(:final maxLength, :final enumValues):
      if (value is! String) {
        sink.add(path, 'expected a string, got ${_jsonType(value)}');
        return;
      }
      if (maxLength != null && value.length > maxLength) {
        sink.add(path, 'is ${value.length} chars, maxLength is $maxLength');
      }
      if (enumValues != null && !enumValues.contains(value)) {
        sink.add(path, 'is not one of ${enumValues.join(', ')}');
      }
    case NumberSchema(:final integer, :final enumValues):
      final ok = integer
          ? value is int || (value is double && value == value.truncate())
          : value is num;
      if (!ok) {
        final want = integer ? 'an integer' : 'a number';
        sink.add(path, 'expected $want, got ${_jsonType(value)}');
        return;
      }
      if (enumValues != null && !enumValues.contains(value)) {
        sink.add(path, 'is not one of ${enumValues.join(', ')}');
      }
    case BooleanSchema():
      if (value is! bool) {
        sink.add(path, 'expected a boolean, got ${_jsonType(value)}');
      }
  }
}

String _jsonType(Object value) => switch (value) {
  Map<Object?, Object?>() => 'an object',
  List<Object?>() => 'an array',
  String() => 'a string',
  bool() => 'a boolean',
  num() => 'a number',
  _ => 'an unsupported value',
};
