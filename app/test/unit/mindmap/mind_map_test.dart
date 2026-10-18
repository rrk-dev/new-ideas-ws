import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/features/extraction/domain/long_transcript/map_reduce_extractor.dart';
import 'package:vaultvoice/features/extraction/domain/long_transcript/transcript_chunker.dart';
import 'package:vaultvoice/features/mindmap/domain/mind_map.dart';
import 'package:vaultvoice/features/mindmap/domain/mind_map_generator.dart';
import 'package:vaultvoice/features/mindmap/domain/mind_map_projection.dart';
import 'package:vaultvoice/features/mindmap/domain/mind_map_schema.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';

import '../../fakes/oracle_llm_engine.dart';

class _Llm implements LlmEngine {
  _Llm(this.answer);

  final String answer;

  @override
  Future<Result<String>> generate(
    LlmRequest request, {
    CancelToken? cancel,
    void Function(String token)? onToken,
  }) async => Ok(answer);
}

const _lines = [
  TranscriptLine(startMs: 0, text: 'We agreed to ship the battery redesign.'),
  TranscriptLine(startMs: 65000, text: 'Warranty claims need the receipt.'),
];

Map<String, Object?> _extraction() => {
  'title': 'Planning',
  'summary': 'ignored',
  'decisions': [
    {'text': 'Ship the battery redesign', 't': '00:00:00'},
  ],
  'action_items': [
    {'task': 'Collect receipts', 'owner': 'Sam'},
  ],
};

MindMapInput _input({Map<String, Object?>? extraction}) => MindMapInput(
  lines: _lines,
  tier: DeviceTier.mid,
  modelId: 'm',
  extraction: extraction,
);

Map<String, Object?> _leaf(String id, String label, [String? t]) => {
  'id': id,
  'label': label,
  'children': <Object?>[],
  't': ?t,
};

