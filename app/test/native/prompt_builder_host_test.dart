@TestOn('mac-os || linux')
@Timeout(Duration(minutes: 5))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/features/extraction/data/ffi_llm_runtime.dart';
import 'package:vaultvoice/features/extraction/domain/llm_backend_policy.dart';
import 'package:vaultvoice/features/extraction/domain/llm_runtime.dart';
import 'package:vaultvoice/features/profiles/data/session_prompt_tokenizer.dart';
import 'package:vaultvoice/features/profiles/domain/prompt_builder.dart';
import 'package:vv_native/vv_native.dart';

import '../unit/profiles/profile_fixtures.dart';

/// PRF-02 with the real tokenizer + GGUF chat template (SmolLM2-135M through
/// the host bridge): the counted prompt is exactly what the generation
/// prefills, and prompt + n_predict fits n_ctx. Skipped without
/// `native/build.sh host` / `tools/ci/fetch_test_models.sh`.
String? _hostLib() {
  final fromEnv = Platform.environment['VV_NATIVE_LIB'];
  if (fromEnv != null) return fromEnv;
  final ext = Platform.isMacOS ? 'dylib' : 'so';
  final f = File('../native/build/host/libvv_native.$ext');
  return f.existsSync() ? f.absolute.path : null;
}

String? _model() {
  final dir =
      Platform.environment['VV_TEST_MODELS_DIR'] ??
      '${Platform.environment['HOME']}/.cache/vaultvoice/test-models';
  final f = File('$dir/SmolLM2-135M-Instruct-Q8_0.gguf');
  return f.existsSync() ? f.path : null;
}

void main() {
  final lib = _hostLib();
  final model = _model();
  final skip = lib == null
      ? 'run native/build.sh host first'
      : model == null
      ? 'run tools/ci/fetch_test_models.sh'
      : null;

  test('[PRF-02/AC1] real tokenizer: counted prompt == prefilled tokens and '
      'prompt + max_tokens <= n_ctx, map-reduce chunks included', () async {
    const ctx = 1024;
    const maxTokens = 64;
    final session = await FfiLlmRuntime(VvNative.open(hostPath: lib)).load(
      model!,
      const LlmBackendChoice(useGpu: false, reason: 'test'),
      contextSize: ctx,
    );
    addTearDown(session.dispose);
    final builder = PromptBuilder(SessionPromptTokenizer(session));
    final meta = PromptMetadata(
      recordedAt: DateTime(2026, 3, 2),
      duration: const Duration(minutes: 5),
    );
    List<PromptSegment> segs(int n) => [
      for (var i = 0; i < n; i++)
        PromptSegment(
          start: Duration(seconds: i * 6),
          speaker: 'S${i % 2 + 1}',
          text: 'Item $i: we agreed the release checklist needs review.',
        ),
    ];
    const budget = PromptBudget(contextSize: ctx, maxTokens: maxTokens);

    Future<void> runExact(BuiltPrompt p) async {
      expect(p.promptTokens + maxTokens, lessThanOrEqualTo(ctx));
      final run = session.generate(
        p.text,
        sampling: const LlmSampling(preset: LlmPreset.deterministic),
        maxTokens: 4,
      );
      await run.text.drain<void>();
      final stats = await run.done;
      expect(stats.status, LlmRunStatus.ok);
      expect(stats.promptTokens, p.promptTokens, reason: 'exact count');
    }

    final short = builder.build(
      PromptInput(
        profile: builtinProfile('meeting'),
        metadata: meta,
        segments: segs(3),
      ),
      budget,
    );
    await runExact((short as SinglePassPrompt).prompt);

    final long = builder.build(
      PromptInput(
        profile: builtinProfile('meeting'),
        metadata: meta,
        segments: segs(200),
      ),
      budget,
    );
    expect(long, isA<MapReducePrompt>());
    final plan = long as MapReducePrompt;
    // Greedy chunks by exact segment tokens; shrink when a render refuses.
    var start = 0;
    var chunks = 0;
    while (start < plan.input.segments.length) {
      var end = start + 1;
      while (end < plan.input.segments.length &&
          plan.segmentTokens(plan.input.segments.sublist(start, end + 1)) <=
              plan.chunkTranscriptBudget) {
        end++;
      }
      BuiltPrompt? p;
      while ((p = plan.renderChunk(
            plan.input.segments.sublist(start, end),
            index: chunks,
            count: 99,
          )) ==
          null) {
        end--;
        expect(end, greaterThan(start));
      }
      if (chunks < 2) await runExact(p!);
      expect(p!.promptTokens + maxTokens, lessThanOrEqualTo(ctx));
      chunks++;
      start = end;
    }
    expect(chunks, greaterThan(1));
  }, skip: skip);
}
