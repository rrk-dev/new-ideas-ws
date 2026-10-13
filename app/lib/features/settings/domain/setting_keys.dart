/// Keys of the `settings` table (FND-04 key/value store, JSON values).
///
/// Every key is listed here once so features and the Settings screen agree
/// on names; renaming a key is a data migration.
abstract final class SettingKeys {
  /// bool, default `true`: post local notifications when a note is ready or
  /// processing failed (APP-04).
  static const notificationsEnabled = 'notifications.enabled';

  /// bool, default `false`: include the recording title in notifications.
  /// Off = generic text ("Your note is ready"), safe on the lock screen.
  static const notificationsShowDetails = 'notifications.show_details';

  /// bool: the OS notification permission prompt was shown once.
  static const notificationsPermissionAsked = 'notifications.permission_asked';
}