void main() {
  group('[MAP-01/AC2] validator and normalizer', () {
    test('a valid tree passes; every rule violation is reported', () {
      expect(
        validateMindMap({
          'id': 'n0',
          'label': 'Root',
          'children': [_leaf('n1', 'A')],
        }),
        isEmpty,
      );
      expect(
        validateMindMap({
          'id': 'n0',
          'label': 'Root',
          'children': [_leaf('n0', 'dup')],
        }),
        contains(contains('duplicate')),
      );
      expect(
        validateMindMap({'id': 'n0', 'label': 'Root', 'children': 'x'}),
        isNotEmpty,
      );
      expect(
        validateMindMap({
          'id': 'n0',
          'label': 'x' * 61,
          'children': [_leaf('n1', 'a')],
        }),
        contains(contains('characters')),
      );
      expect(
        validateMindMap({
          'id': 'n0',
          'label': 'r',
          'children': [
            {
              'id': 'n1',
              'label': 'a',
              'children': [
                {
                  'id': 'n2',
                  'label': 'b',
                  'children': [_leaf('n3', 'c')],
                },
              ],
            },
          ],
        }),
        contains(contains('deeper')),
      );
      expect(
        validateMindMap(
          {
            'id': 'n0',
            'label': 'r',
            'children': [_leaf('n1', 'a', '00:09:00')],
          },
          transcriptTimestamps: {'00:00:00'},
        ),
        contains(contains('not a transcript timestamp')),
      );
      expect(validateMindMap('x'), isNotEmpty);
    });

    test('normalizing garbage yields a valid tree or null', () {
      final raw = {
        'label': '  Root  ',
        'children': [
          for (var i = 0; i < 60; i++)
            {
              'label': 'Branch $i ${'w' * 80}',
              't': '09:09:09',
              'children': [
                {
                  'label': 'Leaf $i',
                  'children': [
                    {'label': 'too deep', 'children': <Object?>[]},
                  ],
                },
                {'label': 'Leaf $i', 'children': <Object?>[]},
                {'label': '   ', 'children': <Object?>[]},
              ],
            },
        ],
      };
      final tree = normalizeMindMap(raw, transcriptTimestamps: {'00:00:00'})!;
      expect(validateMindMap(tree.toJson()), isEmpty);
      expect(tree.count, MindMapLimits.maxNodes);
      expect(tree.depth, lessThanOrEqualTo(MindMapLimits.maxDepth));
      expect(tree.all.every((n) => n.t == null), isTrue);
      expect(tree.all.every((n) => n.label.length <= 60), isTrue);

      expect(normalizeMindMap(null), isNull);
      expect(
        normalizeMindMap({'label': 'Root', 'children': <Object?>[]}),
        isNull,
      );
      expect(
        normalizeMindMap({
          'label': 'Root',
          'children': [
            {'label': 'invented topic'},
          ],
        }, grounded: (_) => false),
        isNull,
      );
    });

    test('a real transcript timestamp is kept, ungrounded labels dropped', () {
      final tree = normalizeMindMap(
        {
          'label': 'Root',
          'children': [
            {'label': 'Warranty', 't': '00:01:05'},
            {'label': 'Invented'},
          ],
        },
        transcriptTimestamps: {'00:01:05'},
        grounded: (l) => l == 'Warranty',
      )!;
      expect(tree.children.map((c) => c.label), ['Warranty']);
      expect(tree.children.single.t, '00:01:05');
    });
  });

  group('[MAP-01/AC2] generator', () {
    test('projection maps the extraction without an LLM call', () async {
      final gen = MindMapGenerator(method: MindMapMethod.projection);
      final result = await gen.generate(_input(extraction: _extraction()));
      final tree = result.valueOrNull!.tree!;
      expect(validateMindMap(tree.toJson()), isEmpty);
      expect(tree.label, 'Planning');
      expect(
        tree.all.map((n) => n.label),
        containsAll(['Ship the battery redesign', 'Collect receipts']),
      );
      expect((await gen.generate(_input())).valueOrNull!.tree, isNull);
      expect(projectExtraction(null, fallbackTitle: 'x'), isNull);
    });

    Future<MindMapResult> viaLlm(String answer, MindMapMethod method) async {
      final r = await MindMapGenerator(
        method: method,
        extractor: MapReduceExtractor(
          engine: _Llm(answer),
          tokenizer: WordTokenizer(),
        ),
        grammar: 'root ::= "x"',
      ).generate(_input(extraction: _extraction()));
      return r.valueOrNull!;
    }

    test('LLM topics are grounded in the transcript and counted before '
        'filtering', () async {
      final answer = jsonEncode({
        'title': 'Battery meeting',
        'topics': [
          {
            'label': 'Battery redesign',
            't': '00:00:00',
            'points': ['ship the battery redesign'],
          },
          {'label': 'Zebra migration plan', 't': null, 'points': <String>[]},
        ],
      });
      final r = await viaLlm(answer, MindMapMethod.llm);
      expect(r.schemaValid, isTrue);
      expect(r.rawLabels, greaterThan(r.groundedLabels));
      final tree = r.tree!;
      expect(validateMindMap(tree.toJson()), isEmpty);
      expect(
        tree.all.map((n) => n.label),
        isNot(contains('Zebra migration plan')),
      );

      final h = (await viaLlm(answer, MindMapMethod.hybrid)).tree!;
      expect(validateMindMap(h.toJson()), isEmpty);
      expect(h.all.map((n) => n.label), contains('Collect receipts'));
    });

    test('invalid LLM output is rejected, not stored', () async {
      final r = await viaLlm('not json', MindMapMethod.llm);
      expect(r.tree, isNull);
      expect(r.schemaValid, isFalse);
    });

    test('schema and reduce strategy cover the topic fields', () {
      expect(kMindMapLlmSchema['required'], containsAll(['title', 'topics']));
    });
  });

  group('[MAP-01/AC7] no map text leaves the device', () {
    test('mind-map code has no logging, print or network code', () {
      final files = [
        ...Directory('lib/features/mindmap').listSync(recursive: true),
        File('lib/features/pipeline/data/steps/mind_map_step.dart'),
      ].whereType<File>().where((f) => f.path.endsWith('.dart'));
      expect(files, isNotEmpty);
      final banned = RegExp(
        r'\bprint\(|debugPrint|\bAppLog|\blog\.|dart:io|HttpClient|'
        r'package:http|Uri\.parse|https?://',
      );
      for (final f in files) {
        expect(banned.hasMatch(f.readAsStringSync()), isFalse, reason: f.path);
      }
    });

    test('validator issues carry paths and rules, never label text', () {
      final issues = validateMindMap({
        'id': 'n0',
        'label': '',
        'children': [_leaf('n0', 'secret label 123')],
      });
      expect(issues, isNotEmpty);
      for (final issue in issues) {
        expect(issue, isNot(contains('secret')));
      }
      expect(const StorageFailure('x').toString(), isNot(contains('secret')));
    });
  });
}
