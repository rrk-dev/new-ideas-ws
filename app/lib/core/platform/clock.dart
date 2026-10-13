/// Time source, injected so tests are deterministic.
abstract interface class Clock {
  DateTime now();
}

/// The real wall clock.
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}
