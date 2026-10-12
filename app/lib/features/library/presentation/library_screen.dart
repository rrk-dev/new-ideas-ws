import 'package:flutter/material.dart';
import 'package:vaultvoice/core/widgets/placeholder_screen.dart';

/// Placeholder for the Library tab.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Library', icon: Icons.library_books);
}
