import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_queue_indicator.dart';

/// Bottom-navigation shell around the four tab branches, with the global
/// processing-queue indicator (APP-04) above the tab bar.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ProcessingQueueIndicator(),
          NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) => navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            ),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.mic),
                label: context.l10n.tabRecord,
              ),
              NavigationDestination(
                icon: const Icon(Icons.library_books),
                label: context.l10n.tabLibrary,
              ),
              NavigationDestination(
                icon: const Icon(Icons.tune),
                label: context.l10n.tabProfiles,
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings),
                label: context.l10n.tabSettings,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
