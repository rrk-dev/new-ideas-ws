import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/features/mindmap/domain/mind_map.dart';
import 'package:vaultvoice/features/mindmap/domain/mind_map_layout.dart';

/// Graphical mind map (MAP-03): cards, curved connectors, pan and pinch-zoom.
/// The layout is computed once per collapse change, never per frame.
class MindMapGraph extends StatefulWidget {
  const MindMapGraph({
    required this.root,
    required this.collapsed,
    required this.selectedId,
    required this.onNodeTap,
    required this.onStampTap,
    required this.exportKey,
    super.key,
  });

  final MindMapNode root;
  final Set<String> collapsed;
  final String? selectedId;
  final ValueChanged<MindMapNode> onNodeTap;
  final void Function(MindMapNode node) onStampTap;

  /// Boundary of the whole graph, used for the PNG export.
  final GlobalKey exportKey;

  @override
  State<MindMapGraph> createState() => _MindMapGraphState();
}

class _MindMapGraphState extends State<MindMapGraph> {
  final _controller = TransformationController();
  MindMapLayout? _layout;
  Set<String>? _layoutFor;
  double _scale = 1;
  Size _viewport = Size.zero;
  bool _fitted = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  MindMapLayout _ensureLayout(double textScale) {
    final collapsed = widget.collapsed;
    final cached = _layout;
    if (cached != null &&
        _scale == textScale &&
        _layoutFor != null &&
        setEquals(_layoutFor!, collapsed) &&
        identical(cached.nodes.first.node, widget.root)) {
      return cached;
    }
    _scale = textScale;
    _layoutFor = {...collapsed};
    return _layout = MindMapLayout.compute(
      widget.root,
      collapsed: collapsed,
      nodeHeight: math.max(
        kMinInteractiveDimension + AppSpacing.md,
        24 + 40 * textScale,
      ),
    );
  }

  static bool setEquals(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  void _fit() {
    final layout = _layout;
    if (layout == null || _viewport.isEmpty) return;
    const pad = AppSpacing.md;
    final w = layout.width + pad * 2;
    final h = layout.height + pad * 2;
    final s = math
        .min(_viewport.width / w, _viewport.height / h)
        .clamp(0.1, 1.0);
    final tx = (_viewport.width - w * s) / 2 + pad * s;
    final ty = (_viewport.height - h * s) / 2 + pad * s;
    _controller.value = Matrix4.translationValues(tx, ty, 0)
      ..scaleByDouble(s, s, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final layout = _ensureLayout(MediaQuery.textScalerOf(context).scale(1));
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = constraints.biggest;
        if (!_fitted) {
          _fitted = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _fit();
          });
        }
        return Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                key: const ValueKey('mindmap-graph'),
                transformationController: _controller,
                constrained: false,
                minScale: 0.1,
                maxScale: 3,
                boundaryMargin: const EdgeInsets.all(AppSpacing.xxxl * 2),
                child: RepaintBoundary(
                  key: widget.exportKey,
                  child: ColoredBox(
                    color: scheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: SizedBox(
                        width: layout.width,
                        height: layout.height,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _EdgePainter(layout, scheme.outline),
                              ),
                            ),
                            for (final p in layout.nodes)
                              Positioned(
                                left: p.x,
                                top: p.y,
                                width: layout.nodeWidth,
                                height: layout.nodeHeight,
                                child: _NodeCard(
                                  key: ValueKey('mindmap-card-${p.node.id}'),
                                  placement: p,
                                  selected: widget.selectedId == p.node.id,
                                  onTap: () => widget.onNodeTap(p.node),
                                  onStampTap: () => widget.onStampTap(p.node),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: AppSpacing.sm,
              top: AppSpacing.sm,
              child: IconButton.filledTonal(
                key: const ValueKey('mindmap-fit'),
                tooltip: l10n.mindMapFit,
                onPressed: _fit,
                icon: const Icon(Icons.fit_screen_outlined),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter(this.layout, this.color);

  final MindMapLayout layout;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final path = Path();
    for (final e in layout.edges) {
      final a = layout.nodes[e.parent];
      final b = layout.nodes[e.child];
      final start = Offset(a.x + layout.nodeWidth, a.y + layout.nodeHeight / 2);
      final end = Offset(b.x, b.y + layout.nodeHeight / 2);
      final mid = (start.dx + end.dx) / 2;
      path
        ..moveTo(start.dx, start.dy)
        ..cubicTo(mid, start.dy, mid, end.dy, end.dx, end.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_EdgePainter old) =>
      !identical(old.layout, layout) || old.color != color;
}

class _NodeCard extends StatelessWidget {
  const _NodeCard({
    required this.placement,
    required this.selected,
    required this.onTap,
    required this.onStampTap,
    super.key,
  });

  final MindMapPlacement placement;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onStampTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final node = placement.node;
    final (bg, fg) = switch (placement.level) {
      0 => (scheme.primary, scheme.onPrimary),
      1 => (scheme.primaryContainer, scheme.onPrimaryContainer),
      _ => (scheme.surfaceContainerHighest, scheme.onSurface),
    };
    final style = (placement.level == 0 ? text.titleSmall : text.bodyMedium)
        ?.copyWith(color: fg);
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      expanded: placement.hasChildren ? !placement.collapsed : null,
      label: l10n.mindMapNodeSemantics(node.label, placement.level + 1),
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: selected
                ? BorderSide(color: scheme.tertiary, width: 3)
                : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      node.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: style,
                    ),
                  ),
                  if (node.t != null)
                    Tooltip(
                      message: l10n.mindMapOpenTranscript(node.t!),
                      child: InkWell(
                        key: ValueKey('mindmap-stamp-${node.id}'),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        onTap: onStampTap,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: kMinInteractiveDimension,
                            minHeight: kMinInteractiveDimension,
                          ),
                          child: Center(
                            child: Text(
                              node.t!,
                              style: text.labelSmall?.copyWith(color: fg),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (placement.hasChildren)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: Icon(
                        placement.collapsed
                            ? Icons.chevron_right
                            : Icons.expand_more,
                        size: AppSizes.iconSm,
                        color: fg,
                      ),
                    )
                  else
                    const SizedBox(width: AppSpacing.sm),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
