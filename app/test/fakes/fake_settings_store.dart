import 'dart:async';
import 'dart:convert';

import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/settings/domain/settings_ports.dart';

/// In-memory [SettingsStore] (JSON round-trip like the real table) for
/// widget tests, which cannot drive drift streams inside fake async.
class FakeSettingsStore implements SettingsStore {
  FakeSettingsStore([Map<String, Object?> initial = const {}])
    : values = {for (final e in initial.entries) e.key: _roundTrip(e.value)};

  final Map<String, Object?> values;
  final _changes = StreamController<String>.broadcast();

  static Object? _roundTrip(Object? v) => jsonDecode(jsonEncode(v));

  @override
  Stream<Object?> watch(String key) async* {
    yield values[key];
    yield* _changes.stream.where((k) => k == key).map((_) => values[key]);
  }

  @override
  Future<Result<void>> set(String key, Object? value) async {
    values[key] = _roundTrip(value);
    _changes.add(key);
    return const Ok(null);
  }
}
