import 'dart:math';

import '../fakes/fake_clock.dart';
import '../fakes/fake_id_generator.dart';

/// Seed for every pseudo-random source in tests (and for LLM sampling in
/// integration tests, together with temperature 0).
const int kTestSeed = 42;

/// Instant every [testClock] starts at.
final DateTime kTestEpoch = DateTime.utc(2026, 1, 15, 9, 30);

/// A [Random] seeded with [kTestSeed] (or [seed]).
Random seededRandom([int seed = kTestSeed]) => Random(seed);

/// A [FakeClock] at [kTestEpoch].
FakeClock testClock() => FakeClock(kTestEpoch);

/// A fresh `id-0001`, `id-0002`, … generator.
SequentialIdGenerator testIds({String prefix = 'id'}) =>
    SequentialIdGenerator(prefix: prefix);
