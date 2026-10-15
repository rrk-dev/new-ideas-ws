import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/profiles/domain/post_processing.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/domain/prompt_inputs.dart';

import 'profile_fixtures.dart';

// Monday 2 March 2026, 18:00 local (the eval set's recording date).
final _ref = DateTime(2026, 3, 2, 18);

String? _iso(DateTime? d) => d?.toIso8601String().substring(0, 10);

void main() {
  final builtins = <String, Profile>{
    for (final id in ['meeting', 'warranty', 'engineering'])
      id: builtinProfile(id),
  };

  group('[PRF-04/AC2] computeWarrantyExpiry', () {
    test('years, months, weeks, days', () {
      expect(
        _iso(computeWarrantyExpiry(DateTime(2026, 3, 2), 2, 'years')),
        '2028-03-02',
      );
      expect(
        _iso(computeWarrantyExpiry(DateTime(2026, 3, 2), 18, 'months')),
        '2027-09-02',
      );
      expect(
        _iso(computeWarrantyExpiry(DateTime(2026, 3, 2), 6, 'weeks')),
        '2026-04-13',
      );
      expect(
        _iso(computeWarrantyExpiry(DateTime(2026, 12, 20), 30, 'days')),
        '2027-01-19',
      );
    });

    test('leap day purchase: +1 year clamps to Feb 28, +4 years keeps 29', () {
      expect(
        _iso(computeWarrantyExpiry(DateTime(2024, 2, 29), 1, 'years')),
        '2025-02-28',
      );
      expect(
        _iso(computeWarrantyExpiry(DateTime(2024, 2, 29), 4, 'years')),
        '2028-02-29',
      );
      expect(
        _iso(computeWarrantyExpiry(DateTime(2024, 2, 29), 12, 'months')),
        '2025-02-28',
      );
    });

    test('month-end purchase clamps to the target month end', () {
      expect(
        _iso(computeWarrantyExpiry(DateTime(2026, 1, 31), 1, 'months')),
        '2026-02-28',
      );
      expect(
        _iso(computeWarrantyExpiry(DateTime(2027, 1, 31), 1, 'months')),
        '2027-02-28',
      );
      expect(
        _iso(computeWarrantyExpiry(DateTime(2028, 1, 31), 1, 'months')),
        '2028-02-29',
      );
      expect(
        _iso(computeWarrantyExpiry(DateTime(2026, 8, 31), 3, 'months')),
        '2026-11-30',
      );
      expect(
        _iso(computeWarrantyExpiry(DateTime(2026, 10, 31), 4, 'months')),
        '2027-02-28',
      );
    });

    test('days across a leap February and a DST change', () {
      expect(
        _iso(computeWarrantyExpiry(DateTime(2028, 2, 20), 10, 'days')),
        '2028-03-01',
      );
      expect(
        _iso(computeWarrantyExpiry(DateTime(2026, 3, 25), 7, 'days')),
        '2026-04-01',
      );
    });

    test('unknown unit or negative value → null', () {
      expect(computeWarrantyExpiry(DateTime(2026), 2, 'decades'), isNull);
      expect(computeWarrantyExpiry(DateTime(2026), -1, 'years'), isNull);
    });

    test('warranty profile: expiry from a spoken relative purchase date', () {
      final out = applyPostProcessors(builtins['warranty']!, {
        'purchase_date': 'yesterday',
        'warranty_period': {'value': 2, 'unit': 'years'},
        'serial_number': 'S as in Sam, M4, 4, 1, 0, 2, 7',
      }, PostProcessContext(recordedAt: _ref));
      expect(out['purchase_date'], 'yesterday', reason: 'spoken text kept');
      expect(out['purchase_date_iso'], '2026-03-01');
      expect(out['warranty_expiry'], '2028-03-01');
      expect(out['serial_number'], 'SM441027');
    });

    test('no purchase date or no period → expiry null', () {
      final p = builtins['warranty']!;
      final ctx = PostProcessContext(recordedAt: _ref);
      expect(
        applyPostProcessors(p, {
          'purchase_date': null,
          'warranty_period': {'value': 2, 'unit': 'years'},
        }, ctx)['warranty_expiry'],
        isNull,
      );
      expect(
        applyPostProcessors(p, {
          'purchase_date': 'March 1st',
          'warranty_period': null,
        }, ctx)['warranty_expiry'],
        isNull,
      );
    });
  });

  group('[PRF-04/AC1] normalizeSerial (spelling-aware)', () {
    const cases = {
      'S as in Sam, M4, 4, 1, 0, 2, 7': 'SM441027',
      'as Esses in Sam, M4, 4, 1, 0, 2, 7': 'SM441027',
      'P as in Peter, W as in William, 8, 0, 0, K as in Kilo, 3': 'PW800K3',
      'X as in x-ray, 7, 4, B as in boy, 2, 9': 'X74B29',
      'T, V, 2, 7, 8, 8, 1, 0': 'TV278810',
      'tv-2788 10': 'TV278810',
      'SM441027': 'SM441027',
      'serial number is AB 12 34': 'AB1234',
      'A B as in boy 9': 'AB9',
      'AB as in boy 9': 'AB9',
      'Kilo Lima four five': 'KL45',
      'double 7 3 triple oh': '773000',
      'Q for Queen 12': 'Q12',
      'nine eight seven': '987',
    };
    for (final MapEntry(:key, :value) in cases.entries) {
      test('"$key" → $value', () => expect(normalizeSerial(key), value));
    }
    test('empty → null', () {
      expect(normalizeSerial('  '), isNull);
      expect(normalizeSerial(', .'), isNull);
    });
  });

  group('[PRF-04/AC1] resolveSpokenDate', () {
    // _ref is Monday 2026-03-02.
    const past = {
      'yesterday': '2026-03-01',
      'today': '2026-03-02',
      'the day before yesterday': '2026-02-28',
      'last Tuesday': '2026-02-24',
      'Tuesday': '2026-02-24',
      'last Monday': '2026-02-23',
      'on Saturday': '2026-02-28',
      'February 10th': '2026-02-10',
      'February tenth': '2026-02-10',
      'the 10th of February': '2026-02-10',
      'May 3rd': '2025-05-03',
      'May third': '2025-05-03',
      'October first': '2025-10-01',
      'March 2': '2026-03-02',
      'December 24, 2025': '2025-12-24',
      '2026-01-15': '2026-01-15',
      'three days ago': '2026-02-27',
      'two weeks ago': '2026-02-16',
      'a month ago': '2026-02-02',
      'Monday last week': '2026-02-23',
    };
    for (final MapEntry(:key, :value) in past.entries) {
      test('purchase "$key" → $value', () {
        expect(_iso(resolveSpokenDate(key, _ref)), value);
      });
    }
    const future = {
      'Friday': '2026-03-06',
      'next Friday': '2026-03-06',
      'this Thursday': '2026-03-05',
      'Monday': '2026-03-09',
      'next Monday': '2026-03-09',
      'Friday next week': '2026-03-13',
      'tomorrow': '2026-03-03',
      'end of the month': '2026-03-31',
      'end of next month': '2026-04-30',
      'end of the week': '2026-03-06',
      'in two weeks': '2026-03-16',
      'March 20th': '2026-03-20',
      'February 10th': '2027-02-10',
      'by Wednesday': '2026-03-04',
    };
    for (final MapEntry(:key, :value) in future.entries) {
      test('due "$key" → $value', () {
        expect(
          _iso(resolveSpokenDate(key, _ref, bias: DateBias.future)),
          value,
        );
      });
    }
    test('not a single day → null', () {
      for (final s in [
        'next week',
        'soon',
        'Q3',
        'last month',
        'February 30th',
        '',
      ]) {
        expect(resolveSpokenDate(s, _ref), isNull, reason: s);
      }
    });
    test('February 29 only in leap years', () {
      expect(
        _iso(resolveSpokenDate('February 29th', DateTime(2028, 3, 10))),
        '2028-02-29',
      );
      expect(resolveSpokenDate('February 29th, 2026', _ref), isNull);
    });
  });

  group('[PRF-03/AC1] map_owner_to_speaker + timestamps', () {
    final ctx = PostProcessContext.fromTranscriptLines(
      '[00:00:05] Priya: Let us ship v2.\n'
      '[00:00:12] Sam Lee: I will update the SDK by Friday.\n'
      '[00:00:20] Kofi: Still unclear who owns the guide.\n',
      recordedAt: _ref,
      speakers: const [PromptSpeaker(label: 'S1', name: 'Priya')],
    );

    test('labels, self references, spelling variants, first names', () {
      expect(mapOwnerToSpeaker('S1', ctx), 'Priya');
      expect(mapOwnerToSpeaker('I', ctx, at: '00:00:12'), 'Sam Lee');
      expect(mapOwnerToSpeaker('me', ctx, at: '00:00:05'), 'Priya');
      expect(mapOwnerToSpeaker('Ko-fi', ctx), 'Kofi');
      expect(mapOwnerToSpeaker('priya', ctx), 'Priya');
      expect(mapOwnerToSpeaker('Sam', ctx), 'Sam Lee');
      expect(mapOwnerToSpeaker('finance', ctx), 'finance');
      expect(mapOwnerToSpeaker(' ', ctx), isNull);
    });

    test('meeting profile: owners, ungrounded t, sort, due dates', () {
      final out = applyPostProcessors(builtins['meeting']!, {
        'title': 't',
        'summary': 's',
        'attendees': ['Priya', 'Sam Lee'],
        'decisions': <String>[],
        'action_items': [
          {'task': 'b', 'owner': 'Ko-fi', 'due': null, 't': '00:00:20'},
          {'task': 'a', 'owner': 'I', 'due': 'Friday', 't': '00:00:12'},
          {'task': 'c', 'owner': null, 'due': 'tomorrow', 't': '00:09:99'},
        ],
        'open_questions': <String>[],
        'topics': <String>[],
      }, ctx);
      final items = (out['action_items']! as List).cast<Map<String, Object?>>();
      expect([for (final i in items) i['task']], ['a', 'b', 'c']);
      expect(items[0]['owner'], 'Sam Lee');
      expect(items[0]['due_iso'], '2026-03-06');
      expect(items[1]['owner'], 'Kofi');
      expect(items[2]['t'], isNull, reason: 'not a transcript timestamp');
      expect(items[2]['owner'], isNull);
      expect(items[2]['due_iso'], '2026-03-03');
    });

    test('input map is not mutated', () {
      final input = <String, Object?>{
        'serial_number': 'x as in xray 1',
        'purchase_date': null,
        'warranty_period': null,
      };
      applyPostProcessors(builtins['warranty']!, input, ctx);
      expect(input['serial_number'], 'x as in xray 1');
      expect(input.containsKey('warranty_expiry'), isFalse);
    });
  });

  group('[PRF-03/AC1] dedupe_lists', () {
    test('drops repeated strings and objects (t ignored), keeps order', () {
      final list = <Object?>[
        'Release notes signed off by Priya.',
        'release notes signed off by priya',
        'Use API v2',
        {'task': 'Ship', 'owner': 'Sam', 't': '00:00:01'},
        {'task': 'ship', 'owner': 'Sam', 't': '00:00:09'},
        {'task': 'Ship', 'owner': 'Lena', 't': '00:00:01'},
      ];
      dedupeList(list);
      expect(list, hasLength(4));
      expect(list[0], 'Release notes signed off by Priya.');
      expect(list[1], 'Use API v2');
      expect((list[3]! as Map)['owner'], 'Lena');
    });
  });
}
