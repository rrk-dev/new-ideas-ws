import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'id_generator.g.dart';

/// Source of new entity IDs, injected so tests are deterministic
/// (`SequentialIdGenerator` in `test/fakes/`).
abstract interface class IdGenerator {
  /// Returns a new, unique ID.
  String next();
}

/// RFC 4122 version-4 UUIDs. Uses [Random.secure] unless a [Random] is
/// injected (a seeded `Random(n)` gives a reproducible sequence in tests).
class RandomIdGenerator implements IdGenerator {
  RandomIdGenerator([Random? random]) : _random = random ?? Random.secure();

  final Random _random;

  @override
  String next() {
    final b = List<int>.generate(16, (_) => _random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40; // version 4
    b[8] = (b[8] & 0x3f) | 0x80; // RFC 4122 variant
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }
}

@Riverpod(keepAlive: true)
IdGenerator idGenerator(Ref ref) => RandomIdGenerator();
