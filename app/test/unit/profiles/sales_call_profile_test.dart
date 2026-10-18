import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/extraction/domain/output_schema_validator.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/profiles/domain/post_processors.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/domain/profile_features.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';

import '../templates/template_fixtures.dart';
import 'builtin_profile_acceptance_test.dart'
    show casesOf, expectLintClean, frontMatter, processed, renderCase;

/// TPL-02: the built-in English Sales conversation profile on its 32-case
/// eval set (`tools/bench/eval/sales_call/`, simulated transcripts). Model
/// quality numbers come from `make eval PROFILE=sales_call` (see the task).
const _evalDir = '../tools/bench/eval/sales_call';
const _taskFile =
    '../tasks/14-product-phase2/TPL-02-sales-conversation-profile.md';
const _assetFiles = [
  'assets/profiles/sales_call.yaml',
  'assets/templates/sales-call-default.mustache',
  'assets/templates/sales-call-logseq.mustache',
  'assets/templates/sales-call-plain.mustache',
];

/// Wording that claims or implies call recording. The profile and template
/// identifiers (`sales_call`, `sales-call-*`) are file names, not user copy.
final List<RegExp> _callClaims = [
  RegExp(r'\bcalls?\b'),
  RegExp(r'\bvoip\b'),
  RegExp(r'\bphone\b'),
  RegExp(r'\bspeaker ?phone\b'),
  RegExp(r'\b(zoom|skype|whatsapp|facetime|webex)\b'),
  RegExp(r'\b(video|conference|telephone|telephony)\b'),
  RegExp(r'\bdial(ing|ed)?\b'),
  RegExp(r'\bwiretap'),
];

String _userCopy(String text) => text.toLowerCase().replaceAll(
  RegExp(r'sales[_-]call(\.yaml)?'),
  'sales-id',
);

List<String> _callClaimsIn(String text) => [
  for (final re in _callClaims)
    for (final m in re.allMatches(_userCopy(text))) m.group(0)!,
];

/// Every string of the profile as the app shows or sends it.
List<String> _profileStrings(Profile p) => [
  p.name,
  p.description,
  p.icon ?? '',
  ...p.classifyKeywords,
  ...p.stt.vocabulary,
  p.instructions,
];

