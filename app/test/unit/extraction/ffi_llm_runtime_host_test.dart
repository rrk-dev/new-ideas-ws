@TestOn('mac-os || linux')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/features/extraction/data/ffi_llm_runtime.dart';
import 'package:vaultvoice/features/extraction/domain/llm_backend_policy.dart';
import 'package:vaultvoice/features/extraction/domain/llm_service.dart';
import 'package:vv_native/vv_native.dart';

/// LLM-04 end-to-end on the host: LlmService → FfiLlmRuntime → vv_native
/// with SmolLM2 (`$VV_TEST_MODELS_DIR`). Skipped without the host build or
/// the model.
void main() {
  final ext = Platform.isMacOS ? 'dylib' : 'so';
  final lib = File('../native/build/host/libvv_native.$ext');
  final dir = Platform.environment['VV_TEST_MODELS_DIR'];
  final model = dir == null
      ? null
      : File('$dir/SmolLM2-135M-Instruct-Q8_0.gguf');
  final skip = !lib.existsSync()
      ? 'run native/build.sh host first'
      : model == null || !model.existsSync()
      ? 'set VV_TEST_MODELS_DIR (tools/ci/fetch_test_models.sh)'
      : null;

  LlmService make() => LlmService(
    runtime: FfiLlmRuntime(VvNative.open(hostPath: lib.absolute.path)),
    modelPath: model!.path,
    backend: () => const LlmBackendChoice(useGpu: true, reason: 'host'),
    contextSize: 1024,
  );

  test('streams a templated deterministic answer', () async {
    final s = make();
    addTearDown(s.unload);
    final tokens = <String>[];
    final r = await s.generate(
      const LlmRequest(
        prompt: 'Name three colors.',
        systemPrompt: 'Answer briefly.',
        maxTokens: 24,
        sampling: LlmSampling(preset: LlmPreset.deterministic),
      ),
      onToken: tokens.add,
    );
    expect(r.valueOrNull, isNotEmpty);
    expect(tokens.join(), r.valueOrNull);
    final again = await s.generate(
      const LlmRequest(
        prompt: 'Name three colors.',
        systemPrompt: 'Answer briefly.',
        maxTokens: 24,
        sampling: LlmSampling(preset: LlmPreset.deterministic),
      ),
    );
    expect(again.valueOrNull, r.valueOrNull);
  }, skip: skip);

  test('[LLM-04/AC1] CancelToken stops generation within 500 ms', () async {
    final s = make();
    addTearDown(s.unload);
    final cancel = CancelToken();
    final sw = Stopwatch();
    final r = await s.generate(
      const LlmRequest(
        prompt: 'Write a very long story about a dragon and a knight.',
        maxTokens: 700,
        sampling: LlmSampling(preset: LlmPreset.summary),
      ),
      cancel: cancel,
      onToken: (_) {
        if (!sw.isRunning) {
          sw.start();
          cancel.cancel();
        }
      },
    );
    sw.stop();
    expect(r.failureOrNull, isA<CancelledFailure>());
    expect(sw.elapsedMilliseconds, lessThan(500));
  }, skip: skip);

  test('grammar-constrained output over the full stack', () async {
    final s = make();
    addTearDown(s.unload);
    final r = await s.generate(
      const LlmRequest(
        prompt: 'Is the sky blue?',
        grammar: r'root ::= "{\"answer\": " ("true" | "false") "}"',
        maxTokens: 16,
        sampling: LlmSampling(preset: LlmPreset.deterministic),
      ),
    );
    expect(r.valueOrNull, anyOf('{"answer": true}', '{"answer": false}'));
  }, skip: skip);
}
