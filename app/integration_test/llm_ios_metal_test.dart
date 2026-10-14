import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'llm_bench_support.dart';

/// LLM-02 device benchmarks (iPhone, Metal). Rows and exact commands:
/// docs/test-plans/device/LLM-02.md. Example:
///   fvm flutter test integration_test/llm_ios_metal_test.dart --flavor dev \
///     -d IPHONE_ID --dart-define=VV_LLM_BENCH_MODEL=Llama-3.2-3B-Instruct-Q4_K_M.gguf \
///     --dart-define=VV_LLM_MIN_DECODE_TPS=15
/// Skips when no model was provided (CI / devices without the file).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const minDecode = int.fromEnvironment('VV_LLM_MIN_DECODE_TPS');

  testWidgets('[LLM-02/AC1] 3B Q4_K_M decode speed with full Metal offload', (
    tester,
  ) async {
    final c = BenchConfig.fromEnvironment();
    final path = await resolveBenchModel(c.model);
    if (path == null) {
      markTestSkipped('VV_LLM_BENCH_MODEL not on device');
      return;
    }
    final results = await runBench(path, c);
    expect(results, hasLength(c.runs));
    if (Platform.isIOS && c.gpu) {
      // Full offload actually ran on Metal (no silent CPU fallback).
      expect(results.every((r) => r.usedGpu), isTrue);
    }
    if (minDecode > 0) {
      expect(
        median(results.map((r) => r.decodeTps)),
        greaterThanOrEqualTo(minDecode),
      );
    }
  }, timeout: const Timeout(Duration(minutes: 30)));

  testWidgets('[LLM-02/AC2] 4k-token prompt + 1k-token generation completes '
      '(no jetsam kill)', (tester) async {
    final c = BenchConfig.fromEnvironment(prompt: 4096, gen: 1024);
    final path = await resolveBenchModel(c.model);
    if (path == null) {
      markTestSkipped('VV_LLM_BENCH_MODEL not on device');
      return;
    }
    // Being killed by jetsam ends the process: the test never reports.
    final r = (await runBench(
      path,
      BenchConfig(
        model: c.model,
        gpu: c.gpu,
        kvQuant: c.kvQuant,
        nPrompt: c.nPrompt,
        nGen: c.nGen,
        nCtx: c.nCtx,
        runs: 1,
        threads: c.threads,
      ),
    )).single;
    expect(r.nPrompt, c.nPrompt);
    expect(r.nGen, c.nGen);
    expect(r.peakMemBytes, greaterThan(0));
  }, timeout: const Timeout(Duration(minutes: 60)));
}
