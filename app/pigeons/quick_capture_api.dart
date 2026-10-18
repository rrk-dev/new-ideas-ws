// Pigeon definition for the QCP-02 quick-capture hand-off (iOS only).
// Regenerate after editing (from app/):
//   fvm dart run pigeon --input pigeons/quick_capture_api.dart
//   fvm dart format lib/features/recording/data/pigeon/quick_capture_api.g.dart
//
// Verified against pigeon 29.0.8.
//
// The native side keeps at most one in-memory request (widget / control tap)
// that expires 10 s after it was issued. Everything here is static data:
// no recording-derived text (ADR-QCP-01 content rule).
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/features/recording/data/pigeon/quick_capture_api.g.dart',
    dartOptions: DartOptions(),
    swiftOut: 'ios/Runner/QuickCaptureApi.g.swift',
    swiftOptions: SwiftOptions(errorClassName: 'QuickCapturePigeonError'),
    dartPackageName: 'vaultvoice',
  ),
)
/// A pending navigate request.
class QuickCaptureRequestMessage {
  QuickCaptureRequestMessage({
    required this.id,
    required this.entry,
    required this.mode,
    required this.remainingMs,
  });

  /// Random UUIDv4.
  String id;

  /// Issuing surface (`iosWidget` / `iosControl`); routing only.
  String entry;

  /// Always `navigate`.
  String mode;

  /// Milliseconds until expiry, measured on the native monotonic clock.
  int remainingMs;
}

@HostApi()
abstract class QuickCaptureHostApi {
  /// Returns the pending request and deletes it; null when none, expired
  /// or already consumed.
  QuickCaptureRequestMessage? consumeRequest();
}
