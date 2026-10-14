import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
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
/// Strings come from [l] (English when omitted, e.g. in unit tests).
String? batteryGuidanceText(BatteryStatus? status, [AppLocalizations? l]) {
  if (status == null || status.ignoringOptimizations) return null;
  final oem = status.manufacturer;
  if (!kAggressiveOems.contains(oem)) return null;
  final s = l ?? lookupAppLocalizations(kFallbackLocale);
  final steps = switch (oem) {
    'samsung' => s.batteryGuidanceSamsung,
    'xiaomi' || 'redmi' || 'poco' => s.batteryGuidanceXiaomi,
    'oneplus' || 'oppo' || 'realme' => s.batteryGuidanceOnePlus,
    _ => s.batteryGuidanceGeneric,
  };
  return s.batteryGuidanceIntro(steps);
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
    final text = batteryGuidanceText(status, context.l10n);
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
                  child: Text(context.l10n.batteryGuidanceOpenSettings),
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
