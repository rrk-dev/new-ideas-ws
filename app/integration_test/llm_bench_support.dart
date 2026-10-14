import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vv_native/vv_native.dart';

/// Shared on-device LLM benchmark runner for the LLM-02 / LLM-03 device rows
/// (docs/test-plans/device/LLM-02.md, LLM-03.md). Configured with
/// `--dart-define`s so one test binary covers every row:
///
/// - `VV_LLM_BENCH_MODEL`: absolute path, or a file name inside the app's
///   Documents directory (copy it there with Xcode → Devices → Download/
///   Replace Container, or `adb push` + `run-as`). Models are never bundled.
/// - `VV_LLM_BENCH_GPU` (1), `VV_LLM_BENCH_KVQ` (1), `VV_LLM_BENCH_PROMPT`
///   (2048), `VV_LLM_BENCH_GEN` (256), `VV_LLM_BENCH_CTX` (prompt+gen+64),
///   `VV_LLM_BENCH_RUNS` (3), `VV_LLM_BENCH_THREADS` (0 = perf cores).
final class BenchConfig {
  const BenchConfig({
    required this.model,
    required this.gpu,
    required this.kvQuant,
    required this.nPrompt,
    required this.nGen,
    required this.nCtx,
    required this.runs,
    required this.threads,
  });

  factory BenchConfig.fromEnvironment({int prompt = 2048, int gen = 256}) {
    const p = int.fromEnvironment('VV_LLM_BENCH_PROMPT');
    const g = int.fromEnvironment('VV_LLM_BENCH_GEN');
    final nPrompt = p > 0 ? p : prompt;
    final nGen = g > 0 ? g : gen;
    const c = int.fromEnvironment('VV_LLM_BENCH_CTX');
    const r = int.fromEnvironment('VV_LLM_BENCH_RUNS');
    return BenchConfig(
      model: const String.fromEnvironment('VV_LLM_BENCH_MODEL'),
      gpu: const int.fromEnvironment('VV_LLM_BENCH_GPU', defaultValue: 1) != 0,
      kvQuant:
          const int.fromEnvironment('VV_LLM_BENCH_KVQ', defaultValue: 1) != 0,
      nPrompt: nPrompt,
      nGen: nGen,
      nCtx: c > 0 ? c : nPrompt + nGen + 64,
      runs: r > 0 ? r : 3,
      threads: const int.fromEnvironment('VV_LLM_BENCH_THREADS'),
    );
  }

  final String model;
  final bool gpu;
  final bool kvQuant;
  final int nPrompt;
  final int nGen;
  final int nCtx;
  final int runs;
  final int threads;
}

Future<String?> resolveBenchModel(String model) async {
  if (model.isEmpty) return null;
  if (model.startsWith('/')) return File(model).existsSync() ? model : null;
  final docs = await getApplicationDocumentsDirectory();
  final f = File('${docs.path}/$model');
  return f.existsSync() ? f.path : null;
}

/// Runs [BenchConfig.runs] benchmarks on a background isolate and prints one
/// `VV_LLM_BENCH {json}` line per run plus the median (copy into the device
/// row / ADR). Returns all results.
Future<List<LlmBenchResult>> runBench(String path, BenchConfig c) async {
  final results = <LlmBenchResult>[];
  for (var i = 0; i < c.runs; i++) {
    final r = await Isolate.run(
      () => VvNative.open().llmBench(
        path,
        LlmBackendParams(
          useGpu: c.gpu,
          kvQuant: c.kvQuant,
          nCtx: c.nCtx,
          nThreads: c.threads,
        ),
        nPrompt: c.nPrompt,
        nGen: c.nGen,
      ),
    );
    results.add(r);
    debugPrint('VV_LLM_BENCH ${jsonEncode({'run': i, ...r.toJson()})}');
  }
  final summary = {
    'model': path.split('/').last,
    'gpu_devices': VvNative.open().gpuDevices().map((d) => d.$3).toList(),
    'prefill_tps': median(results.map((r) => r.prefillTps)),
    'decode_tps': median(results.map((r) => r.decodeTps)),
    'load_ms': median(results.map((r) => r.loadMs)),
    'peak_mem_mib': results
        .map((r) => r.peakMemBytes >> 20)
        .reduce((a, b) => a > b ? a : b),
  };
  debugPrint('VV_LLM_BENCH_MEDIAN ${jsonEncode(summary)}');
  return results;
}

double median(Iterable<double> v) {
  final s = v.toList()..sort();
  if (s.isEmpty) return 0;
  final m = s.length ~/ 2;
  return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
}
