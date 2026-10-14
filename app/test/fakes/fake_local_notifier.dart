import 'package:vaultvoice/features/pipeline/domain/local_notifier.dart';
import 'package:vaultvoice/features/pipeline/domain/processing_notification.dart';

/// Records what would be shown; [tap] simulates the user tapping one.
class FakeLocalNotifier implements LocalNotifier {
  FakeLocalNotifier({this.launch, this.grant = true});

  /// Tap that "launched" the app (returned once by [launchTap]).
  NotificationTap? launch;
  final bool grant;

  final List<ProcessingNotification> shown = [];
  int permissionRequests = 0;
  bool initialized = false;
  void Function(NotificationTap tap)? _onTap;

  @override
  Future<void> initialize({
    required ProcessingNotificationTexts texts,
    required void Function(NotificationTap tap) onTap,
  }) async {
    initialized = true;
    _onTap = onTap;
  }

  @override
  Future<NotificationTap?> launchTap() async {
    final l = launch;
    launch = null;
    return l;
  }

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return grant;
  }

  @override
  Future<void> show(ProcessingNotification notification) async =>
      shown.add(notification);

  /// Simulates a tap on [n] (or on its action [actionId]).
  void tap(ProcessingNotification n, {String? actionId}) =>
      _onTap?.call(NotificationTap(payload: n.payload, actionId: actionId));
}
