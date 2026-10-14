import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vaultvoice/features/pipeline/domain/local_notifier.dart';
import 'package:vaultvoice/features/pipeline/domain/processing_notification.dart';

/// [LocalNotifier] on `flutter_local_notifications` 22.3.1 (API verified
/// against the pinned package source; dependency review in
/// docs/privacy-audit.md). Purely local — the plugin has no network code.
///
/// Android: channel "Processing", low importance (vv-flutter-architecture →
/// Local notifications). Generic notifications are `public` on the lock
/// screen; ones that reveal the recording title are `private`, so the lock
/// screen shows only "VaultVoice — Contents hidden".
/// iOS: a `processing_failed` category with a foreground "Retry" action;
/// previews on the lock screen follow the system "Show Previews" setting
/// (default "When Unlocked").
class FlutterLocalNotifier implements LocalNotifier {
  FlutterLocalNotifier({
    FlutterLocalNotificationsPlugin? plugin,
    this.channelName = 'Processing',
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Android channel name shown in system settings (localised by caller).
  final String channelName;

  static const channelId = 'processing';
  static const _failedCategory = 'processing_failed';

  final FlutterLocalNotificationsPlugin _plugin;
  ProcessingNotificationTexts? _texts;

  @override
  Future<void> initialize({
    required ProcessingNotificationTexts texts,
    required void Function(NotificationTap tap) onTap,
  }) async {
    _texts = texts;
    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Permission is requested just-in-time (requestPermission).
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
          notificationCategories: [
            DarwinNotificationCategory(
              _failedCategory,
              actions: [
                DarwinNotificationAction.plain(
                  NotificationActions.retry,
                  texts.retryAction,
                  options: {DarwinNotificationActionOption.foreground},
                ),
              ],
            ),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: (r) {
        final tap = _toTap(r);
        if (tap != null) onTap(tap);
      },
    );
  }

  @override
  Future<NotificationTap?> launchTap() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    final response = details?.notificationResponse;
    if (details?.didNotificationLaunchApp != true || response == null) {
      return null;
    }
    return _toTap(response);
  }

  @override
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ?? false;
    }
    if (Platform.isIOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(alert: true, sound: true) ?? false;
    }
    return false;
  }

  @override
  Future<void> show(ProcessingNotification n) async {
    final failed = n.kind == ProcessingNotificationKind.failed;
    await _plugin.show(
      id: n.id,
      title: n.title,
      body: n.body,
      payload: n.payload,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.low,
          priority: Priority.low,
          visibility: n.revealsContent
              ? NotificationVisibility.private
              : NotificationVisibility.public,
          category: failed
              ? AndroidNotificationCategory.error
              : AndroidNotificationCategory.status,
          actions: [
            for (final (id, label) in n.actions)
              AndroidNotificationAction(id, label, showsUserInterface: true),
          ],
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: failed && _texts != null ? _failedCategory : null,
          threadIdentifier: channelId,
        ),
      ),
    );
  }

  static NotificationTap? _toTap(NotificationResponse r) {
    final payload = r.payload;
    if (payload == null || payload.isEmpty) return null;
    final action = r.actionId;
    return NotificationTap(
      payload: payload,
      actionId: action == null || action.isEmpty ? null : action,
    );
  }
}
