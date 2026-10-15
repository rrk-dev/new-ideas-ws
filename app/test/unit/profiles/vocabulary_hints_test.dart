import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/profiles/domain/vocabulary_hints.dart';

void main() {
  group('[PRF-05/AC1] vocabulary hints', () {
    test('parse splits, trims and de-duplicates', () {
      expect(VocabularyHints.parse(' gRPC;\nAPI, api ,\u0007x'), [
        'gRPC',
        'API',
        'x',
      ]);
    });

    test('merge keeps profile terms first', () {
      expect(VocabularyHints.merge(['API', 'REST'], ['rest', 'Kafka']), [
        'API',
        'REST',
        'Kafka',
      ]);
    });

    test('prompt is capped at 200 chars and null when empty', () {
      final many = [for (var i = 0; i < 60; i++) 'term-number-$i'];
      expect(VocabularyHints.prompt(many)!.length, lessThanOrEqualTo(200));
      expect(VocabularyHints.prompt(const []), isNull);
      expect(VocabularyHints.prompt(['a', 'b']), 'a, b.');
    });
  });
}
