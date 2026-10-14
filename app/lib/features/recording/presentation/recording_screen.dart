import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/flavor_provider.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/widgets/placeholder_screen.dart';
import 'package:vaultvoice/features/recording/presentation/audio_import_flow.dart';
import 'package:vaultvoice/features/recording/presentation/battery_guidance.dart';
import 'package:vaultvoice/features/recording/presentation/call_guard_debug_screen.dart';
import 'package:vaultvoice/features/recording/presentation/recording_debug_screen.dart';
import 'package:vaultvoice/features/recording/presentation/recording_indicator_binding.dart';
import 'package:vaultvoice/features/recording/presentation/recovered_recordings_prompt.dart';

/// Placeholder for the Record tab (AUD-08 builds the real UI). The dev
/// flavor exposes the AUD-01 recording and SEC-09 CallGuard debug screens
/// from the app bar.
class RecordScreen extends ConsumerWidget {
  const RecordScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDev = ref.watch(flavorProvider).isDev;
    // Keeps the OS recording indicator (notification) in sync (AUD-05).
    ref.watch(recordingIndicatorBindingProvider);
    // The launch screen: offers recordings recovered after a crash (AUD-07)
    // and OEM battery-saver guidance (AUD-05).
    return RecoveredRecordingsPrompt(
      // AUD-06: files shared into the app (share sheet / "Open in").
      child: SharedAudioImportListener(
        child: BatteryGuidance(
          child: PlaceholderScreen(
            title: context.l10n.tabRecord,
            icon: Icons.mic,
            actions: [
              // AUD-06: import an audio file recorded elsewhere.
              const ImportAudioButton(),
              if (isDev)
                IconButton(
                  tooltip: context.l10n.recordingDebugTooltip,
                  icon: const Icon(Icons.graphic_eq),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RecordingDebugScreen(),
                    ),
                  ),
                ),
              if (isDev)
                IconButton(
                  tooltip: context.l10n.callGuardDebugTooltip,
                  icon: const Icon(Icons.phone_disabled),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CallGuardDebugScreen(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
