import 'package:vaultvoice/core/platform/clock.dart';

/// Manually advanced [Clock].
class FakeClock implements Clock {
  FakeClock([DateTime? start]) : _now = start ?? DateTime.utc(2026);

  DateTime _now;

  void advance(Duration d) => _now = _now.add(d);

  @override
  DateTime now() => _now;
}
