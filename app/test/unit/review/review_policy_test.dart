import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/profiles/domain/profile_schema.dart';
import 'package:vaultvoice/features/review/domain/review_policy.dart';
import 'package:vaultvoice/features/review/presentation/schema_form.dart';

import '../templates/template_fixtures.dart';

void main() {
  test('[APP-05] review setting overrides the profile default', () {
    expect(reviewRequired(setting: null, profileDefault: false), isFalse);
    expect(reviewRequired(setting: null, profileDefault: true), isTrue);
    expect(reviewRequired(setting: true, profileDefault: false), isTrue);
    expect(reviewRequired(setting: false, profileDefault: true), isFalse);
    expect(reviewRequired(setting: 'x', profileDefault: true), isTrue);
  });

  test('[APP-05] content hash ignores key order, sees value changes', () {
    final a = extractionHash({
      'b': [1, 2],
      'a': {'y': 1, 'x': 2},
    });
    final b = extractionHash({
      'a': {'x': 2, 'y': 1},
      'b': [1, 2],
    });
    expect(a, b);
    expect(
      extractionHash({
        'a': {'x': 2, 'y': 1},
        'b': [2, 1],
      }),
      isNot(a),
    );
  });

  test('[APP-05/AC1] evidence timestamps → recording position', () {
    expect(timestampToMs('00:00:12'), 12000);
    expect(timestampToMs('01:02:03'), 3723000);
    expect(timestampToMs('02:05'), 125000);
    expect(timestampToMs('7'), 7000);
    expect(timestampToMs(''), isNull);
    expect(timestampToMs('ab:cd'), isNull);
    expect(timestampToMs('1:2:3:4'), isNull);
    expect(timestampToMs(null), isNull);
  });

  test('[APP-05] form helpers and schema validation of edits', () {
    final schema = builtinProfiles['meeting']!.schema;
    final empty = emptyValueFor(schema)! as Map<String, Object?>;
    expect(empty['attendees'], isEmpty);
    expect(empty['title'], '');
    final item =
        emptyValueFor(
              (schema.properties['action_items']! as ArraySchema).items,
            )!
            as Map<String, Object?>;
    expect(item, {'task': '', 'owner': null, 'due': null, 't': null});

    final edited = setIn(empty, ['action_items'], [item]);
    final deeper = setIn(edited, ['action_items', 0, 'owner'], 'Sam');
    expect(
      ((deeper! as Map)['action_items'] as List).single,
      containsPair('owner', 'Sam'),
    );
    expect((edited! as Map)['action_items'], [item], reason: 'copy on write');

    expect(validateEdited(schema, empty), isEmpty);
    expect(validateEdited(schema, {...empty, 'title': 'x' * 200}), isNotEmpty);
    expect(
      validateEdited(schema, {...empty, 'attendees': 'not a list'}),
      isNotEmpty,
    );
  });
}
