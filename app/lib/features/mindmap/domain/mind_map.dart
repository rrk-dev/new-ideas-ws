import 'package:flutter/foundation.dart';

/// Limits of a stored mind map (ADR-MAP-01).
abstract final class MindMapLimits {
  /// Levels including the root.
  static const int maxDepth = 3;
  static const int maxNodes = 40;
  static const int maxLabel = 60;
}

final _timestamp = RegExp(r'^\d{2}:[0-5]\d:[0-5]\d$');

/// One node of a mind map: `{id, label, children[], t?}`. `t` is the
/// `hh:mm:ss` evidence timestamp of a real transcript line.
@immutable
final class MindMapNode {
  const MindMapNode({
    required this.id,
    required this.label,
    this.children = const [],
    this.t,
  });

  final String id;
  final String label;
  final List<MindMapNode> children;
  final String? t;

  int get count => 1 + children.fold(0, (n, c) => n + c.count);

  int get depth => 1 + children.fold(0, (d, c) => c.depth > d ? c.depth : d);

  Iterable<MindMapNode> get all sync* {
    yield this;
    for (final c in children) {
      yield* c.all;
    }
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'children': [for (final c in children) c.toJson()],
    if (t != null) 't': t,
  };
}

/// Strict structural check of a stored tree. Returns the problems found
/// (paths and rules only, never label text); empty means valid.
List<String> validateMindMap(
  Object? json, {
  Set<String>? transcriptTimestamps,
}) {
  final issues = <String>[];
  final ids = <String>{};
  var nodes = 0;

  void visit(Object? node, int depth, String path) {
    if (node is! Map) {
      issues.add('$path: not an object (orphan child)');
      return;
    }
    nodes++;
    final id = node['id'];
    if (id is! String || id.isEmpty) {
      issues.add('$path.id: missing');
    } else if (!ids.add(id)) {
      issues.add('$path.id: duplicate');
    }
    final label = node['label'];
    if (label is! String || label.trim().isEmpty) {
      issues.add('$path.label: empty');
    } else if (label.length > MindMapLimits.maxLabel) {
      issues.add('$path.label: over ${MindMapLimits.maxLabel} characters');
    }
    final t = node['t'];
    if (t != null) {
      if (t is! String || !_timestamp.hasMatch(t)) {
        issues.add('$path.t: malformed');
      } else if (transcriptTimestamps != null &&
          !transcriptTimestamps.contains(t)) {
        issues.add('$path.t: not a transcript timestamp');
      }
    }
    final children = node['children'];
    if (children is! List) {
      issues.add('$path.children: not a list');
      return;
    }
    if (children.isNotEmpty && depth >= MindMapLimits.maxDepth) {
      issues.add('$path: deeper than ${MindMapLimits.maxDepth} levels');
      return;
    }
    for (var i = 0; i < children.length; i++) {
      visit(children[i], depth + 1, '$path.children[$i]');
    }
  }

  visit(json, 1, r'$');
  if (nodes > MindMapLimits.maxNodes) {
    issues.add('\$: more than ${MindMapLimits.maxNodes} nodes');
  }
  if (json is Map &&
      json['children'] is List &&
      (json['children'] as List).isEmpty) {
    issues.add(r'$: no branches');
  }
  return issues;
}

/// Decides whether a label is supported by the transcript.
typedef LabelGrounding = bool Function(String label);

/// Deterministic repair of a raw tree: ids are reassigned (`n0…` in
/// pre-order, so duplicates and missing ids cannot survive), labels are
/// whitespace-collapsed and cut at [MindMapLimits.maxLabel], unsupported
/// labels (with their subtree), empty and sibling-duplicate labels are
/// dropped, unknown timestamps are removed, depth and node count are capped
/// breadth-first. Returns null when no branch is left (rejected, never
/// stored).
MindMapNode? normalizeMindMap(
  Object? raw, {
  Set<String>? transcriptTimestamps,
  LabelGrounding? grounded,
}) {
  if (raw is! Map) return null;
  var budget = MindMapLimits.maxNodes;

  String? cleanLabel(Object? v) {
    if (v is! String) return null;
    var s = v.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) return null;
    if (s.length > MindMapLimits.maxLabel) {
      final cut = s.substring(0, MindMapLimits.maxLabel);
      final space = cut.lastIndexOf(' ');
      s = (space > MindMapLimits.maxLabel ~/ 2 ? cut.substring(0, space) : cut)
          .trimRight();
    }
    return s;
  }

  String? cleanT(Object? v) {
    if (v is! String || !_timestamp.hasMatch(v)) return null;
    if (transcriptTimestamps != null && !transcriptTimestamps.contains(v)) {
      return null;
    }
    return v;
  }

  // Breadth-first so the node cap keeps the shallow (most useful) nodes.
  final rootLabel = cleanLabel(raw['label']);
  if (rootLabel == null) return null;
  final rootBuild = _Build(rootLabel, null);
  var level = <(_Build, Object?)>[(rootBuild, raw['children'])];
  budget--;
  for (var depth = 1; depth < MindMapLimits.maxDepth; depth++) {
    final next = <(_Build, Object?)>[];
    for (final (parent, rawChildren) in level) {
      if (rawChildren is! List) continue;
      final seen = <String>{};
      for (final c in rawChildren) {
        if (budget <= 0) break;
        if (c is! Map) continue;
        final label = cleanLabel(c['label']);
        if (label == null || !seen.add(label.toLowerCase())) continue;
        if (grounded != null && !grounded(label)) continue;
        final node = _Build(label, cleanT(c['t']));
        parent.children.add(node);
        budget--;
        next.add((node, c['children']));
      }
    }
    level = next;
  }
  if (rootBuild.children.isEmpty) return null;

  var n = 0;
  MindMapNode freeze(_Build b) {
    final id = 'n${n++}';
    return MindMapNode(
      id: id,
      label: b.label,
      t: b.t,
      children: [for (final c in b.children) freeze(c)],
    );
  }

  return freeze(rootBuild);
}

final class _Build {
  _Build(this.label, this.t);
  final String label;
  final String? t;
  final List<_Build> children = [];
}
