import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
            destinations: const [
              NavigationDestination(icon: Icon(Icons.mic), label: 'Record'),
              NavigationDestination(
                icon: Icon(Icons.library_books),
                label: 'Library',
              ),
              NavigationDestination(icon: Icon(Icons.tune), label: 'Profiles'),
              NavigationDestination(
                icon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
