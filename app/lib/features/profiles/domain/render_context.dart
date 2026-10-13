import 'package:vaultvoice/features/profiles/domain/post_processors.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/domain/profile_schema.dart';

/// Shape of the Mustache rendering context (profile spec → "Rendering
/// context passed to templates"). One source of truth for both the
/// template-variable check (validation time) and the context normalizer
/// (render time, EXP-01), so a template that validates cannot hit a missing
/// key under `lenient: false`.
sealed class ContextShape {
  const ContextShape({required this.nullable});

  final bool nullable;
}

/// A map. Every entry of [fields] is always present after normalization;
/// each name in [helpersFor] also gets a `has_<name>` bool.
final class MapShape extends ContextShape {
  const MapShape(
    this.fields, {
    this.helpersFor = const {},
    super.nullable = false,
  });

  final Map<String, ContextShape> fields;
  final Set<String> helpersFor;

  /// The shape of key [name], including `has_*` helpers (always bools).
  ContextShape? lookup(String name) {
    if (fields[name] case final shape?) return shape;
    if (name.startsWith('has_') && helpersFor.contains(name.substring(4))) {
      return const ScalarShape(ScalarKind.boolean);
    }
    return null;
  }
}

final class ListShape extends ContextShape {
  const ListShape(this.item) : super(nullable: false);

  final ContextShape item;
}

enum ScalarKind { string, number, boolean }

final class ScalarShape extends ContextShape {
  const ScalarShape(this.kind, {super.nullable = false});

  final ScalarKind kind;
}

/// Names of the context root keys.
abstract final class ContextKeys {
  static const String data = 'data';
  static const String meta = 'meta';
  static const String transcript = 'transcript';
}

ScalarShape _str({bool nullable = false}) =>
    ScalarShape(ScalarKind.string, nullable: nullable);

/// `meta` — recording metadata supplied by the app (profile spec).
final MapShape kMetaShape = _withHelpers({
  'recording_id': _str(),
  'title': _str(nullable: true),
  'date': _str(),
  'time': _str(),
  'duration_ms': const ScalarShape(ScalarKind.number),
  'duration_human': _str(),
  'profile_id': _str(),
  'profile_name': _str(),
  'speakers': ListShape(
    _withHelpers({'label': _str(), 'name': _str(nullable: true)}),
  ),
  'tags': ListShape(_str()),
  'markers': ListShape(
    _withHelpers({'t': _str(), 'label': _str(nullable: true), 'kind': _str()}),
  ),
  'model_ids': _withHelpers({
    'stt': _str(nullable: true),
    'llm': _str(nullable: true),
  }),
  'app_version': _str(),
  'device': _str(nullable: true),
  'consent_at': _str(nullable: true),
});

/// `transcript` — speaker-labelled segments.
final MapShape kTranscriptShape = _withHelpers({
  'segments': ListShape(
    _withHelpers({
      't': _str(),
      'speaker': _str(nullable: true),
      'text': _str(),
    }),
  ),
});

/// Adds a `has_<field>` helper for every list, every scalar except
/// non-nullable bools, and every nullable map (superset of the spec's
/// "every list and nullable scalar": a non-nullable string can still be
/// empty → null).
MapShape _withHelpers(
  Map<String, ContextShape> fields, {
  bool nullable = false,
}) => MapShape(
  fields,
  nullable: nullable,
  helpersFor: {
    for (final e in fields.entries)
      if (_needsHelper(e.value)) e.key,
  },
);

bool _needsHelper(ContextShape shape) => switch (shape) {
  ListShape() => true,
  ScalarShape(:final kind, :final nullable) =>
    kind != ScalarKind.boolean || nullable,
  MapShape(:final nullable) => nullable,
};

/// Shape of `data` for [profile]: schema fields plus fields added by its
/// post-processors (e.g. `due_iso`, `warranty_expiry`), each with helpers.
MapShape dataShapeFor(Profile profile) =>
    _objectShape(profile.schema, profile.postProcess.toSet(), isRoot: true);

