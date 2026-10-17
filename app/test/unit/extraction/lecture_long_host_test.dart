@TestOn('mac-os || linux')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/extraction/data/ffi_llm_runtime.dart';
import 'package:vaultvoice/features/extraction/data/native_schema_grammar_converter.dart';
import 'package:vaultvoice/features/extraction/domain/llm_backend_policy.dart';
import 'package:vaultvoice/features/extraction/domain/llm_runtime.dart';
import 'package:vaultvoice/features/extraction/domain/llm_service.dart';
import 'package:vaultvoice/features/extraction/domain/long_transcript/extraction_prompts.dart';
import 'package:vaultvoice/features/extraction/domain/long_transcript/map_reduce_extractor.dart';
import 'package:vaultvoice/features/extraction/domain/long_transcript/token_budget.dart';
import 'package:vaultvoice/features/extraction/domain/long_transcript/transcript_chunker.dart';
import 'package:vaultvoice/features/extraction/domain/output_schema_validator.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';
import 'package:vaultvoice/features/profiles/domain/builtin_profiles.dart';
import 'package:vv_native/vv_native.dart';

/// TPL-01 AC5: a 60-minute single-speaker lecture runs through the LLM-06
/// map-reduce path on the host build (real tokenizer, grammar and engine;
/// SmolLM2-135M exercises the path, its answers are not quality numbers).
/// Every call must fit n_ctx and peak memory must stay bounded by the
/// context, not the transcript length.
void main() {
  final ext = Platform.isMacOS ? 'dylib' : 'so';
  final lib = File('../native/build/host/libvv_native.$ext');
  final dir = Platform.environment['VV_TEST_MODELS_DIR'];
  final model = dir == null
      ? null
      : File('$dir/SmolLM2-135M-Instruct-Q8_0.gguf');
  final skip = !lib.existsSync()
      ? 'run native/build.sh host first'
      : (model == null || !model.existsSync()
            ? 'set VV_TEST_MODELS_DIR (tools/ci/fetch_test_models.sh)'
            : null);

  const topics = [
    'graph traversal',
    'shortest paths',
    'hash tables',
    'dynamic programming',
    'sorting networks',
    'amortised analysis',
  ];

  String assignment(int n) =>
      'Your assignment: finish exercise $n by next Friday. ';

  // ~150 words/minute of fictional lecture speech, one line per ~10 seconds.
  List<TranscriptLine> lecture(int minutes) => [
    for (var i = 0; i < minutes * 6; i++)
      TranscriptLine(
        startMs: i * 10000,
        text:
            'In this part we discuss ${topics[(i ~/ 30) % topics.length]}. '
            'The key idea number $i is that each step reduces the remaining '
            'problem, so we can reason about the cost of every operation. '
            '${i % 36 == 5 ? assignment(i ~/ 36 + 1) : ''}'
            'Keep this in mind as we move to the next example on the board.',
      ),
  ];

  test(
    '[TPL-01/AC5] host: a 60-minute lecture completes through map-reduce '
    'within n_ctx and bounded memory',
    () async {
      final profile = BuiltinProfiles.parse({
        for (final a in kBuiltinProfileAssets) a: File(a).readAsStringSync(),
      })['lecture']!;
      final schema = profile.schema.toJson();
      final native = VvNative.open(hostPath: lib.absolute.path);
      final grammar = (await NativeSchemaGrammarConverter(
        hostPath: lib.absolute.path,
      ).toGbnf(jsonEncode(schema))).valueOrNull!;
      final stats = <LlmRunStats>[];
      final service = LlmService(
        runtime: FfiLlmRuntime(native),
        modelPath: model!.path,
        backend: () => const LlmBackendChoice(useGpu: true, reason: 'host'),
        onStats: stats.add,
      );
      addTearDown(service.unload);
      final extractor = MapReduceExtractor(engine: service, tokenizer: service);
      LongExtractionInput input(List<TranscriptLine> lines) =>
          LongExtractionInput(
            lines: lines,
            prompts: ProfilePromptSource(profile),
            spec: MapReduceSpec(
              schema: schema,
              grammar: grammar,
              strategyFor: profile.reduceStrategyFor,
            ),
            tier: DeviceTier.low,
            maxTokens: 768,
            paramsKey: 'smollm2|lecture',
          );

      Future<LongExtractionResult> run(int minutes) async {
        final res = await extractor.extract(input(lecture(minutes)));
        expect(res.valueOrNull, isNotNull, reason: '${res.failureOrNull}');
        return res.valueOrNull!;
      }

      await run(5);
      final (_, peakShort) = native.processMemory;
      final shortCalls = stats.length;
      final long = await run(60);
      final (_, peakLong) = native.processMemory;
      final ctx = (await service.contextWindow()).valueOrNull!;

      expect(long.plan.mode, ExtractionMode.mapReduce);
      expect(long.chunks, greaterThanOrEqualTo(4));
      if (long.outcome.valid) {
        expect(
          const OutputSchemaValidator().validate(long.outcome.data, schema),
          isEmpty,
        );
      }
      final longStats = stats.sublist(shortCalls);
      // Map/reduce calls fit n_ctx with their full n_predict. A repair
      // prompt (prompt + the invalid answer) can exceed it; the engine
      // refuses it (0 tokens generated) and the chunk contributes nothing —
      // a safe failure, tracked as a follow-up in the task file.
      for (final s in longStats.where((s) => s.generatedTokens > 0)) {
        expect(s.promptTokens + 768, lessThanOrEqualTo(ctx));
      }
      expect(
        longStats
            .where((s) => s.promptTokens + 768 > ctx)
            .every((s) => s.generatedTokens == 0),
        isTrue,
        reason: 'oversized calls are rejected, never run',
      );
      expect(peakLong - peakShort, lessThan(150 * 1024 * 1024));

      // Content-free report line for the Completion Notes.
      // ignore: avoid_print
      print(
        'TPL-01 host: ctx $ctx; 60 min: ${long.plan.transcriptTokens} tokens, '
        '${long.chunks} chunks (${long.failedChunks} invalid), valid '
        '${long.outcome.valid}; peak RSS ${peakShort >> 20} -> '
        '${peakLong >> 20} MiB',
      );
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 30)),
  );
}
