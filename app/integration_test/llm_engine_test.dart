import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vv_native/vv_native.dart';

import 'llm_bench_support.dart';

/// LLM-04 on device (docs/test-plans/device/LLM-04.md): cancel latency
/// during decode and during a long prefill, determinism, unload memory.
/// `--dart-define=VV_LLM_BENCH_MODEL=<gguf in Documents>`; skips without it.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<String?> model() =>
      resolveBenchModel(const String.fromEnvironment('VV_LLM_BENCH_MODEL'));
  final gpu = BenchConfig.fromEnvironment().gpu;

  Future<String> collect(LlmGeneration g) async {
    final b = StringBuffer();
    await g.text.forEach(b.write);
    return b.toString();
  }

  testWidgets('[LLM-04/AC1] cancel < 500 ms during decode and prefill', (
    t,
  ) async {
    final path = await model();
    if (path == null) return markTestSkipped('no model on device');
    final llm = await VvNative.open().loadLlm(
      path,
      LlmBackendParams(useGpu: gpu),
    );
    final prompt = llm.applyChatTemplate([
      ('user', 'Write a very long story about a dragon and a knight.'),
    ]);
    // During decode.
    var g = llm.generate(prompt, const LlmGenParams(nPredict: 2000));
    await g.text.first;
    var sw = Stopwatch()..start();
    g.cancel();
    var r = await g.done;
    debugPrint('VV_LLM_CANCEL decode_ms=${sw.elapsedMilliseconds}');
    expect(r.status, VV_E_CANCELLED);
    expect(sw.elapsedMilliseconds, lessThan(500));
    // During a ~3k-token prefill.
    final long = llm.applyChatTemplate([
      ('user', List.filled(300, 'The team reviewed the plan again.').join(' ')),
    ]);
    g = llm.generate(long, const LlmGenParams(nPredict: 64));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    sw = Stopwatch()..start();
    g.cancel();
    r = await g.done;
    debugPrint('VV_LLM_CANCEL prefill_ms=${sw.elapsedMilliseconds}');
    expect(r.status, VV_E_CANCELLED);
    expect(sw.elapsedMilliseconds, lessThan(500));
    llm.destroy();
  }, timeout: const Timeout(Duration(minutes: 10)));

  testWidgets('[LLM-04/AC2] same seed + prompt -> identical output on device', (
    t,
  ) async {
    final path = await model();
    if (path == null) return markTestSkipped('no model on device');
    final llm = await VvNative.open().loadLlm(
      path,
      LlmBackendParams(useGpu: gpu),
    );
    final prompt = llm.applyChatTemplate([('user', 'Name three colors.')]);
    const p = LlmGenParams(temperature: 0.8, seed: 1234, nPredict: 64);
    final a = await collect(llm.generate(prompt, p));
    final b = await collect(llm.generate(prompt, p));
    llm.destroy();
    expect(b, a);
  }, timeout: const Timeout(Duration(minutes: 10)));

  testWidgets('[LLM-04/AC3] unload returns memory to baseline (± 50 MB)', (
    t,
  ) async {
    final path = await model();
    if (path == null) return markTestSkipped('no model on device');
    final native = VvNative.open();
    final warm = await native.loadLlm(path, LlmBackendParams(useGpu: gpu));
    warm.destroy();
    final base = native.processMemory.$1;
    for (var i = 0; i < 3; i++) {
      final llm = await native.loadLlm(path, LlmBackendParams(useGpu: gpu));
      await collect(
        llm.generate(
          llm.applyChatTemplate([('user', 'Hi')]),
          const LlmGenParams(nPredict: 16),
        ),
      );
      llm.destroy();
    }
    final delta = native.processMemory.$1 - base;
    debugPrint('VV_LLM_UNLOAD base=${base >> 20}MiB delta=${delta >> 20}MiB');
    expect(delta, lessThan(50 * 1024 * 1024));
  }, timeout: const Timeout(Duration(minutes: 10)));
}
