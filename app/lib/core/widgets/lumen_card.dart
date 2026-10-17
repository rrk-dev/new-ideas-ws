import 'package:flutter/material.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';

/// Soft bordered card on the themed surface: large radius, no shadow. Pass
/// [onTap] for a tappable card; [padding] defaults to none so a [ListTile]
/// child keeps its own insets.
class LumenCard extends StatelessWidget {
  const LumenCard({
    required this.child,
    this.onTap,
    this.padding = EdgeInsets.zero,
    this.margin = const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.xs,
    ),
    this.tonal = false,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  /// Uses the quieter container colour instead of the raised white surface.
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = Padding(padding: padding, child: child);
    return Padding(
      padding: margin,
      child: Card(
        margin: EdgeInsets.zero,
        color: tonal ? scheme.surfaceContainer : null,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}
