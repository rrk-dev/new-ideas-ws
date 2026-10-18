import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:vaultvoice/features/licensing/domain/managed_config.dart';

/// Where the MDM managed configuration comes from (LIC-04).
abstract interface class ManagedConfigSource {
  /// The configuration now; [ManagedConfig.none] when nothing is managed or
  /// the platform has no managed configuration (host, tests).
  Future<ManagedConfig> read();

  /// The current configuration, then every change.
  Stream<ManagedConfig> watch();
}

class NoManagedConfig implements ManagedConfigSource {
  const NoManagedConfig();

  @override
  Future<ManagedConfig> read() async => ManagedConfig.none;

  @override
  Stream<ManagedConfig> watch() => Stream.value(ManagedConfig.none);
}

/// [ManagedConfigSource] over channel `vaultvoice/managed_config`.
///
/// - iOS / macOS (`ManagedConfigPlugin.swift`): the dictionary under
///   `UserDefaults.standard` key `com.apple.configuration.managed`, with
///   `UserDefaults.didChangeNotification` as the change signal.
/// - Android (`ManagedConfigPlugin.kt`): `RestrictionsManager
///   .getApplicationRestrictions()`, with a runtime-registered
///   `ACTION_APPLICATION_RESTRICTIONS_CHANGED` receiver.
///
/// `read` -> JSON text of the dictionary (null = nothing managed). The
/// platform calls `changed` (no arguments) when it may have changed; the
/// configuration is then re-read. Content-free: nothing here is logged.
class PlatformManagedConfigSource implements ManagedConfigSource {
  PlatformManagedConfigSource([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'changed' && !_changes.isClosed) {
        _changes.add(await read());
      }
      return null;
    });
  }

  static const channelName = 'vaultvoice/managed_config';

  final MethodChannel _channel;
  final _changes = StreamController<ManagedConfig>.broadcast();

  @override
  Future<ManagedConfig> read() async {
    try {
      final text = await _channel.invokeMethod<String>('read');
      if (text == null || text.isEmpty) return ManagedConfig.none;
      final json = jsonDecode(text);
      if (json is! Map<String, Object?>) return ManagedConfig.none;
      return ManagedConfig.parse(json);
    } on Object {
      // No platform implementation, a platform error or malformed text:
      // nothing is managed (managed values only ever tighten the app).
      return ManagedConfig.none;
    }
  }

  @override
  Stream<ManagedConfig> watch() async* {
    yield await read();
    yield* _changes.stream;
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    unawaited(_changes.close());
  }
}
