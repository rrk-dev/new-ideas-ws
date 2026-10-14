@TestOn('mac-os || linux')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vv_native/vv_native.dart';

/// LLM-04 host FFI tests of the streaming engine against
/// `native/build/host` and SmolLM2-135M from `$VV_TEST_MODELS_DIR`
/// (tools/ci/fetch_test_models.sh). Skipped when either is missing.
String? _hostLib() {
  final fromEnv = Platform.environment['VV_NATIVE_LIB'];
  if (fromEnv != null) return fromEnv;
  final ext = Platform.isMacOS ? 'dylib' : 'so';
  final f = File('../../native/build/host/libvv_native.$ext');
  return f.existsSync() ? f.absolute.path : null;
}

String? _model() {
  final dir = Platform.environment['VV_TEST_MODELS_DIR'];
  if (dir == null) return null;
  final f = File('$dir/SmolLM2-135M-Instruct-Q8_0.gguf');
  return f.existsSync() ? f.path : null;
}

void main() {
  final lib = _hostLib();
  final model = _model();
  final skip = lib == null
      ? 'run native/build.sh host first'
      : model == null
      ? 'set VV_TEST_MODELS_DIR (tools/ci/fetch_test_models.sh)'
      : null;
  const params = LlmBackendParams(nCtx: 1024, nBatch: 256);

  Future<String> collect(LlmGeneration g) async {
    final b = StringBuffer();
    await g.text.forEach(b.write);
    return b.toString();
  }

  late VvNative native;
  late String prompt;
  setUpAll(() async {
    if (skip != null) return;
    native = VvNative.open(hostPath: lib);
    final llm = await native.loadLlm(model!, params);
    prompt = llm.applyChatTemplate([
      ('system', 'You are a storyteller.'),
      ('user', 'Write a long story about a dragon and a knight.'),
    ]);
    llm.destroy();
  });

  test('loads, reports backend info, counts tokens, streams text', () async {
    final llm = await native.loadLlm(model!, params);
    addTearDown(llm.destroy);
    final info = llm.info;
    expect(info.nCtx, greaterThanOrEqualTo(1024));
    expect(info.usedGpu, Platform.isMacOS);
    expect(llm.countTokens('Hello world'), inInclusiveRange(2, 6));
    expect(prompt, contains('dragon and a knight'));
    final g = llm.generate(prompt, const LlmGenParams(nPredict: 32));
    final chunks = <String>[];
    final sub = g.text.listen(chunks.add);
    final r = await g.done;
    await sub.cancel();
    expect(r.status, VV_OK);
    expect(r.nGen, greaterThan(0));
    expect(chunks.join(), isNotEmpty);
    expect(r.decodeTps, greaterThan(0));
  }, skip: skip);

  test('[LLM-04/AC2] same seed + prompt yields identical output', () async {
    final llm = await native.loadLlm(model!, params);
    addTearDown(llm.destroy);
    const sampled = LlmGenParams(temperature: 0.8, seed: 1234, nPredict: 48);
    final a = await collect(llm.generate(prompt, sampled));
    final b = await collect(llm.generate(prompt, sampled));
    expect(a, isNotEmpty);
    expect(b, a);
    const other = LlmGenParams(temperature: 0.8, seed: 99, nPredict: 48);
    final c = await collect(llm.generate(prompt, other));
    expect(c, isNot(a), reason: 'seed must matter at temperature 0.8');
    final greedy1 = await collect(
      llm.generate(prompt, const LlmGenParams.deterministic(nPredict: 32)),
    );
    final greedy2 = await collect(
      llm.generate(prompt, const LlmGenParams.deterministic(nPredict: 32)),
    );
    expect(greedy2, greedy1);
  }, skip: skip);

  test(
    '[LLM-04/AC1] cancel stops a running generation within 500 ms',
    () async {
      final llm = await native.loadLlm(model!, params);
      addTearDown(llm.destroy);
      final g = llm.generate(
        prompt,
        const LlmGenParams(nPredict: 700, tokenBatch: 1),
      );
      final first = g.text.first; // at least one chunk streamed
      await first;
      final sw = Stopwatch()..start();
      g.cancel();
      final r = await g.done;
      sw.stop();
      expect(r.status, VV_E_CANCELLED);
      expect(r.nGen, lessThan(700));
      expect(sw.elapsedMilliseconds, lessThan(500));
    },
    skip: skip,
  );

  test(
    'second generate while busy -> VV_E_BUSY; bad grammar rejected',
    () async {
      final llm = await native.loadLlm(model!, params);
      addTearDown(llm.destroy);
      final g = llm.generate(prompt, const LlmGenParams(nPredict: 200));
      expect(
        () => llm.generate(prompt, const LlmGenParams()),
        throwsA(isA<VvLlmException>().having((e) => e.code, 'code', VV_E_BUSY)),
      );
      g.cancel();
      await g.done;
      expect(
        () => llm.generate(prompt, const LlmGenParams(grammar: 'root ::= (((')),
        throwsA(
          isA<VvLlmException>().having((e) => e.code, 'code', VV_E_INVALID_ARG),
        ),
      );
      final json = await collect(
        llm.generate(
          prompt,
          const LlmGenParams.deterministic(
            grammar: r'root ::= "{\"ok\": " ("true" | "false") "}"',
          ),
        ),
      );
      expect(json, anyOf('{"ok": true}', '{"ok": false}'));
    },
    skip: skip,
  );

  test('[LLM-04/AC3] model unload returns RAM to baseline (± 50 MB)', () async {
    // The first load of the process initialises process-wide backend state
    // (Metal device/pipelines) once; the baseline is taken after it.
    final warm = await native.loadLlm(model!, params);
    await collect(warm.generate(prompt, const LlmGenParams(nPredict: 8)));
    warm.destroy();
    final baseline = native.processMemory.$1;
    var worst = 0;
    for (var i = 0; i < 4; i++) {
      final llm = await native.loadLlm(
        model,
        LlmBackendParams(useGpu: i.isOdd, nCtx: 1024, nBatch: 256),
      );
      await collect(llm.generate(prompt, const LlmGenParams(nPredict: 16)));
      llm.destroy();
      final delta = native.processMemory.$1 - baseline;
      if (delta > worst) worst = delta;
    }
    expect(worst, lessThan(50 * 1024 * 1024));
  }, skip: skip);
}
