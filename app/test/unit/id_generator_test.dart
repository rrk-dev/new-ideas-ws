import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/platform/id_generator.dart';

import '../fakes/fake_id_generator.dart';
import '../helpers/deterministic.dart';
import '../helpers/test_container.dart';

final _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

void main() {
  test('RandomIdGenerator emits RFC 4122 v4 UUIDs', () {
    final ids = RandomIdGenerator();
    final seen = {for (var i = 0; i < 200; i++) ids.next()};
    expect(seen, hasLength(200));
    expect(seen.every(_uuidV4.hasMatch), isTrue, reason: seen.first);
  });

  test('a seeded Random makes the sequence reproducible', () {
    final a = RandomIdGenerator(seededRandom());
    final b = RandomIdGenerator(seededRandom());
    final c = RandomIdGenerator(seededRandom(kTestSeed + 1));
    final first = [a.next(), a.next()];
    expect([b.next(), b.next()], first);
    expect(c.next(), isNot(first.first));
  });

  test('provider defaults to RandomIdGenerator; fakes override it', () {
    expect(
      createContainer().read(idGeneratorProvider),
      isA<RandomIdGenerator>(),
    );

    final ids = SequentialIdGenerator(prefix: 'rec');
    final c = createContainer(overrides: fakeEngineOverrides(ids: ids));
    final gen = c.read(idGeneratorProvider);
    expect([gen.next(), gen.next()], ['rec-0001', 'rec-0002']);
    expect(ids.issued, ['rec-0001', 'rec-0002']);
  });
}
