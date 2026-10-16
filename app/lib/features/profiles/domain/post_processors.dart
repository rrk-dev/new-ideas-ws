import 'package:vaultvoice/features/profiles/domain/profile_schema.dart';

/// The named Dart post-processors a profile may list in `post_process`
/// (profile spec). Unknown names are validation errors. The implementations
/// live with extraction (PRF-03/04/LLM-05); this is the contract: which
/// fields each one needs and which fields it adds to the extraction JSON —
/// the template-variable check and the render-context normalizer both use it.
enum PostProcessor {
  /// Relative dates ("next Friday") → absolute using the recording date.
  /// Adds a nullable `<field>_iso` sibling (YYYY-MM-DD) to every date field.
  resolveRelativeDates('resolve_relative_dates'),

  /// Root `warranty_expiry` = `purchase_date` + `warranty_period`.
  computeWarrantyExpiry('compute_warranty_expiry'),

  /// Uppercases/strips `serial_number`; spelled letters ("S as in Sam") → S.
  normalizeSerial('normalize_serial'),

  /// Maps `owner` values to speaker display names.
  mapOwnerToSpeaker('map_owner_to_speaker'),

  /// Sorts lists of objects with a `t` timestamp field by `t`.
  sortByTimestamp('sort_by_timestamp'),

  /// Nulls `t` values that do not exist in the transcript.
  dropUngroundedTimestamps('drop_ungrounded_timestamps'),

  /// Removes repeated items from every list (same text after
  /// normalization: case, punctuation, whitespace) — small models sometimes
  /// repeat one item until `maxItems`. Keeps the first occurrence.
  dedupeLists('dedupe_lists'),

  /// Drops list items whose key terms (< 50 %) do not occur in the transcript
  /// (inventions, or example text copied from the prompt), clears `owner`
  /// values nobody in the transcript matches, and replaces a `title` /
  /// `summary` / `context` that is not derived from the transcript (null when
  /// nullable, else the transcript's leading sentences).
  groundToTranscript('ground_to_transcript');

  PostProcessor(this.wireName);

  /// Name used in YAML/JSON definitions.
  final String wireName;

  static PostProcessor? fromWireName(String name) {
    for (final p in values) {
      if (p.wireName == name) return p;
    }
    return null;
  }
}

/// Whether a string field holds a date that `resolve_relative_dates`
/// resolves: `format: date`, or named `date`, `due` or `*_date`.
bool isDateField(String name, SchemaNode node) =>
    node is StringSchema &&
    (node.format == 'date' ||
        name == 'date' ||
        name == 'due' ||
        name.endsWith('_date'));

/// Name of the resolved sibling added by `resolve_relative_dates`.
String isoSiblingName(String field) => '${field}_iso';

/// Root field added by `compute_warranty_expiry` (ISO date or null).
const String kWarrantyExpiryField = 'warranty_expiry';

/// What [processor] needs from the schema to do anything; returns a problem
/// description, or null when the schema is suitable.
String? postProcessorRequirement(PostProcessor processor, ObjectSchema root) {
  bool anyField(bool Function(String name, SchemaNode node) test) =>
      _anyField(root, test);
  switch (processor) {
    case PostProcessor.resolveRelativeDates:
      return anyField(isDateField)
          ? null
          : 'needs a date field (string named date, due or *_date, or with '
                'format: date)';
    case PostProcessor.computeWarrantyExpiry:
      final purchase = root.properties['purchase_date'];
      final period = root.properties['warranty_period'];
      final periodOk =
          period is ObjectSchema &&
          period.properties['value'] is NumberSchema &&
          period.properties['unit'] is StringSchema;
      if (purchase is! StringSchema || !periodOk) {
        return 'needs root fields purchase_date (string) and warranty_period '
            '{value: number, unit: string}';
      }
      if (root.properties.containsKey(kWarrantyExpiryField)) {
        return '$kWarrantyExpiryField is computed in Dart; remove it from the '
            'schema (the model must not fill it)';
      }
      return null;
    case PostProcessor.normalizeSerial:
      return root.properties['serial_number'] is StringSchema
          ? null
          : 'needs a root string field serial_number';
    case PostProcessor.mapOwnerToSpeaker:
      return anyField((n, node) => n == 'owner' && node is StringSchema)
          ? null
          : 'needs a string field named owner';
    case PostProcessor.sortByTimestamp:
      final ok = anyField(
        (_, node) =>
            node is ArraySchema &&
            node.items is ObjectSchema &&
            (node.items as ObjectSchema).properties['t'] is StringSchema,
      );
      return ok ? null : 'needs a list of objects with a string field t';
    case PostProcessor.dropUngroundedTimestamps:
      return anyField((n, node) => n == 't' && node is StringSchema)
          ? null
          : 'needs a string field named t (hh:mm:ss timestamp)';
    case PostProcessor.dedupeLists:
      return anyField((_, node) => node is ArraySchema)
          ? null
          : 'needs a list field';
    case PostProcessor.groundToTranscript:
      return anyField((_, node) => node is ArraySchema) ||
              root.properties['title'] is StringSchema
          ? null
          : 'needs a list field or a string field named title';
  }
}

bool _anyField(
  ObjectSchema object,
  bool Function(String name, SchemaNode node) test,
) {
  for (final entry in object.properties.entries) {
    if (test(entry.key, entry.value)) return true;
    if (_anyFieldIn(entry.value, test)) return true;
  }
  return false;
}

bool _anyFieldIn(
  SchemaNode node,
  bool Function(String name, SchemaNode node) test,
) => switch (node) {
  ObjectSchema() => _anyField(node, test),
  ArraySchema(:final items) => _anyFieldIn(items, test),
  _ => false,
};

/// Fields [processors] add to [object] (at the given nesting [isRoot]):
/// name → node. Used to build the render-context shape.
Map<String, SchemaNode> derivedFields(
  ObjectSchema object,
  Set<PostProcessor> processors, {
  required bool isRoot,
}) {
  final out = <String, SchemaNode>{};
  if (processors.contains(PostProcessor.resolveRelativeDates)) {
    for (final entry in object.properties.entries) {
      if (isDateField(entry.key, entry.value)) {
        out[isoSiblingName(entry.key)] = const StringSchema(
          maxLength: 10,
          nullable: true,
          format: 'date',
        );
      }
    }
  }
  if (isRoot && processors.contains(PostProcessor.computeWarrantyExpiry)) {
    out[kWarrantyExpiryField] = const StringSchema(
      maxLength: 10,
      nullable: true,
      format: 'date',
    );
  }
  return out;
}
