import 'package:flutter/material.dart';
import 'package:vaultvoice/core/widgets/placeholder_screen.dart';

/// Placeholder for the Record tab.
class RecordScreen extends StatelessWidget {
  const RecordScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Record', icon: Icons.mic);
}
