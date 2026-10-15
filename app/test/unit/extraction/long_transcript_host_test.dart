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
import 'package:vaultvoice/features/extraction/domain/long_transcript/partial_reducer.dart';
import 'package:vaultvoice/features/extraction/domain/long_transcript/token_budget.dart';
import 'package:vaultvoice/features/extraction/domain/long_transcript/transcript_chunker.dart';
import 'package:vaultvoice/features/extraction/domain/output_schema_validator.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';
import 'package:vaultvoice/features/profiles/domain/builtin_profiles.dart';
import 'package:vv_native/vv_native.dart';

import '../../helpers/synthetic_transcript.dart';

/// LLM-06 end-to-end on the host build with the real tokenizer, grammar and
/// engine (SmolLM2-135M — the smallest model; recall numbers here are NOT
/// quality numbers, they only exercise the path). Synthetic transcripts,
/// sized by tokens: the 2-hour case is ~10× the 4k context.
///
/// Checks: map-reduce completes with schema-valid output; every call fits
/// n_ctx (prompt + n_predict); peak process memory after the 2-hour run
/// stays within 150 MiB of the 10-minute run (memory is bounded by n_ctx,
/// not transcript length); map calls after the first reuse the shared
/// system-prompt KV prefix. Prints a content-free report line.
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

  test(
    '[LLM-06/AC1] host: 2-hour transcript map-reduce with SmolLM2 completes '
    'within n_ctx and bounded memory',
    () async {
      final native = VvNative.open(hostPath: lib.absolute.path);
      final grammar = (await NativeSchemaGrammarConverter(
        hostPath: lib.absolute.path,
      ).toGbnf(jsonEncode(meetingTestSchema))).valueOrNull!;
      final stats = <LlmRunStats>[];
      final service = LlmService(
        runtime: FfiLlmRuntime(native),
        modelPath: model!.path,
        backend: () => const LlmBackendChoice(useGpu: true, reason: 'host'),
        onStats: stats.add,
      );
      addTearDown(service.unload);
      final meeting = BuiltinProfiles.parse({
        for (final a in kBuiltinProfileAssets) a: File(a).readAsStringSync(),
      })['meeting']!;
      final extractor = MapReduceExtractor(engine: service, tokenizer: service);
      LongExtractionInput input(List<TranscriptLine> lines) =>
          LongExtractionInput(
            lines: lines,
            prompts: ProfilePromptSource(meeting),
            spec: MapReduceSpec(
              schema: meetingTestSchema,
              grammar: grammar,
              strategyFor: meeting.reduceStrategyFor,
            ),
            tier: DeviceTier.low,
            maxTokens: 768,
            paramsKey: 'smollm2|meeting',
          );

      Future<({LongExtractionResult r, double recall, Duration took})> run(
        int minutes,
      ) async {
        final m = syntheticMeeting(minutes: minutes, actionEveryMinutes: 2);
        final sw = Stopwatch()..start();
        final res = await extractor.extract(input(m.lines));
        sw.stop();
        final r = res.valueOrNull;
        expect(r, isNotNull, reason: '${res.failureOrNull}');
        final items =
            (r!.outcome.data?['action_items'] as List<Object?>?) ?? const [];
        return (
          r: r,
          recall: actionItemRecall(items, m.actions, tokenJaccard),
          took: sw.elapsed,
        );
      }

      final short = await run(10);
      final (_, peakShort) = native.processMemory;
      final shortCalls = stats.length;
      final long = await run(120);
      final (_, peakLong) = native.processMemory;
      final ctx = (await service.contextWindow()).valueOrNull!;

      expect(long.r.plan.mode, ExtractionMode.mapReduce);
      expect(long.r.chunks, greaterThanOrEqualTo(8));
      if (long.r.outcome.valid) {
        expect(
          const OutputSchemaValidator().validate(
            long.r.outcome.data,
            meetingTestSchema,
          ),
          isEmpty,
        );
      }
      final longStats = stats.sublist(shortCalls);
      for (final s in longStats) {
        expect(s.promptTokens + 768, lessThanOrEqualTo(ctx));
      }
      final mapStats = longStats.take(long.r.chunks).toList();
      final reused = mapStats.skip(1).map((s) => s.reusedPromptTokens);
      expect(reused.every((n) => n > 0), isTrue, reason: 'prefix reuse');
      expect(peakLong - peakShort, lessThan(150 * 1024 * 1024));

      final prompt = mapStats.fold<int>(0, (a, s) => a + s.promptTokens);
      final kept = mapStats.fold<int>(0, (a, s) => a + s.reusedPromptTokens);
      // Content-free report line for the Completion Notes.
      // ignore: avoid_print
      print(
        'LLM-06 host: ctx $ctx; 10 min: ${short.r.plan.mode.name} '
        '${short.took.inSeconds}s recall ${short.recall.toStringAsFixed(2)}; '
        '2 h: ${long.r.plan.transcriptTokens} tokens, ${long.r.chunks} '
        'chunks (${long.r.failedChunks} invalid), valid '
        '${long.r.outcome.valid}, ${long.took.inSeconds}s, recall '
        '${long.recall.toStringAsFixed(2)}; prefix reuse $kept/$prompt '
        'prompt tokens (${(100 * kept / prompt).toStringAsFixed(1)}%); peak '
        'RSS ${peakShort >> 20} -> ${peakLong >> 20} MiB',
      );
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 30)),
  );
}
