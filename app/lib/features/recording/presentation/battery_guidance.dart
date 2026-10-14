import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/features/recording/data/method_channel_recording_indicator.dart';
import 'package:vaultvoice/features/recording/data/recording_providers.dart';

/// Manufacturers whose battery managers are known to stop long background
/// work despite a foreground service (dontkillmyapp.com ranking).
const kAggressiveOems = {
  'samsung',
  'xiaomi',
  'redmi',
  'poco',
  'oneplus',
  'oppo',
  'realme',
  'vivo',
  'huawei',
  'honor',
};

/// OEM-specific steps to keep long recordings alive (AUD-05). Null when no
/// guidance is needed (not Android, already exempt, or a stock-like OEM).
String? batteryGuidanceText(BatteryStatus? status) {
  if (status == null || status.ignoringOptimizations) return null;
  final oem = status.manufacturer;
  if (!kAggressiveOems.contains(oem)) return null;
  final steps = switch (oem) {
    'samsung' =>
      'Settings → Battery → Background usage limits → Never sleeping apps → '
          'add VaultVoice.',
    'xiaomi' || 'redmi' || 'poco' =>
      'Settings → Apps → VaultVoice → Battery saver → No restrictions, and '
          'turn on Autostart.',
    'oneplus' ||
    'oppo' ||
    'realme' => 'Settings → Battery → VaultVoice → Allow background activity.',
    _ => 'In battery settings, allow VaultVoice to run in the background.',
  };
  return 'Long recordings can be stopped by this phone’s battery saver when '
      'the screen is off. $steps';
}

/// Shows [batteryGuidanceText] above [child] with a button that opens the
/// system battery-optimization settings. Renders [child] unchanged when no
/// guidance applies. Never requests `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`
/// (Play policy) — the user changes the setting themselves.
class BatteryGuidance extends ConsumerWidget {
  const BatteryGuidance({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(batteryStatusProvider).value;
    final text = batteryGuidanceText(status);
    if (text == null) return child;
    return Column(
      children: [
        Material(
          child: SafeArea(
            bottom: false,
            child: MaterialBanner(
              padding: const EdgeInsets.all(AppSpacing.md),
              leading: const Icon(Icons.battery_alert),
              content: Text(text),
              actions: [
                TextButton(
                  onPressed: () => unawaited(
                    ref
                        .read(platformRecordingIndicatorProvider)
                        .openBatterySettings(),
                  ),
                  child: const Text('Open battery settings'),
                ),
              ],
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
