import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/features/extraction/domain/output_schema_validator.dart';
import 'package:vaultvoice/features/extraction/domain/structured_extractor.dart';

import '../../fakes/scripted_llm_engine.dart';

const _schema = <String, Object?>{
  'type': 'object',
  'required': ['title', 'action_items'],
  'additionalProperties': false,
  'properties': {
    'title': {'type': 'string', 'maxLength': 20},
    'kind': {
      'enum': ['meeting', 'call'],
    },
    'score': {'type': 'integer', 'minimum': 0, 'maximum': 5},
    'action_items': {
      'type': 'array',
      'maxItems': 2,
      'items': {
        'type': 'object',
        'required': ['text'],
        'properties': {
          'text': {'type': 'string', 'minLength': 1},
          'owner': {
            'type': ['string', 'null'],
          },
          't': {'type': 'string', 'pattern': r'^\d{2}:\d{2}:\d{2}$'},
        },
      },
    },
  },
};

ExtractionRequest _req({Set<String> ts = const {'00:00:05'}}) =>
    ExtractionRequest(
      systemPrompt: 'sys',
      userPrompt: '<transcript>[00:00:05] A: ship it</transcript>',
      schema: _schema,
      grammar: 'root ::= ...',
      transcriptTimestamps: ts,
    );

