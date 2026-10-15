import 'package:flutter/foundation.dart';
import 'package:vaultvoice/features/extraction/domain/long_transcript/transcript_chunker.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';

/// One map result: the schema-valid partial JSON of chunk [chunkIndex]
/// (null when that chunk's extraction failed validation twice).
@immutable
final class PartialResult {
  const PartialResult({
    required this.chunkIndex,
    required this.chunkStartMs,
    required this.data,
  });

  final int chunkIndex;

  /// Offset of the chunk's first line: the sort time of items without `t`.
  final int chunkStartMs;
  final Map<String, Object?>? data;
}

/// Deterministic part of the reduce step.
@immutable
final class ReduceOutput {
  const ReduceOutput({required this.data, required this.proseInputs});

  /// Merged fields (every `llm_summarize` field is absent).
  final Map<String, Object?> data;

  /// `llm_summarize` field → its non-empty chunk values in time order.
  final Map<String, List<String>> proseInputs;
}

/// Lower-case word tokens (letters/digits of any script).
Set<String> _words(String s) => s
    .toLowerCase()
    .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
    .where((w) => w.isNotEmpty)
    .toSet();

/// Token Jaccard similarity of two strings (1.0 for equal word sets).
double tokenJaccard(String a, String b) {
  final x = _words(a);
  final y = _words(b);
  if (x.isEmpty && y.isEmpty) return a.trim() == b.trim() ? 1 : 0;
  final inter = x.intersection(y).length;
  return inter / (x.length + y.length - inter);
}

/// Merges partial map results per top-level field with the profile's
/// `reduce` strategies (docs/profile-spec.md → `reduce`), entirely in Dart:
///
/// - `union_dedupe` (lists): union in chunk order; an item is a duplicate of
///   an earlier one when its text has token Jaccard ≥ [similarity], or when
///   both carry the same evidence timestamp `t` and Jaccard ≥
///   [sameTimestampSimilarity] (the overlap region yields the same item
///   twice, often reworded). Duplicates are merged (missing/null fields
///   filled from the later copy). Lists of objects are then stably sorted by
///   time (`t`, else the chunk start) and capped at `maxItems`.
/// - `first_non_null`: the first non-null (non-empty) value in time order.
/// - `max` / `min`: over non-null numbers or strings (ISO dates sort).
/// - `llm_summarize`: collected for the LLM reduce
///   ([ReduceOutput.proseInputs]).
final class PartialReducer {
  const PartialReducer({
    this.similarity = 0.8,
    this.sameTimestampSimilarity = 0.5,
    this.evidenceKey = 't',
  });

  final double similarity;
  final double sameTimestampSimilarity;
  final String evidenceKey;

  ReduceOutput reduce({
    required Map<String, Object?> schema,
    required ReduceStrategy Function(String field) strategyFor,
    required List<PartialResult> partials,
  }) {
    final ordered = [...partials]
      ..sort((a, b) => a.chunkIndex.compareTo(b.chunkIndex));
    final props = (schema['properties'] as Map<String, Object?>?) ?? const {};
    final data = <String, Object?>{};
    final prose = <String, List<String>>{};
    for (final entry in props.entries) {
      final field = entry.key;
      final fieldSchema = entry.value! as Map<String, Object?>;
      final values = [
        for (final p in ordered)
          if (p.data case final d? when d.containsKey(field))
            (value: d[field], startMs: p.chunkStartMs),
      ];
      switch (strategyFor(field)) {
        case ReduceStrategy.unionDedupe:
          data[field] = _union(values, fieldSchema);
        case ReduceStrategy.firstNonNull:
          data[field] = values
              .map((v) => v.value)
              .firstWhere(_present, orElse: () => null);
        case ReduceStrategy.max:
          data[field] = _extreme(values.map((v) => v.value), max: true);
        case ReduceStrategy.min:
          data[field] = _extreme(values.map((v) => v.value), max: false);
        case ReduceStrategy.llmSummarize:
          prose[field] = [
            for (final v in values)
              if (v.value case final String s when s.trim().isNotEmpty)
                s.trim(),
          ];
      }
    }
    return ReduceOutput(data: data, proseInputs: prose);
  }