MapShape _objectShape(
  ObjectSchema object,
  Set<PostProcessor> processors, {
  required bool isRoot,
}) {
  final fields = <String, ContextShape>{
    for (final e in object.properties.entries)
      e.key: _nodeShape(e.value, processors),
  };
  for (final e in derivedFields(object, processors, isRoot: isRoot).entries) {
    fields.putIfAbsent(e.key, () => _nodeShape(e.value, processors));
  }
  return _withHelpers(fields, nullable: object.nullable);
}

ContextShape _nodeShape(SchemaNode node, Set<PostProcessor> processors) =>
    switch (node) {
      ObjectSchema() => _objectShape(node, processors, isRoot: false),
      ArraySchema(:final items) => ListShape(_nodeShape(items, processors)),
      StringSchema(:final nullable) => _str(nullable: nullable),
      NumberSchema(:final nullable) => ScalarShape(
        ScalarKind.number,
        nullable: nullable,
      ),
      BooleanSchema(:final nullable) => ScalarShape(
        ScalarKind.boolean,
        nullable: nullable,
      ),
    };

/// Root shape: `{data, meta, transcript}` plus a root `has_<field>` alias
/// for every top-level data helper (so templates can write
/// `{{#has_attendees}}` as in the built-in meeting template).
MapShape rootShapeFor(Profile profile) {
  final data = dataShapeFor(profile);
  return MapShape({
    ContextKeys.data: data,
    ContextKeys.meta: kMetaShape,
    ContextKeys.transcript: kTranscriptShape,
  }, helpersFor: data.helpersFor);
}

/// Normalizes [value] against [shape] (the context normalizer contract):
/// every field present (null when unknown), empty / whitespace-only strings
/// → null, values of the wrong type → null (lists → `[]`), null entries
/// dropped from lists, and a `has_<field>` bool next to every helper field
/// (true when the list is non-empty / the value is non-null).
Object? normalizeToShape(ContextShape shape, Object? value) {
  switch (shape) {
    case ScalarShape(:final kind):
      return switch (kind) {
        ScalarKind.string =>
          value is String && value.trim().isNotEmpty ? value : null,
        ScalarKind.number => value is num ? value : null,
        ScalarKind.boolean => value is bool ? value : null,
      };
    case ListShape(:final item):
      if (value is! List<Object?>) return const <Object?>[];
      return [for (final e in value) ?normalizeToShape(item, e)];
    case MapShape(:final fields, :final nullable):
      if (value is! Map<String, Object?>) {
        if (nullable) return null;
        return normalizeToShape(shape, const <String, Object?>{});
      }
      final out = <String, Object?>{
        for (final e in fields.entries)
          e.key: normalizeToShape(e.value, value[e.key]),
      };
      for (final f in fields.keys) {
        if (shape.helpersFor.contains(f)) out['has_$f'] = _present(out[f]);
      }
      return out;
  }
}

bool _present(Object? v) => v is List<Object?> ? v.isNotEmpty : v != null;

/// Builds the full rendering context for [profile] from the post-processed
/// extraction [data], the app-supplied [meta] and [transcript] maps.
Map<String, Object?> buildRenderContext({
  required Profile profile,
  required Map<String, Object?> data,
  required Map<String, Object?> meta,
  required Map<String, Object?> transcript,
}) {
  final dataShape = dataShapeFor(profile);
  final normalizedData =
      normalizeToShape(dataShape, data)! as Map<String, Object?>;
  return {
    ContextKeys.data: normalizedData,
    ContextKeys.meta: normalizeToShape(kMetaShape, meta),
    ContextKeys.transcript: normalizeToShape(kTranscriptShape, transcript),
    for (final f in dataShape.helpersFor) 'has_$f': normalizedData['has_$f'],
  };
}
