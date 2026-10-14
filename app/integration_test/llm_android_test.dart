import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vaultvoice/core/platform/backend_policy.dart';
import 'package:vaultvoice/core/platform/gpu_trial_file.dart';
import 'package:vaultvoice/features/extraction/data/native_device_capabilities.dart';
import 'package:vv_native/vv_native.dart';

import 'llm_bench_support.dart';

/// LLM-03 device runs (Android arm64). Rows and commands:
/// docs/test-plans/device/LLM-03.md. Skips without a model on the device.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const minDecode = int.fromEnvironment('VV_LLM_MIN_DECODE_TPS');

  testWidgets('[LLM-03/AC1] 3B Q4 decode speed on the CPU backend', (
    tester,
  ) async {
    final caps = NativeDeviceCapabilities(VvNative.open());
    expect(caps.cpuSupported(), isTrue, reason: 'build needs CPU features');
    debugPrint(
      'VV_LLM_CPU perf_cores=${caps.perfCores()} '
      'features=${VvNative.open().cpuFeatures}',
    );
    final c = BenchConfig.fromEnvironment();
    final path = await resolveBenchModel(c.model);
    if (path == null) {
      markTestSkipped('VV_LLM_BENCH_MODEL not on device');
      return;
    }
    final results = await runBench(path, c);
    expect(results.every((r) => r.nThreads == caps.perfCores()), isTrue);
    if (minDecode > 0) {
      expect(
        median(results.map((r) => r.decodeTps)),
        greaterThanOrEqualTo(minDecode),
      );
    }
  }, timeout: const Timeout(Duration(minutes: 30)));

  testWidgets('[LLM-03/AC2] every GPU backend is probed under the crash guard; '
      'failing ones end up disabled, CPU always works', (tester) async {
    final c = BenchConfig.fromEnvironment(prompt: 128, gen: 32);
    final path = await resolveBenchModel(c.model);
    if (path == null) {
      markTestSkipped('VV_LLM_BENCH_MODEL not on device');
      return;
    }
    final docs = await getApplicationDocumentsDirectory();
    // The single shared crash sentinel (ADR-STT-02 / ADR-INT-W2).
    final guard = fileGpuTrialGuard(File('${docs.path}/gpu_trials.json'));
    // A crash in the previous run of this test left a marker: report it.
    final crashed = await guard.crashed();
    debugPrint('VV_LLM_GUARD recovered_from_crash=$crashed');

    final native = VvNative.open();
    for (final backend in const [GpuBackend.vulkan, GpuBackend.opencl]) {
      if (crashed.contains(backend)) {
        debugPrint('VV_LLM_GUARD skip disabled ${backend.name}');
        continue;
      }
      // Durable marker *before* the module is dlopen()ed (DL builds register
      // GPU modules only on request, STT-02 loader) and before GPU init.
      await guard.begin(backend);
      final rc = native.loadBackends(gpuMask: backend.maskBit);
      final devices = NativeDeviceCapabilities(native)
          .gpuDevices()
          .where((d) => d.backend == backend)
          .toList();
      debugPrint(
        'VV_LLM_GUARD ${backend.name} load=$rc devices=${devices.length}',
      );
      var worked = devices.isNotEmpty;
      for (final d in devices) {
        try {
          final r = await Isolate.run(
            () => VvNative.open().llmBench(
              path,
              LlmBackendParams(gpuDevice: d.index, nCtx: 512),
              nPrompt: c.nPrompt,
              nGen: c.nGen,
            ),
          );
          final ok = r.usedGpu && !r.fellBackToCpu;
          worked = worked && ok;
          debugPrint('VV_LLM_GUARD ${backend.name} worked=$ok ${r.toJson()}');
        } on VvLlmException catch (e) {
          worked = false;
          debugPrint('VV_LLM_GUARD ${backend.name} error=${e.code}');
        }
      }
      if (worked) {
        await guard.succeeded(backend);
      } else {
        await guard.failed(backend); // no device, fallback or error: CPU
      }
      expect((await guard.crashed()).contains(backend), !worked);
    }
    // CPU path must always work.
    final cpu = await Isolate.run(
      () => VvNative.open().llmBench(
        path,
        const LlmBackendParams(useGpu: false, nCtx: 512),
        nPrompt: c.nPrompt,
        nGen: c.nGen,
      ),
    );
    expect(cpu.usedGpu, isFalse);
    expect(cpu.nGen, c.nGen);
  }, timeout: const Timeout(Duration(minutes: 20)));
}