void main() {
  group('OutputSchemaValidator', () {
    const v = OutputSchemaValidator();

    test('accepts a valid document', () {
      expect(
        v.validate({
          'title': 'Sync',
          'kind': 'call',
          'score': 3,
          'action_items': [
            {'text': 'Ship', 'owner': null, 't': '00:00:05'},
          ],
        }, _schema),
        isEmpty,
      );
    });

    test('reports paths and rules, never values', () {
      final issues = v.validate({
        'title': 'A title that is far too long',
        'kind': 'party',
        'score': 9,
        'extra': 1,
        'action_items': [
          {'owner': 3, 't': 'noon'},
          {'text': 'b'},
          {'text': 'c'},
        ],
      }, _schema);
      expect(
        issues,
        containsAll([
          r'$.title: longer than maxLength 20',
          r'$.kind: not one of the allowed values',
          r'$.score: above maximum 5',
          r'$.extra: not allowed',
          r'$.action_items: more than maxItems 2',
          r'$.action_items[0].text: required',
          r'$.action_items[0].owner: expected string|null',
          r'$.action_items[0].t: does not match pattern',
        ]),
      );
      expect(issues.join(), isNot(contains('party')));
      expect(issues.join(), isNot(contains('noon')));
      expect(v.validate({'title': 'x'}, _schema), [
        r'$.action_items: required',
      ]);
      expect(v.validate([1], _schema), [r'$: expected object']);
    });
  });

  group('StructuredExtractor (LLM-05)', () {
    test('valid first answer: grammar passed, evidence verified', () async {
      const answer =
          '{"title":"Sync","action_items":[{"text":"Ship","t":"00:00:05"},'
          '{"text":"Call","t":"00:09:59"}]}';
      final engine = ScriptedLlmEngine([answer]);
      final r = await StructuredExtractor(engine).extract(_req());
      final o = r.valueOrNull!;
      expect(o.valid, isTrue);
      expect(o.repairUsed, isFalse);
      expect(engine.requests.single.grammar, 'root ::= ...');
      expect(engine.requests.single.sampling.preset, LlmPreset.extraction);
      // 00:09:59 is not in the transcript -> dropped, item kept.
      final items = o.data!['action_items']! as List;
      expect((items[0] as Map)['t'], '00:00:05');
      expect((items[1] as Map).containsKey('t'), isFalse);
      expect(o.droppedEvidence, 1);
    });

    test('[LLM-05/AC1] unverifiable required evidence drops the item; '
        'nullable evidence becomes null; result stays schema-valid', () async {
      const schema = <String, Object?>{
        'type': 'object',
        'required': ['a', 'b'],
        'properties': {
          'a': {
            'type': 'array',
            'items': {
              'type': 'object',
              'required': ['text', 't'],
              'properties': {
                'text': {'type': 'string'},
                't': {'type': 'string'},
              },
            },
          },
          'b': {
            'type': 'array',
            'items': {
              'type': 'object',
              'required': ['text', 't'],
              'properties': {
                'text': {'type': 'string'},
                't': {
                  'type': ['string', 'null'],
                },
              },
            },
          },
        },
      };
      const answer =
          '{"a":[{"text":"real","t":"00:00:05"},'
          '{"text":"made up","t":"07:07:07"}], '
          '"b":[{"text":"kept","t":"99:99:99"}]}';
      final engine = ScriptedLlmEngine([answer]);
      final o = (await StructuredExtractor(engine).extract(
        const ExtractionRequest(
          systemPrompt: 's',
          userPrompt: 'u',
          schema: schema,
          grammar: 'g',
          transcriptTimestamps: {'00:00:05'},
        ),
      )).valueOrNull!;
      expect(o.data!['a'], [
        {'text': 'real', 't': '00:00:05'},
      ]);
      expect(o.data!['b'], [
        {'text': 'kept', 't': null},
      ]);
      expect(o.droppedEvidence, 2);
      expect(const OutputSchemaValidator().validate(o.data, schema), isEmpty);
    });

    group('[LLM-05/AC1] cleanup is revalidated (rework-1)', () {
      ExtractionRequest req(Map<String, Object?> schema) => ExtractionRequest(
        systemPrompt: 's',
        userPrompt: 'u',
        schema: schema,
        grammar: 'g',
        transcriptTimestamps: const {'00:00:05'},
      );
      const rootT = <String, Object?>{
        'type': 'object',
        'required': ['t'],
        'properties': {
          't': {'type': 'string', 'maxLength': 8},
        },
      };

      test('[LLM-05/AC1] required root evidence that cannot be verified is '
          'never reported as valid; repair then summary fallback', () async {
        final engine = ScriptedLlmEngine([
          '{"t":"00:00:09"}',
          '{"t":"00:00:07"}',
          'Title\nSummary.',
        ]);
        final o = (await StructuredExtractor(engine).extract(req(rootT)))
            .valueOrNull!;
        expect(o.valid, isFalse);
        expect(o.data, isNull);
        expect(o.repairUsed, isTrue);
        expect(o.fallbackSummary, startsWith('Title'));
        expect(engine.requests, hasLength(3));
        // The repair prompt names the rule, never the invented value.
        expect(
          engine.requests[1].prompt,
          contains(r'$.t: evidence timestamp not found in transcript'),
        );
        expect(o.issues.join(), isNot(contains('00:00:07')));
      });

      test(
        '[LLM-05/AC1] repair with verifiable evidence is accepted',
        () async {
          final engine = ScriptedLlmEngine([
            '{"t":"00:00:09"}',
            '{"t":"00:00:05"}',
          ]);
          final o = (await StructuredExtractor(engine).extract(req(rootT)))
              .valueOrNull!;
          expect(o.valid, isTrue);
          expect(o.repairUsed, isTrue);
          expect(o.data, {'t': '00:00:05'});
        },
      );

      test('[LLM-05/AC1] dropping items below minItems is not valid', () async {
        const schema = <String, Object?>{
          'type': 'object',
          'required': ['items'],
          'properties': {
            'items': {
              'type': 'array',
              'minItems': 1,
              'items': {
                'type': 'object',
                'required': ['text', 't'],
                'properties': {
                  'text': {'type': 'string'},
                  't': {'type': 'string'},
                },
              },
            },
          },
        };
        final engine = ScriptedLlmEngine([
          '{"items":[{"text":"a","t":"00:00:09"}]}',
          '{"items":[{"text":"a","t":"00:00:08"}]}',
        ]);
        final o = (await StructuredExtractor(engine).extract(
          const ExtractionRequest(
            systemPrompt: 's',
            userPrompt: 'u',
            schema: schema,
            grammar: 'g',
            transcriptTimestamps: {'00:00:05'},
            summaryFallback: false,
          ),
        )).valueOrNull!;
        expect(o.valid, isFalse);
        expect(o.data, isNull);
        expect(o.issues, contains(r'$.items: fewer than minItems 1'));
      });

      test('[LLM-05/AC1] nested objects: required one invalidates, optional '
          'one is removed; accepted data always revalidates', () async {
        const inner = <String, Object?>{
          'type': 'object',
          'required': ['t'],
          'properties': {
            't': {'type': 'string'},
          },
        };
        const requiredNested = <String, Object?>{
          'type': 'object',
          'required': ['obj'],
          'properties': {'obj': inner},
        };
        const optionalNested = <String, Object?>{
          'type': 'object',
          'properties': {
            'obj': inner,
            'n': {'type': 'integer'},
          },
        };
        final bad = ScriptedLlmEngine([
          '{"obj":{"t":"00:00:09"}}',
          '{"obj":{"t":"00:00:09"}}',
          'T\nS.',
        ]);
        final o1 = (await StructuredExtractor(bad).extract(req(requiredNested)))
            .valueOrNull!;
        expect(o1.valid, isFalse);
        expect(o1.data, isNull);

        final ok = ScriptedLlmEngine(['{"obj":{"t":"00:00:09"},"n":1}']);
        final o2 = (await StructuredExtractor(ok).extract(req(optionalNested)))
            .valueOrNull!;
        expect(o2.valid, isTrue);
        expect(o2.data, {'n': 1});
        expect(
          const OutputSchemaValidator().validate(o2.data, optionalNested),
          isEmpty,
        );
      });
    });

    test('invalid answer -> one repair with the issues, then valid', () async {
      final engine = ScriptedLlmEngine([
        '{"title":"Sync"}',
        '{"title":"Sync","action_items":[]}',
      ]);
      final o = (await StructuredExtractor(engine).extract(_req()))
          .valueOrNull!;
      expect(o.valid, isTrue);
      expect(o.repairUsed, isTrue);
      final repair = engine.requests[1];
      expect(repair.prompt, contains(r'$.action_items: required'));
      expect(repair.prompt, contains('{"title":"Sync"}'));
      expect(repair.sampling.preset, LlmPreset.deterministic);
      expect(repair.grammar, 'root ::= ...');
    });

    test('invalid twice -> summary-only fallback, valid=false', () async {
      final engine = ScriptedLlmEngine([
        'not json',
        '{"title": 1}',
        'Release sync\nThe team agreed to ship.',
      ]);
      final o = (await StructuredExtractor(engine).extract(_req()))
          .valueOrNull!;
      expect(o.valid, isFalse);
      expect(o.data, isNull);
      expect(o.fallbackSummary, startsWith('Release sync'));
      expect(o.issues, isNotEmpty);
      expect(engine.requests.last.grammar, isNull);
      expect(engine.requests.last.sampling.preset, LlmPreset.summary);
    });

    test('cancel / OOM propagate as failures', () async {
      final cancelled = ScriptedLlmEngine([const CancelledFailure()]);
      expect(
        (await StructuredExtractor(cancelled).extract(_req())).failureOrNull,
        isA<CancelledFailure>(),
      );
      final oom = ScriptedLlmEngine(['nope', const OutOfMemoryFailure()]);
      expect(
        (await StructuredExtractor(oom).extract(_req())).failureOrNull,
        isA<OutOfMemoryFailure>(),
      );
    });

    test('transcriptTimestamps parses [hh:mm:ss] markers', () {
      expect(
        transcriptTimestamps('[00:00:05] A: hi\n[01:02:03] B: yo\n[9:9:9] x'),
        {'00:00:05', '01:02:03'},
      );
    });
  });
}
