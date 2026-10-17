import 'package:flutter/material.dart';

/// Round tonal icon button for app bars (UIX-01). Keeps the 48 dp tap target.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 4),
    child: IconButton.filledTonal(
      tooltip: tooltip,
      icon: Icon(icon),
      onPressed: onPressed,
    ),
  );
}

/// Style that gives a [PopupMenuButton] the same round tonal look.
ButtonStyle circleMenuStyle(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return IconButton.styleFrom(
    backgroundColor: scheme.secondaryContainer,
    foregroundColor: scheme.onSecondaryContainer,
    minimumSize: const Size(48, 48),
  );
}
