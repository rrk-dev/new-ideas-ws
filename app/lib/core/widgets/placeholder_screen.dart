import 'package:flutter/material.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';

/// Base screen used by features until their real UI lands.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    required this.title,
    required this.icon,
    this.actions,
    super.key,
  });

  final String title;
  final IconData icon;

  /// Optional app-bar actions (e.g. dev-flavor debug entries).
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: Center(
        child: Semantics(
          label: '$title screen placeholder',
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48, color: theme.colorScheme.primary),
                const SizedBox(height: AppSpacing.md),
                Text(title, style: theme.textTheme.titleLarge),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
