/// Validates LLM output JSON against a profile output schema (LLM-05).
///
/// Supports the profile-schema subset (vv-llm-inference → Constrained
/// output): `type` (single or list), `enum`, `const`, `required`,
/// `properties`, `additionalProperties: false`, `items`, `minItems` /
/// `maxItems`, `minLength` / `maxLength`, `pattern`, `minimum` / `maximum`.
/// Unknown keywords are ignored (the grammar already enforced syntax).
///
/// Issues name the JSON path and the rule only — never the offending value —
/// so they can be logged and fed back into a repair prompt safely.
final class OutputSchemaValidator {
  const OutputSchemaValidator();

  List<String> validate(Object? value, Map<String, Object?> schema) {
    final issues = <String>[];
    _check(value, schema, r'$', issues);
    return issues;
  }

  void _check(
    Object? v,
    Map<String, Object?> s,
    String path,
    List<String> out,
  ) {
    final type = s['type'];
    if (type != null) {
      final types = type is List ? type.cast<String>() : [type as String];
      if (!types.any((t) => _isType(v, t))) {
        out.add('$path: expected ${types.join('|')}');
        return;
      }
    }
    if (s['enum'] case final List<Object?> options
        when !options.any((o) => _equals(o, v))) {
      out.add('$path: not one of the allowed values');
    }
    if (s.containsKey('const') && !_equals(s['const'], v)) {
      out.add('$path: must equal the constant');
    }
    switch (v) {
      case final String str:
        final len = str.runes.length;
        if (s['maxLength'] case final num max when len > max) {
          out.add('$path: longer than maxLength $max');
        }
        if (s['minLength'] case final num min when len < min) {
          out.add('$path: shorter than minLength $min');
        }
        if (s['pattern'] case final String p when !RegExp(p).hasMatch(str)) {
          out.add('$path: does not match pattern');
        }
      case final num n:
        if (s['minimum'] case final num min when n < min) {
          out.add('$path: below minimum $min');
        }
        if (s['maximum'] case final num max when n > max) {
          out.add('$path: above maximum $max');
        }
      case final List<Object?> list:
        if (s['maxItems'] case final num max when list.length > max) {
          out.add('$path: more than maxItems $max');
        }
        if (s['minItems'] case final num min when list.length < min) {
          out.add('$path: fewer than minItems $min');
        }
        if (s['items'] case final Map<String, Object?> item) {
          for (var i = 0; i < list.length; i++) {
            _check(list[i], item, '$path[$i]', out);
          }
        }
      case final Map<String, Object?> obj:
        final props = (s['properties'] as Map<String, Object?>?) ?? const {};
        for (final r in (s['required'] as List<Object?>?) ?? const []) {
          if (!obj.containsKey(r)) out.add('$path.$r: required');
        }
        for (final e in obj.entries) {
          final sub = props[e.key];
          if (sub is Map<String, Object?>) {
            _check(e.value, sub, '$path.${e.key}', out);
          } else if (s['additionalProperties'] == false) {
            out.add('$path.${e.key}: not allowed');
          }
        }
    }
  }

  static bool _isType(Object? v, String t) => switch (t) {
    'string' => v is String,
    'integer' => v is int || (v is double && v == v.roundToDouble()),
    'number' => v is num,
    'boolean' => v is bool,
    'object' => v is Map,
    'array' => v is List,
    'null' => v == null,
    _ => true,
  };

  static bool _equals(Object? a, Object? b) {
    if (a is num && b is num) return a == b;
    return a == b;
  }
}
