import 'dart:async';

import 'package:flutter/services.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/features/recording/domain/recording_indicator.dart';
import 'package:vaultvoice/features/recording/domain/recording_limits.dart';

/// [RecordingIndicator] backed by the app's platform code: Android
/// `RecordingIndicatorPlugin.kt` + `RecordingService.kt` (AUD-05), iOS
/// `RecordingIndicatorPlugin.swift` (AUD-04). Plain method/event channels
/// like CallGuard (ADR-SEC-09 → Channel).
class MethodChannelRecordingIndicator implements RecordingIndicator {
  MethodChannelRecordingIndicator({
    this._methods = const MethodChannel(methodChannelName),
    this._events = const EventChannel(eventChannelName),
    AppLocalizations Function()? l10n,
  }) : _l10n = l10n ?? (() => l10nFor(kFallbackLocale));

  static const methodChannelName = 'vaultvoice/recording_indicator';
  static const eventChannelName = 'vaultvoice/recording_indicator/actions';

  final MethodChannel _methods;
  final EventChannel _events;
  final AppLocalizations Function() _l10n;
  Stream<IndicatorAction>? _actions;

  /// Wire format of [content].
  static Map<String, Object?> encode(IndicatorContent content) => {
    'recording': content.recording,
    'title': content.title,
    'text': content.text,
    'chronometerBaseMs': content.chronometerBase?.millisecondsSinceEpoch,
    'actions': [for (final a in content.actions) a.name],
    'liveActivity': encodeLiveActivity(content),
  };

  /// AUD-13: the only data the iOS Live Activity receives — state and the
  /// timer's start instant, never title/text or anything recording-derived.
  static Map<String, Object?> encodeLiveActivity(IndicatorContent content) => {
    'recording': content.recording,
    'timerStartMs': content.chronometerBase?.millisecondsSinceEpoch,
  };

  @override
  Future<Result<void>> show(IndicatorContent content) =>
      _call('show', encode(content));

  @override
  Future<void> hide() async {
    await _call('hide');
  }

  @override
  void stillRecording(Duration elapsed) => unawaited(
    _call('remind', {'text': stillRecordingText(_l10n(), elapsed)}),
  );

  @override
  Stream<IndicatorAction> get actions => _actions ??= _events
      .receiveBroadcastStream()
      .map(IndicatorAction.tryParse)
      .where((a) => a != null)
      .cast<IndicatorAction>()
      .handleError((Object _) {});

  /// OEM / battery-optimization state for the guidance card (Android).
  Future<BatteryStatus?> batteryStatus() async {
    try {
      final m = await _methods.invokeMapMethod<String, Object?>(
        'batteryStatus',
      );
      if (m == null) return null;
      return BatteryStatus(
        manufacturer: (m['manufacturer'] as String?)?.toLowerCase() ?? '',
        ignoringOptimizations: m['ignoringOptimizations'] == true,
      );
    } on Object {
      return null; // iOS / unavailable: no guidance needed.
    }
  }

  /// Opens the system battery-optimization settings (Android).
  Future<void> openBatterySettings() async {
    await _call('openBatterySettings');
  }

  Future<Result<void>> _call(String method, [Object? args]) async {
    try {
      await _methods.invokeMethod<void>(method, args);
      return const Ok<void>(null);
    } on MissingPluginException {
      // Platform without an indicator implementation (tests, desktop).
      return const Ok<void>(null);
    } on PlatformException catch (e) {
      return Err(UnexpectedFailure('indicator ${e.code}'));
    }
  }
}

/// Battery-optimization state (Android).
final class BatteryStatus {
  const BatteryStatus({
    required this.manufacturer,
    required this.ignoringOptimizations,
  });

  /// `Build.MANUFACTURER`, lower-case.
  final String manufacturer;

  /// Whether the user exempted the app from battery optimization.
  final bool ignoringOptimizations;
}
