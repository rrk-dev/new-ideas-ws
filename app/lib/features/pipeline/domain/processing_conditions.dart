import 'package:flutter/foundation.dart';
import 'package:vaultvoice/features/extraction/domain/device_tiering.dart'
    show ThermalState;

/// Device state relevant to heavy processing (vv-background-execution →
/// Thermal & power), reported by the platform (`DeviceConditions` stream).
@immutable
final class DeviceConditions {
  const DeviceConditions({
    this.charging = false,
    this.lowPower = false,
    this.thermal = ThermalState.unknown,
  });

  /// Wire format of the background-processing channel
  /// (`{charging, lowPower, thermal}`); unknown values fall back to safe
  /// defaults (not charging, thermal unknown).
  factory DeviceConditions.fromMap(Object? raw) {
    if (raw is! Map) return const DeviceConditions();
    final thermal = raw['thermal'];
    return DeviceConditions(
      charging: raw['charging'] == true,
      lowPower: raw['lowPower'] == true,
      thermal: ThermalState.values.firstWhere(
        (t) => t.name == thermal,
        orElse: () => ThermalState.unknown,
      ),
    );
  }

  /// Plugged in (charging or full).
  final bool charging;

  /// iOS Low Power Mode / Android battery saver.
  final bool lowPower;
  final ThermalState thermal;

  @override
  bool operator ==(Object other) =>
      other is DeviceConditions &&
      other.charging == charging &&
      other.lowPower == lowPower &&
      other.thermal == thermal;

  @override
  int get hashCode => Object.hash(charging, lowPower, thermal);

  @override
  String toString() =>
      'DeviceConditions(charging: $charging, lowPower: $lowPower, '
      'thermal: ${thermal.name})';
}

/// Why processing is held back right now.
enum HoldReason {
  /// Thermal state `critical` (always) or `serious` (unless the user asked
  /// to process now) — iOS `ProcessInfo.thermalState`, Android
  /// `THERMAL_STATUS_SEVERE`+ maps to critical, `MODERATE` to serious.
  thermal,

  /// Low Power Mode / battery saver, unless the user asked to process now.
  lowPower,

  /// "Process only while charging" is on and the device is not charging,
  /// unless the user asked to process now.
  notCharging,

  /// The OS background time is used up (iOS expiration handler, Android
  /// foreground-service `onTimeout`): pause until the app is foreground.
  backgroundTimeExpired,
}

/// Whether the pipeline may run heavy steps now.
///
/// [userForced] = the job was started with "Process now" (user priority):
/// it overrides the charge-only setting, Low Power Mode and `serious`
/// thermal state, never `critical` or an expired background budget
/// (vv-background-execution).
HoldReason? holdReason(
  DeviceConditions conditions, {
  required bool chargeOnly,
  required bool userForced,
  bool backgroundExpired = false,
}) {
  if (conditions.thermal == ThermalState.critical) return HoldReason.thermal;
  if (backgroundExpired) return HoldReason.backgroundTimeExpired;
  if (userForced) return null;
  if (conditions.thermal == ThermalState.serious) return HoldReason.thermal;
  if (conditions.lowPower) return HoldReason.lowPower;
  if (chargeOnly && !conditions.charging) return HoldReason.notCharging;
  return null;
}
