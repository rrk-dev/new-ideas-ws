import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _adr = '../docs/adr/ADR-MAP-01-mind-map-generation.md';
const _task = '../tasks/14-product-phase2/MAP-01-mind-map-generation.md';
const _device = '../docs/test-plans/device/MAP-01.md';
const _evalDir = '../tools/bench/eval/mindmap';
const _baseline =
    '../tools/bench/eval/baselines/mindmap.Llama-3-2-1B-Instruct-Q4-K-M.json';

Map<String, Object?> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

void main() {
  final scoring = _json('$_evalDir/scoring.json');
  final targets = scoring['targets']! as Map<String, Object?>;
  final baseline = _json(_baseline);
  final options = baseline['options']! as Map<String, Object?>;

  test(
    '[MAP-01/AC1] the ADR compares A/B/C on the eval set and fixes limits',
    () {
      final adr = File(_adr).readAsStringSync();
      expect(adr, contains('Status:** Proposed'));
      for (final m in ['A projection', 'B llm', 'C hybrid']) {
        expect(adr, contains(m));
      }
      expect(adr, contains('tools/bench/results/'));
      expect(adr, contains('depth ≤ 3'));
      expect(adr, contains('≤ 40 nodes'));
      expect(adr, contains('≤ 60 characters'));
      expect(adr, contains('PRODUCT-DECISION'));
      final chosen = baseline['chosen']! as String;
      expect(adr, contains('Method: C (hybrid)'));
      expect(chosen, 'hybrid');
      expect(File('$_evalDir/cases.json').existsSync(), isTrue);
    },
  );

  test('[MAP-01/AC3] the baseline has >= 30 cases and meets the targets', () {
    final cases = (_json('$_evalDir/cases.json')['cases']! as List)
        .cast<Map<String, Object?>>();
    expect(cases.length, greaterThanOrEqualTo(30));
    expect((baseline['env']! as Map)['cases'], cases.length);
    expect(targets['schema_valid'], 0.9);
    expect(targets['label_grounding'], 0.85);
    final chosen = options[baseline['chosen']]! as Map<String, Object?>;
    for (final entry in targets.entries) {
      final v = chosen[entry.key]! as num;
      expect(v, greaterThanOrEqualTo(entry.value! as num), reason: entry.key);
    }
    expect(options.keys, containsAll(['projection', 'llm', 'hybrid']));
  });

  test(
    '[MAP-01/AC5] budgets are in the task file and the device rows pend',
    () {
      final task = File(_task).readAsStringSync();
      expect(task, contains('Cost budgets of the mind-map step'));
      for (final row in [
        '| High | ≤ 30 |',
        '| Mid | ≤ 60 |',
        '| Low | ≤ 120 |',
      ]) {
        expect(task, contains(row));
      }
      final device = File(_device).readAsStringSync();
      expect(device, contains('[MAP-01/AC5]'));
      expect(device, contains('⏳'));
    },
  );
}
