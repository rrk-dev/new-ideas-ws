import 'package:flutter/material.dart';
import 'package:vaultvoice/core/widgets/placeholder_screen.dart';

/// Placeholder for the Settings tab.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Settings', icon: Icons.settings);
}
