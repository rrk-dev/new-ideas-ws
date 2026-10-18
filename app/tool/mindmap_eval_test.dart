@TestOn('mac-os || linux')
library;

// MAP-01 mind-map eval driver (tools/bench/eval/mindmap/run_mindmap.py).
//
// Not part of CI: it lives under tool/ and is run explicitly, in one process
// with the host llama.cpp build, through `flutter test` because the shared
// extraction code imports Flutter:
//
//   VV_MINDMAP_CASES=… VV_MINDMAP_OUT=… VV_MINDMAP_MODEL=… VV_NATIVE_LIB=… \
//     fvm flutter test tool/mindmap_eval_test.dart
//
// Per case: the real extraction of the case's profile (production map-reduce
// path, 1B model), then options A (projection), B (LLM topics) and C (hybrid)
// of ADR-MAP-01 through the same `MindMapGenerator` the pipeline uses. B and
// C share one memoized LLM call (greedy sampling => identical output); its
// wall time is `llm_ms`. One JSON line per case. Transcripts are synthetic.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/features/extraction/data/ffi_llm_runtime.dart';
import 'package:vaultvoice/features/extraction/data/native_schema_grammar_converter.dart';
import 'package:vaultvoice/features/extraction/domain/llm_backend_policy.dart';
import 'package:vaultvoice/features/extraction/domain/llm_service.dart';
import 'package:vaultvoice/features/extraction/domain/long_transcript/extraction_prompts.dart';
import 'package:vaultvoice/features/extraction/domain/long_transcript/map_reduce_extractor.dart';
import 'package:vaultvoice/features/extraction/domain/long_transcript/transcript_chunker.dart';
import 'package:vaultvoice/features/mindmap/domain/mind_map_generator.dart';
import 'package:vaultvoice/features/mindmap/domain/mind_map_schema.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';
import 'package:vaultvoice/features/profiles/domain/builtin_profiles.dart';
import 'package:vv_native/vv_native.dart';

final _line = RegExp(r'^\[(\d{2}):(\d{2}):(\d{2})\] (?:([^:]{1,40}): )?(.*)$');

List<TranscriptLine> _parse(String transcript) => [
  for (final raw in const LineSplitter().convert(transcript))
    if (_line.firstMatch(raw) case final m?)
      TranscriptLine(
        startMs:
            (int.parse(m[1]!) * 3600 +
                int.parse(m[2]!) * 60 +
                int.parse(m[3]!)) *
            1000,
        speaker: m[4],
        text: m[5]!,
      ),
];

/// Caches answers by request so B and C pay for one LLM call.
class _MemoEngine implements LlmEngine {
  _MemoEngine(this.inner);

  final LlmEngine inner;
  final _cache = <String, Result<String>>{};
  int liveMs = 0;

  @override
  Future<Result<String>> generate(
    LlmRequest request, {
    CancelToken? cancel,
    void Function(String token)? onToken,
  }) async {
    final key =
        '${request.systemPrompt}\u0000${request.prompt}'
        '\u0000${request.grammar}';
    final hit = _cache[key];
    if (hit != null) return hit;
    final watch = Stopwatch()..start();
    final result = await inner.generate(
      request,
      cancel: cancel,
      onToken: onToken,
    );
    liveMs += watch.elapsedMilliseconds;
    return _cache[key] = result;
  }
}

void main() {
  final env = Platform.environment;
  final casesPath = env['VV_MINDMAP_CASES'];
  final model = env['VV_MINDMAP_MODEL'];
  final lib = env['VV_NATIVE_LIB'];
  final skip = casesPath == null || model == null || lib == null
      ? 'set VV_MINDMAP_CASES, VV_MINDMAP_MODEL, VV_NATIVE_LIB, VV_MINDMAP_OUT'
      : null;

  test('mind-map eval', skip: skip, timeout: Timeout.none, () async {
    final cases =
        ((jsonDecode(File(casesPath!).readAsStringSync())
                    as Map<String, Object?>)['cases']!
                as List<Object?>)
            .cast<Map<String, Object?>>();
    final limit = int.tryParse(env['VV_MINDMAP_LIMIT'] ?? '');
    final selected = limit == null ? cases : cases.take(limit).toList();
    final builtins = BuiltinProfiles.parse({
      for (final a in kBuiltinProfileAssets) a: File(a).readAsStringSync(),
    });
    final converter = NativeSchemaGrammarConverter(hostPath: lib);
    final topicGrammar = (await converter.toGbnf(jsonEncode(kMindMapLlmSchema)))
        .valueOrNull!;
    final native = VvNative.open(hostPath: lib);
    final service = LlmService(
      runtime: FfiLlmRuntime(native),
      modelPath: model!,
      backend: () => const LlmBackendChoice(useGpu: false, reason: 'host'),
    );
    addTearDown(service.unload);
    final memo = _MemoEngine(service);
    final extractor = MapReduceExtractor(engine: memo, tokenizer: service);
    final out = File(env['VV_MINDMAP_OUT'] ?? 'mindmap_eval.jsonl').openWrite();
    addTearDown(out.close);

    for (final c in selected) {
      final profile = builtins[c['profile']! as String]!;
      final schema = profile.schema.toJson();
      final grammar = (await converter.toGbnf(jsonEncode(schema))).valueOrNull!;
      final lines = _parse(c['transcript']! as String);

      final extractWatch = Stopwatch()..start();
      final extraction = await extractor.extract(
        LongExtractionInput(
          lines: lines,
          prompts: ProfilePromptSource(profile),
          spec: MapReduceSpec(
            schema: schema,
            grammar: grammar,
            strategyFor: profile.reduceStrategyFor,
          ),
          tier: DeviceTier.mid,
          paramsKey: 'eval|${profile.id}',
        ),
      );
      final extractMs = extractWatch.elapsedMilliseconds;
      final outcome = extraction.valueOrNull?.outcome;
      final valid = outcome?.valid ?? false;
      final extracted = valid ? outcome!.data : null;
      final record = <String, Object?>{
        'id': c['id'],
        'profile': c['profile'],
        'extraction_valid': valid,
        'extraction_ms': extractMs,
      };

      final liveBefore = memo.liveMs;
      for (final method in MindMapMethod.values) {
        final watch = Stopwatch()..start();
        final r =
            await MindMapGenerator(
              method: method,
              extractor: extractor,
              grammar: topicGrammar,
            ).generate(
              MindMapInput(
                lines: lines,
                tier: DeviceTier.mid,
                modelId: 'eval',
                extraction: extracted,
                fallbackTitle: c['title']! as String,
              ),
            );
        final res = r.valueOrNull;
        record[method.name] = {
          'ok': res != null,
          'schema_valid': method == MindMapMethod.projection
              ? valid
              : res?.schemaValid ?? false,
          'raw_labels': res?.rawLabels ?? 0,
          'grounded_labels': res?.groundedLabels ?? 0,
          'tree': res?.tree?.toJson(),
          'ms': watch.elapsedMilliseconds,
        };
      }
      record['llm_ms'] = memo.liveMs - liveBefore;
      out.writeln(jsonEncode(record));
      await out.flush();
    }
  });
}
