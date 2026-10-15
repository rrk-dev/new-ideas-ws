import 'package:vaultvoice/core/db/repositories/settings_repository.dart';

/// Cross-isolate "a heavy model is in use by the profile preview" claim,
/// stored in settings (the preview runs on the UI isolate, the pipeline in a
/// worker isolate). Stale claims (crash) expire after [ttl].
class PreviewLease {
  PreviewLease(
    this._settings, {
    this.ttl = const Duration(minutes: 10),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const key = 'pipeline.previewLease';

  final SettingsRepository _settings;
  final Duration ttl;
  final DateTime Function() _now;

  Future<void> acquire() async {
    await _settings.set(key, _now().millisecondsSinceEpoch);
  }

  Future<void> release() async {
    await _settings.set(key, null);
  }

  Future<bool> isHeld() async {
    final v = (await _settings.get(key)).valueOrNull;
    if (v is! int) return false;
    return _now().millisecondsSinceEpoch - v < ttl.inMilliseconds;
  }
}
