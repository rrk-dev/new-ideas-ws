import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/flavor_provider.dart';
import 'package:vaultvoice/core/widgets/placeholder_screen.dart';
import 'package:vaultvoice/features/recording/presentation/call_guard_debug_screen.dart';
import 'package:vaultvoice/features/recording/presentation/recording_debug_screen.dart';

/// Placeholder for the Record tab (AUD-08 builds the real UI). The dev
/// flavor exposes the AUD-01 recording and SEC-09 CallGuard debug screens
/// from the app bar.
class RecordScreen extends ConsumerWidget {
  const RecordScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDev = ref.watch(flavorProvider).isDev;
    return PlaceholderScreen(
      title: 'Record',
      icon: Icons.mic,
      actions: [
        if (isDev)
          IconButton(
            tooltip: 'Recording debug',
            icon: const Icon(Icons.graphic_eq),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const RecordingDebugScreen(),
              ),
            ),
          ),
        if (isDev)
          IconButton(
            tooltip: 'CallGuard debug',
            icon: const Icon(Icons.phone_disabled),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CallGuardDebugScreen(),
              ),
            ),
          ),
      ],
    );
  }
}