void main() {
  final p = profile('sales_call');
  const validator = OutputSchemaValidator();

  group('[TPL-02/AC2] profile definition', () {
    test('schema keys, diarization on, English, consent required', () {
      expect(p.schema.properties.keys, [
        'title',
        'summary',
        'participants',
        'needs',
        'objections',
        'commitments',
        'next_steps',
        'competitors_mentioned',
        'open_questions',
      ]);
      expect(p.name, 'Sales conversation');
      expect(p.stt.diarization, isTrue);
      expect(p.consentConfirmation, ConsentConfirmation.required);
      expect(p.templateId, 'sales-call-default');
    });

    test('item shapes: objection/response, who/what/t, task/owner/due/t', () {
      final json = p.schema.toJson()['properties']! as Map<String, Object?>;
      List<Object?> required(String field) =>
          ((json[field]! as Map)['items']! as Map)['required']! as List;
      expect(required('objections'), ['objection', 'response']);
      expect(required('commitments'), ['who', 'what', 't']);
      expect(required('next_steps'), ['task', 'owner', 'due', 't']);
      // Same item shape as the meeting action_items (TSK-02 treats them alike).
      expect(
        required('next_steps'),
        (((profile('meeting').schema.toJson()['properties']!
                    as Map)['action_items']!
                as Map)['items']!
            as Map)['required'],
      );
    });

    test('states only what was said: no scoring, rating or prediction', () {
      const banned = [
        'score',
        'sentiment',
        'probab',
        'likelihood',
        'rating',
        'rank',
        'forecast',
      ];
      final names = <String>{};
      void collect(Object? node) {
        if (node is Map) {
          final props = node['properties'];
          if (props is Map) names.addAll(props.keys.map((k) => '$k'));
          node.values.forEach(collect);
        } else if (node is List) {
          node.forEach(collect);
        }
      }

      collect(p.schema.toJson());
      expect(names, containsAll(['objection', 'next_steps', 'commitments']));
      for (final n in names) {
        for (final b in banned) {
          expect(n.toLowerCase(), isNot(contains(b)), reason: n);
        }
      }
      expect(p.instructions, contains('Do not rate, score or rank'));
      expect(p.instructions, contains('predict'));
    });

    test('uses only existing post-processors and ships no examples', () {
      expect(
        p.postProcess,
        containsAll([
          PostProcessor.mapOwnerToSpeaker,
          PostProcessor.resolveRelativeDates,
          PostProcessor.groundToTranscript,
        ]),
      );
      expect(p.examples, isEmpty);
    });

    test('tier is the intended future tier; matrix row is the gate', () {
      final yaml = File('assets/profiles/sales_call.yaml').readAsStringSync();
      expect(yaml, contains('tier: pro'));
      expect(yaml, isNot(contains('PRODUCT-DECISION')));
      expect(featureForProfile('sales_call'), Feature.salesProfile);
    });

    test('profile and templates carry no URLs or logging', () {
      for (final f in _assetFiles) {
        final text = File(f).readAsStringSync();
        expect(text, isNot(contains('http')), reason: f);
        expect(text, isNot(contains('print(')), reason: f);
      }
    });

    test('STT vocabulary stays user-configurable per profile', () {
      expect(SettingKeys.vocabularyFor('sales_call'), 'vocabulary.sales_call');
    });
  });

  group('[TPL-02/AC3] eval set renders lint-clean notes', () {
    test('≥ 30 cases fit the schema, 2-4 speakers, simulated provenance', () {
      final cases = casesOf('sales_call');
      expect(cases.length, greaterThanOrEqualTo(30));
      var noNextSteps = 0;
      var injection = 0;
      var dropped = 0;
      for (final c in cases) {
        expect(
          validator.validate(c.expected, p.schema.toJson()),
          isEmpty,
          reason: c.id,
        );
        final meta = jsonDecode(
          File('$_evalDir/${c.id}/meta.json').readAsStringSync(),
        ) as Map<String, Object?>;
        expect(meta['diarization'], isTrue, reason: c.id);
        final speakers = (meta['speakers']! as List).length;
        expect(speakers, inInclusiveRange(2, 4), reason: c.id);
        expect(
          (meta['asr']! as Map<String, Object?>)['simulated'],
          isTrue,
          reason: '${c.id}: honest provenance',
        );
        final tags = (meta['tags']! as List).cast<String>();
        if (tags.contains('no-next-steps')) {
          noNextSteps++;
          expect(c.expected['next_steps'], isEmpty, reason: c.id);
        }
        if (tags.contains('injection')) injection++;
        if (tags.contains('dropped')) {
          dropped++;
          expect(
            (c.expected['objections']! as List).any(
              (o) => (o as Map)['response'] == null,
            ),
            isTrue,
            reason: '${c.id}: dropped objection has no response',
          );
        }
        final commitments = (c.expected['commitments']! as List)
            .map((e) => (e as Map)['who'])
            .toSet();
        expect(commitments, isNotEmpty, reason: c.id);
      }
      expect(noNextSteps, greaterThanOrEqualTo(1));
      expect(injection, greaterThanOrEqualTo(1));
      expect(dropped, greaterThanOrEqualTo(1));
    });

    test('commitments cover both the seller and the buyer side', () {
      final cases = casesOf('sales_call');
      final bothSides = cases.where((c) {
        final meta = jsonDecode(
          File('$_evalDir/${c.id}/meta.json').readAsStringSync(),
        ) as Map<String, Object?>;
        final seller = ((meta['speakers']! as List).first as Map)['name'];
        final who = (c.expected['commitments']! as List)
            .map((e) => (e as Map)['who'])
            .toSet();
        return who.contains(seller) && who.length > 1;
      });
      expect(bothSides.length, greaterThanOrEqualTo(5));
    });

    test('every case renders lint-clean with front-matter', () {
      for (final c in casesOf('sales_call')) {
        final md = renderCase(p, c);
        expectLintClean(md, c.id);
        final fm = frontMatter(md);
        expect(fm['type'], 'sales_call', reason: c.id);
        expect(fm['participants'], isNotNull, reason: c.id);
      }
    });

    test('next steps in the processed output keep owner and due date', () {
      var withOwner = 0;
      var withDue = 0;
      for (final c in casesOf('sales_call')) {
        final out = processed(p, c);
        for (final a
            in (out['next_steps']! as List).cast<Map<String, Object?>>()) {
          expect('${a['task']}'.trim(), isNotEmpty, reason: c.id);
          if (a['owner'] != null) withOwner++;
          if (a['due_iso'] != null) withDue++;
        }
      }
      expect(withOwner, greaterThan(10));
      expect(withDue, greaterThan(3));
    });
  });

  group('[TPL-02/AC4] eval targets are fixed before the baseline', () {
    test('scoring.json mirrors the task file targets', () {
      final cfg = jsonDecode(
        File('$_evalDir/scoring.json').readAsStringSync(),
      ) as Map<String, Object?>;
      final t = cfg['targets']! as Map<String, Object?>;
      expect(t['schema_valid'], 0.9);
      expect(t['lists.next_steps.recall'], 0.6);
      expect(t['lists.next_steps.precision'], 0.6);
      expect(t['lists.next_steps.owner_accuracy'], 0.5);
      expect(t['lists.objections.recall'], 0.5);
      expect(t['lists.commitments.recall'], 0.5);
      expect(t['lists.needs.recall'], 0.5);
      final task = File(_taskFile).readAsStringSync();
      expect(task, contains('written before the first baseline run'));
      for (final e in t.entries) {
        expect(task, contains('`${e.key}`'), reason: e.key);
      }
    });

    test('a baseline for the default catalog model is committed', () {
      final baselines = Directory('../tools/bench/eval/baselines')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('/sales_call.'));
      expect(baselines, isNotEmpty);
      final json = jsonDecode(
        baselines.first.readAsStringSync(),
      ) as Map<String, Object?>;
      final agg = json['aggregate']! as Map<String, Object?>;
      expect(agg['cases'], greaterThanOrEqualTo(30));
      expect(agg['schema_valid'], isA<num>());
      expect(agg['hallucination_rate'], isA<num>());
    });
  });

  group(
    '[TPL-02/AC5] no profile, template or string claims call recording',
    () {
      test('profile strings and template files make no call-capture claim', () {
        for (final s in _profileStrings(p)) {
          expect(_callClaimsIn(s), isEmpty, reason: s);
        }
        for (final f in _assetFiles) {
          expect(_callClaimsIn(File(f).readAsStringSync()), isEmpty, reason: f);
        }
      });

      test('rendered notes of the three templates make no call claim', () {
        for (final id in ['default', 'logseq', 'plain']) {
          for (final c in casesOf('sales_call').take(8)) {
            final data = processed(p, c);
            final md = renderBuiltin(
              'sales-call-$id',
              contextFor('sales_call', data),
            );
            expect(_callClaimsIn(md), isEmpty, reason: '$id ${c.id}');
          }
        }
      });

      test('localised strings about the sales profile make no call claim', () {
        final arb = jsonDecode(
          File('lib/core/l10n/arb/app_en.arb').readAsStringSync(),
        ) as Map<String, Object?>;
        for (final e in arb.entries) {
          final text = '${e.key} ${e.value}'.toLowerCase();
          if (text.contains('sales')) {
            expect(_callClaimsIn(text), isEmpty, reason: e.key);
          }
        }
      });

      test('built-in profile and template names do not advertise calls', () {
        for (final b in [p]) {
          expect(b.name.toLowerCase(), isNot(contains('call')));
          expect(b.description.toLowerCase(), contains('in-person'));
          expect(b.description.toLowerCase(), contains('right to use'));
        }
      });

      test('the scanner flags call-recording wording (positive control)', () {
        for (final bad in [
          'Record your sales calls',
          'Capture phone conversations',
          'Works with Zoom and VoIP',
          'Put the call on speakerphone and record it',
        ]) {
          expect(_callClaimsIn(bad), isNotEmpty, reason: bad);
        }
        expect(_callClaimsIn('Sales conversation notes'), isEmpty);
      });
    },
  );
}
