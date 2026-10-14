import 'package:flutter/material.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/widgets/placeholder_screen.dart';

/// Placeholder for the Profiles tab.
class ProfilesScreen extends StatelessWidget {
  const ProfilesScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      PlaceholderScreen(title: context.l10n.tabProfiles, icon: Icons.tune);
}
