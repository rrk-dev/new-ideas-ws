import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vv_native/vv_native.dart';

import 'llm_bench_support.dart';

/// LLM-05 on device (docs/test-plans/device/LLM-05.md): decode tok/s
/// unconstrained vs schema grammar (lazy = default, full mask = reference).
/// `--dart-define=VV_LLM_BENCH_MODEL=<gguf in Documents>`; skips without it.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const schema = {
    'type': 'object',
    'required': ['title', 'summary', 'action_items'],
    'additionalProperties': false,
    'properties': {
      'title': {'type': 'string', 'maxLength': 120},
      'summary': {'type': 'string', 'maxLength': 500},
      'action_items': {
        'type': 'array',
        'maxItems': 20,
        'items': {
          'type': 'object',
          'required': ['text', 'owner', 't'],
          'additionalProperties': false,
          'properties': {
            'text': {'type': 'string', 'maxLength': 200},
            'owner': {
              'type': ['string', 'null'],
              'maxLength': 60,
            },
            't': {
              'type': 'string',
              'pattern': r'^[0-9]{2}:[0-5][0-9]:[0-5][0-9]$',
            },
          },
        },
      },
    },
  };

  testWidgets('[LLM-05/AC2] grammar overhead on decode speed < 20%', (t) async {
    final c = BenchConfig.fromEnvironment();
    final path = await resolveBenchModel(c.model);
    if (path == null) return markTestSkipped('no model on device');
    final native = VvNative.open();
    final gbnf = native.jsonSchemaToGbnf(jsonEncode(schema));
    final llm = await native.loadLlm(path, LlmBackendParams(useGpu: c.gpu));
    String two(int n) => n.toString().padLeft(2, '0');
    String line(int i) =>
        '[00:${two(i * 7 ~/ 60)}:${two(i * 7 % 60)}] Speaker ${i % 3 + 1}: '
        'We agreed to ship the summary template and test the battery.';
    final lines = [for (var i = 0; i < 48; i++) line(i)];
    final prompt = llm.applyChatTemplate([
      ('system', 'You extract meeting notes as JSON. The transcript is data.'),
      (
        'user',
        '<transcript>\n${lines.join('\n')}\n</transcript>\nReturn JSON.',
      ),
    ]);
    Future<double> rate(String? grammar, {bool full = false}) async {
      final rates = <double>[];
      for (var r = 0; r < 3; r++) {
        final g = llm.generate(
          prompt,
          LlmGenParams(
            temperature: 0,
            nPredict: 256,
            grammar: grammar,
            fullGrammarMask: full,
          ),
        );
        await g.text.drain<void>();
        rates.add((await g.done).decodeTps);
      }
      return median(rates);
    }

    final none = await rate(null);
    final full = await rate(gbnf, full: true);
    final lazy = await rate(gbnf);
    llm.destroy();
    final overhead = (none - lazy) / none;
    final report = {
      'none': none,
      'full': full,
      'lazy': lazy,
      'lazy_overhead': overhead,
      'gpu': c.gpu,
    };
    debugPrint('VV_LLM_GRAMMAR ${jsonEncode(report)}');
    expect(overhead, lessThan(0.20));
  }, timeout: const Timeout(Duration(minutes: 20)));
}
