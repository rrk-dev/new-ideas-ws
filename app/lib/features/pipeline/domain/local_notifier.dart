import 'package:vaultvoice/features/pipeline/domain/processing_notification.dart';

/// The user tapped a notification (or one of its actions).
class NotificationTap {
  const NotificationTap({required this.payload, this.actionId});

  /// Typed-route location from [ProcessingNotification.payload].
  final String payload;

  /// `null` for a tap on the notification body.
  final String? actionId;

  @override
  String toString() => 'NotificationTap($payload, action: $actionId)';
}

/// Local (on-device) notifications. No push service, no network: the OS
/// shows what the app posts. Real implementation:
/// `FlutterLocalNotifier` (flutter_local_notifications); tests use
/// `FakeLocalNotifier`.
abstract interface class LocalNotifier {
  /// Registers channels/categories and the tap handler. Safe to call once.
  Future<void> initialize({
    required ProcessingNotificationTexts texts,
    required void Function(NotificationTap tap) onTap,
  });

  /// The tap that launched the app from a terminated state, if any.
  Future<NotificationTap?> launchTap();

  /// Asks for the OS permission (Android 13+, iOS). Returns whether
  /// notifications may be shown.
  Future<bool> requestPermission();

  Future<void> show(ProcessingNotification notification);
}

/// Shows nothing (unsupported platforms and before initialisation).
class NoopLocalNotifier implements LocalNotifier {
  const NoopLocalNotifier();

  @override
  Future<void> initialize({
    required ProcessingNotificationTexts texts,
    required void Function(NotificationTap tap) onTap,
  }) async {}

  @override
  Future<NotificationTap?> launchTap() async => null;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> show(ProcessingNotification notification) async {}
}
