/// Approach A (ADR-MAP-01): deterministic projection of an extraction's JSON
/// into a raw tree. No LLM call; labels are the extraction's own (already
/// grounded) text, so the result is normalized without a grounding filter.
Map<String, Object?>? projectExtraction(
  Map<String, Object?>? extraction, {
  required String fallbackTitle,
}) {
  if (extraction == null) return null;
  final title = _text(extraction['title']) ?? fallbackTitle;
  final branches = <Map<String, Object?>>[];
  for (final entry in extraction.entries) {
    if (entry.key == 'title' || entry.key == 'summary') continue;
    final children = _children(entry.value);
    if (children.isEmpty) continue;
    branches.add(_node(_humanize(entry.key), null, children));
  }
  if (branches.isEmpty) return null;
  return _node(title, null, branches);
}

Map<String, Object?> _node(
  String label,
  String? t,
  List<Map<String, Object?>> children,
) => {'label': label, 't': ?t, 'children': children};

String _humanize(String key) {
  final words = key.replaceAll('_', ' ').trim();
  return words.isEmpty ? key : words[0].toUpperCase() + words.substring(1);
}

String? _text(Object? v) => switch (v) {
  final String s when s.trim().isNotEmpty => s.trim(),
  final num n => '$n',
  _ => null,
};

// Fields that name an item, in priority order.
const _labelKeys = [
  'term',
  'heading',
  'task',
  'option',
  'objection',
  'question',
  'name',
  'what',
  'text',
  'label',
  'topic',
  'title',
];

List<Map<String, Object?>> _children(Object? value) {
  switch (value) {
    case final List<Object?> list:
      return [for (final item in list) ?_item(item)];
    case final Map<Object?, Object?> map:
      final text = [for (final v in map.values) ?_text(v)].join(' ');
      return text.isEmpty ? const [] : [_node(text, null, const [])];
    default:
      final s = _text(value);
      return s == null ? const [] : [_node(s, null, const [])];
  }
}

Map<String, Object?>? _item(Object? item) {
  if (item is String || item is num) {
    final s = _text(item);
    return s == null ? null : _node(s, null, const []);
  }
  if (item is! Map) return null;
  String? label;
  for (final k in _labelKeys) {
    label = _text(item[k]);
    if (label != null) break;
  }
  label ??= [
    for (final v in item.values)
      if (v is String && v.trim().isNotEmpty) v.trim(),
  ].firstOrNull;
  if (label == null) return null;
  final sub = <Map<String, Object?>>[];
  for (final v in item.values) {
    if (v is List) {
      for (final p in v) {
        if (_text(p) case final s?) sub.add(_node(s, null, const []));
      }
    }
  }
  final t = item['t'];
  return _node(label, t is String ? t : null, sub);
}
