import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/features/profiles/domain/profile_classifier.dart';

import 'profile_fixtures.dart';

const _evalDir = '../tools/bench/eval/classify';
const _taskFile =
    '../tasks/14-product-phase2/TPL-04-template-picker-classification.md';
const _ids = [
  'meeting',
  'warranty',
  'engineering',
  'lecture',
  'sales_call',
  'interview',
];

class _NoLlm implements LlmEngine {
  @override
  Future<Result<String>> generate(
    LlmRequest request, {
    CancelToken? cancel,
    void Function(String token)? onToken,
  }) => throw StateError('the keyword stage must not reach the model');
}

Map<String, Object?> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

void main() {
  final spec = _json('$_evalDir/cases.json');
  final cases = (spec['cases']! as List).cast<Map<String, Object?>>();
  final profiles = [for (final id in _ids) builtinProfile(id)];

  group('[TPL-04/AC1] the mixed classification eval set', () {
    test('covers the six built-in profiles with >= 20 cases each', () {
      expect(spec['profiles'], _ids);
      for (final id in _ids) {
        final mine = cases.where((c) => c['expected'] == id);
        expect(mine.length, greaterThanOrEqualTo(20), reason: id);
        expect(
          mine.where((c) => (c['tags']! as List).contains('ambiguous')),
          isNotEmpty,
          reason: '$id has ambiguous cases',
        );
      }
      expect(cases.map((c) => c['id']).toSet(), hasLength(cases.length));
      expect(cases.map((c) => c['split']).toSet(), {'dev', 'holdout'});
    });

    test(
      'the keyword stage decides with >= 95% precision, without the LLM',
      () async {
        final classifier = ProfileClassifier(llm: _NoLlm());
        var decided = 0;
        var correct = 0;
        for (final c in cases) {
          final r = await classifier.classify(
            profiles,
            c['transcript']! as String,
            allowLlm: false,
          );
          final value = r.valueOrNull;
          if (value?.method != ClassificationMethod.keyword) continue;
          decided++;
          if (value!.profileId == c['expected']) correct++;
        }
        expect(decided, greaterThan(cases.length ~/ 2));
        expect(correct / decided, greaterThanOrEqualTo(0.95));
      },
    );

    test('a clear case per profile is picked by keywords alone', () async {
      final classifier = ProfileClassifier(llm: _NoLlm());
      for (final id in _ids) {
        final c = cases.firstWhere(
          (c) => c['expected'] == id && (c['tags']! as List).contains('clear'),
        );
        final r = await classifier.classify(
          profiles,
          c['transcript']! as String,
          allowLlm: false,
        );
        expect(r.valueOrNull?.profileId, id, reason: c['id']! as String);
      }
    });

    test('every profile has keywords within the spec limits', () {
      for (final p in profiles) {
        expect(p.classifyKeywords, isNotEmpty, reason: p.id);
        expect(p.classifyKeywords.length, lessThanOrEqualTo(30));
      }
    });

    test('scoring.json mirrors the task file targets', () {
      final t =
          _json('$_evalDir/scoring.json')['targets']! as Map<String, Object?>;
      expect(t['accuracy'], 0.9);
      expect(t['accuracy_holdout'], 0.9);
      expect(t['accuracy_ambiguous'], 0.75);
      expect(t['recall_per_profile'], 0.8);
      expect(t['confident_wrong_rate_max'], 0.05);
      expect(t['keyword_precision'], 0.95);
      final task = File(_taskFile).readAsStringSync();
      expect(task, contains('written before the first baseline run'));
      for (final k in t.keys) {
        expect(task, contains('`$k`'), reason: k);
      }
    });

    test('the committed baseline reports accuracy and a confusion matrix '
        'that meets the targets', () {
      final baselines = Directory('../tools/bench/eval/baselines')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('/classify.'));
      expect(baselines, isNotEmpty);
      final agg =
          _json(baselines.first.path)['aggregate']! as Map<String, Object?>;
      expect(agg['cases'], cases.length);
      expect(agg['accuracy']! as num, greaterThanOrEqualTo(0.9));
      expect(agg['accuracy_holdout']! as num, greaterThanOrEqualTo(0.9));
      final confusion = agg['confusion']! as Map<String, Object?>;
      expect(confusion.keys, _ids);
      for (final row in confusion.values) {
        expect((row! as Map).keys, containsAll(_ids));
      }
    });
  });

  group('[TPL-04/AC2] classification latency', () {
    test('the device row exists and is pending a mid-tier device', () {
      final doc = File('../docs/test-plans/device/TPL-04.md')
          .readAsStringSync();
      expect(doc, contains('[TPL-04/AC2]'));
      expect(doc, contains('< 10 s'));
    });
  });

  group('[TPL-04/AC5] built-in profile enumeration', () {
    test('six built-ins, each with icon, description and keywords', () {
      final dir =
          Directory('assets/profiles')
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.yaml'))
              .map((f) => f.uri.pathSegments.last.replaceAll('.yaml', ''))
              .toList()
            ..sort();
      expect(dir, [..._ids]..sort());
      for (final p in profiles) {
        expect(p.icon, isNotNull, reason: p.id);
        expect(p.description, isNotEmpty, reason: p.id);
        expect(p.classifyKeywords, isNotEmpty, reason: p.id);
      }
    });
  });
}
