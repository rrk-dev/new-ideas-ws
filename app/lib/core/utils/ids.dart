import 'dart:math';

final Random _random = Random.secure();

/// A random RFC 4122 version-4 UUID string (lower-case hex).
String newUuidV4([Random? random]) {
  final r = random ?? _random;
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
  final hex = [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')];
  return '${hex.sublist(0, 4).join()}-${hex.sublist(4, 6).join()}-'
      '${hex.sublist(6, 8).join()}-${hex.sublist(8, 10).join()}-'
      '${hex.sublist(10).join()}';
}

/// Stable 32-bit FNV-1a hash as 8 hex chars (deterministic across runs,
/// unlike `String.hashCode`). Not cryptographic.
String fnv1a32(String input) {
  var hash = 0x811c9dc5;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
