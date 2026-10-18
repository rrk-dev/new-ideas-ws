import 'dart:async';

import 'package:vaultvoice/features/licensing/data/managed_config_source.dart';
import 'package:vaultvoice/features/licensing/domain/managed_config.dart';

/// A settable MDM configuration for tests (LIC-04).
class FakeManagedConfigSource implements ManagedConfigSource {
  FakeManagedConfigSource([this.config = ManagedConfig.none]);

  ManagedConfig config;
  final _changes = StreamController<ManagedConfig>.broadcast();

  /// Changes the configuration and notifies watchers.
  void set(ManagedConfig next) {
    config = next;
    _changes.add(next);
  }

  @override
  Future<ManagedConfig> read() async => config;

  @override
  Stream<ManagedConfig> watch() async* {
    yield config;
    yield* _changes.stream;
  }
}
