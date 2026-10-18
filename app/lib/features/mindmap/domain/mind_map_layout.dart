import 'package:flutter/foundation.dart';
import 'package:vaultvoice/features/mindmap/domain/mind_map.dart';

/// One positioned card of the graph (MAP-03).
@immutable
final class MindMapPlacement {
  const MindMapPlacement({
    required this.node,
    required this.level,
    required this.x,
    required this.y,
    required this.hasChildren,
    required this.collapsed,
  });

  final MindMapNode node;
  final int level;
  final double x;
  final double y;
  final bool hasChildren;
  final bool collapsed;
}

/// Parent → child connector, as indexes into [MindMapLayout.nodes].
@immutable
final class MindMapEdge {
  const MindMapEdge(this.parent, this.child);

  final int parent;
  final int child;
}

/// Deterministic left-to-right tree layout. Pure Dart: the same tree and
/// parameters always give the same positions.
@immutable
final class MindMapLayout {
  const MindMapLayout._({
    required this.nodes,
    required this.edges,
    required this.width,
    required this.height,
    required this.nodeWidth,
    required this.nodeHeight,
  });

  /// Lays out [root]; nodes whose id is in [collapsed] hide their children.
  factory MindMapLayout.compute(
    MindMapNode root, {
    Set<String> collapsed = const {},
    double nodeWidth = 200,
    double nodeHeight = 64,
    double hGap = 56,
    double vGap = 16,
  }) {
    layoutRuns++;
    final nodes = <MindMapPlacement>[];
    final edges = <MindMapEdge>[];
    var nextLeafY = 0.0;

    // Returns the index of the placed node; parents centre on their children.
    int place(MindMapNode n, int level) {
      final hidden = collapsed.contains(n.id);
      final kids = hidden ? const <MindMapNode>[] : n.children;
      final index = nodes.length;
      nodes.add(
        MindMapPlacement(
          node: n,
          level: level,
          x: level * (nodeWidth + hGap),
          y: 0,
          hasChildren: n.children.isNotEmpty,
          collapsed: hidden,
        ),
      );
      double y;
      if (kids.isEmpty) {
        y = nextLeafY;
        nextLeafY += nodeHeight + vGap;
      } else {
        final childIndexes = [for (final c in kids) place(c, level + 1)];
        for (final c in childIndexes) {
          edges.add(MindMapEdge(index, c));
        }
        y = (nodes[childIndexes.first].y + nodes[childIndexes.last].y) / 2;
      }
      final p = nodes[index];
      nodes[index] = MindMapPlacement(
        node: p.node,
        level: p.level,
        x: p.x,
        y: y,
        hasChildren: p.hasChildren,
        collapsed: p.collapsed,
      );
      return index;
    }

    place(root, 0);
    var maxX = 0.0;
    for (final n in nodes) {
      if (n.x > maxX) maxX = n.x;
    }
    return MindMapLayout._(
      nodes: nodes,
      edges: edges,
      width: maxX + nodeWidth,
      height: nextLeafY - vGap,
      nodeWidth: nodeWidth,
      nodeHeight: nodeHeight,
    );
  }

  /// Counts layout runs; tests use it to prove panning does not relayout.
  @visibleForTesting
  static int layoutRuns = 0;

  final List<MindMapPlacement> nodes;
  final List<MindMapEdge> edges;
  final double width;
  final double height;
  final double nodeWidth;
  final double nodeHeight;
}
