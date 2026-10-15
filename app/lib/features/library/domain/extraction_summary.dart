/// A display row of an extraction result: a field and its values as text.
typedef ExtractionField = ({String key, List<String> values});

/// Flattens extracted JSON for display: one row per top-level field (in
/// [order] when given — the profile schema's property order — then the
/// rest), strings as-is, lists as one value per item, objects as their
/// non-empty values joined with " · ". Empty fields are kept with no values.
List<ExtractionField> summarizeExtraction(
  Map<String, Object?> data, {
  List<String> order = const [],
}) {
  final keys = [
    for (final k in order)
      if (data.containsKey(k)) k,
    for (final k in data.keys)
      if (!order.contains(k)) k,
  ];
  return [for (final k in keys) (key: k, values: _values(data[k]))];
}

List<String> _values(Object? v) => switch (v) {
  null => const [],
  final List<Object?> list => [
    for (final item in list)
      if (_text(item) case final t? when t.isNotEmpty) t,
  ],
  _ => [?_text(v)],
};

String? _text(Object? v) => switch (v) {
  null => null,
  final String s => s.trim().isEmpty ? null : s.trim(),
  final num n => '$n',
  final bool b => '$b',
  final Map<String, Object?> m => [
    for (final e in m.values)
      if (_text(e) case final t? when t.isNotEmpty) t,
  ].join(' · '),
  final List<Object?> l => [
    for (final e in l)
      if (_text(e) case final t? when t.isNotEmpty) t,
  ].join(', '),
  _ => '$v',
};

/// `action_items` → `Action items`.
String humanizeFieldName(String key) {
  final words = key.replaceAll('_', ' ').trim();
  if (words.isEmpty) return key;
  return words[0].toUpperCase() + words.substring(1);
}