  static bool _present(Object? v) =>
      v != null && !(v is String && v.trim().isEmpty);

  static Object? _extreme(Iterable<Object?> values, {required bool max}) {
    Object? best;
    for (final v in values) {
      if (v is! num && v is! String) continue;
      if (v is String && v.trim().isEmpty) continue;
      if (best == null) {
        best = v;
        continue;
      }
      final c = v is num && best is num
          ? v.compareTo(best)
          : v.toString().compareTo(best.toString());
      if (max ? c > 0 : c < 0) best = v;
    }
    return best;
  }

  List<Object?> _union(
    List<({Object? value, int startMs})> values,
    Map<String, Object?> fieldSchema,
  ) {
    final items = <({Object? item, int time, int seq})>[];
    var seq = 0;
    if (values.isEmpty) return const [];
    final itemSchema = fieldSchema['items'] as Map<String, Object?>?;
    for (final v in values) {
      final list = v.value;
      if (list is! List) {
        if (_present(list)) {
          items.add((item: list, time: v.startMs, seq: seq++));
        }
        continue;
      }
      for (final x in list) {
        final dup = _findDuplicate(items, x, itemSchema);
        if (dup >= 0) {
          final d = items[dup];
          items[dup] = (item: _merge(d.item, x), time: d.time, seq: d.seq);
          continue;
        }
        final t = x is Map ? parseTimestamp(x[evidenceKey] as String?) : null;
        items.add((item: x, time: t ?? v.startMs, seq: seq++));
      }
    }
    if (items.any((i) => i.item is Map)) {
      items.sort((a, b) {
        final c = a.time.compareTo(b.time);
        return c != 0 ? c : a.seq.compareTo(b.seq);
      });
    }
    final maxItems = (fieldSchema['maxItems'] as num?)?.toInt();
    final out = [for (final i in items) i.item];
    return maxItems != null && out.length > maxItems
        ? out.sublist(0, maxItems)
        : out;
  }

  int _findDuplicate(
    List<({Object? item, int time, int seq})> items,
    Object? x,
    Map<String, Object?>? itemSchema,
  ) {
    final text = _text(x, itemSchema);
    final t = x is Map ? x[evidenceKey] : null;
    for (var i = 0; i < items.length; i++) {
      final other = items[i].item;
      if (x is Map != other is Map) continue;
      final sim = tokenJaccard(text, _text(other, itemSchema));
      if (sim >= similarity) return i;
      if (t is String &&
          other is Map &&
          other[evidenceKey] == t &&
          sim >= sameTimestampSimilarity) {
        return i;
      }
    }
    return -1;
  }

  /// Identity text of a list item: a string itself; for objects the
  /// required, non-nullable, non-enum string properties (e.g. `task`), else
  /// every string value except the evidence key.
  String _text(Object? x, Map<String, Object?>? itemSchema) {
    if (x is String) return x;
    if (x is! Map) return x?.toString() ?? '';
    final props =
        (itemSchema?['properties'] as Map<String, Object?>?) ?? const {};
    final required = (itemSchema?['required'] as List<Object?>?) ?? const [];
    final keys = [
      for (final e in props.entries)
        if (e.key != evidenceKey &&
            required.contains(e.key) &&
            e.value is Map &&
            (e.value! as Map)['type'] == 'string' &&
            !(e.value! as Map).containsKey('enum'))
          e.key,
    ];
    final use = keys.isNotEmpty
        ? keys
        : [
            for (final k in x.keys)
              if (k != evidenceKey && x[k] is String) k as String,
          ];
    return use.map((k) => x[k]?.toString() ?? '').join(' ');
  }

  /// Keeps [a]; fills its null/empty fields from [b] (first_non_null per
  /// key), recursively for nested objects.
  static Object? _merge(Object? a, Object? b) {
    if (a is! Map || b is! Map) return _present(a) ? a : b;
    final out = <String, Object?>{...a.cast<String, Object?>()};
    for (final e in b.entries) {
      final k = e.key as String;
      final cur = out[k];
      if (!_present(cur)) {
        out[k] = e.value;
      } else if (cur is Map && e.value is Map) {
        out[k] = _merge(cur, e.value);
      }
    }
    return out;
  }
}
