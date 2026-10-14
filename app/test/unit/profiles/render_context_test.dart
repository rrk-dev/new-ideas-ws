import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/domain/render_context.dart';

import 'profile_fixtures.dart';

void main() {
  late Profile meeting;
  setUp(() => meeting = Profile.fromJson(builtinMap('meeting')));

  Map<String, Object?> context(Map<String, Object?> data) => buildRenderContext(
    profile: meeting,
    data: data,
    meta: const {'recording_id': 'r1', 'date': '2026-10-13'},
    transcript: const {},
  );

  test('every schema and post-processor field is present, with has_ '
      'helpers, when the model returned almost nothing', () {
    final ctx = context({'title': 'Sync'});
    final data = ctx['data']! as Map<String, Object?>;
    expect(data['title'], 'Sync');
    expect(data['has_title'], isTrue);
    expect(data['summary'], isNull);
    expect(data['has_summary'], isFalse);
    for (final list in ['attendees', 'decisions', 'action_items', 'topics']) {
      expect(data[list], isEmpty);
      expect(data['has_$list'], isFalse);
      expect(ctx['has_$list'], isFalse, reason: 'root alias');
    }
    final meta = ctx['meta']! as Map<String, Object?>;
    expect(meta['consent_at'], isNull);
    expect(meta['has_consent_at'], isFalse);
    expect(meta['tags'], isEmpty);
    expect((meta['model_ids']! as Map)['stt'], isNull);
    expect((ctx['transcript']! as Map)['segments'], isEmpty);
  });

  test('items get per-field helpers; empty strings become null; '
      'post-processor fields are added', () {
    final ctx = context({
      'attendees': ['Priya', '', '  ', 'Sam'],
      'action_items': [
        {'task': 'Ship it', 'owner': '', 'due': 'Friday', 't': '00:00:12'},
        {'task': 'Docs', 'owner': 'Sam', 'due_iso': '2026-10-16'},
      ],
    });
    final data = ctx['data']! as Map<String, Object?>;
    expect(data['attendees'], ['Priya', 'Sam']);
    final items = (data['action_items']! as List).cast<Map<String, Object?>>();
    expect(items[0], {
      'task': 'Ship it',
      'owner': null,
      'due': 'Friday',
      't': '00:00:12',
      'due_iso': null,
      'has_task': true,
      'has_owner': false,
      'has_due': true,
      'has_t': true,
      'has_due_iso': false,
    });
    expect(items[1]['has_due_iso'], isTrue);
    expect(items[1]['has_due'], isFalse);
    expect(ctx['has_action_items'], isTrue);
  });

  test('values of the wrong type are dropped, never passed to templates', () {
    final ctx = context({
      'title': 42,
      'attendees': 'Priya',
      'action_items': [
        'not an object',
        {'task': 7},
      ],
    });
    final data = ctx['data']! as Map<String, Object?>;
    expect(data['title'], isNull);
    expect(data['attendees'], isEmpty);
    final items = (data['action_items']! as List).cast<Map<String, Object?>>();
    expect(items, hasLength(2));
    expect(
      items.every((i) => i['task'] == null && i['has_task'] == false),
      isTrue,
    );
  });

  test('warranty: nullable object, number and computed expiry', () {
    final warranty = Profile.fromJson(builtinMap('warranty'));
    final ctx = buildRenderContext(
      profile: warranty,
      data: {
        'warranty_period': {'value': 2, 'unit': 'years'},
        'warranty_expiry': '2028-10-11',
      },
      meta: const {},
      transcript: const {},
    );
    final data = ctx['data']! as Map<String, Object?>;
    expect(data['warranty_period'], {
      'value': 2,
      'unit': 'years',
      'has_value': true,
      'has_unit': true,
    });
    expect(data['has_warranty_period'], isTrue);
    expect(data['warranty_expiry'], '2028-10-11');
    expect(data['has_warranty_expiry'], isTrue);
    expect(data['purchase_date_iso'], isNull);
    final empty =
        buildRenderContext(
              profile: warranty,
              data: const {},
              meta: const {},
              transcript: const {},
            )['data']!
            as Map<String, Object?>;
    expect(empty['warranty_period'], isNull);
    expect(empty['has_warranty_period'], isFalse);
  });

  test('the shape used by the template check matches the normalizer '
      'output keys', () {
    final shape = dataShapeFor(meeting);
    final data =
        normalizeToShape(shape, const <String, Object?>{})!
            as Map<String, Object?>;
    for (final key in data.keys) {
      expect(shape.lookup(key), isNotNull, reason: key);
    }
    expect(data.keys, containsAll(shape.fields.keys));
  });
}
