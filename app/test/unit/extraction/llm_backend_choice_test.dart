import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/platform/backend_policy.dart';
import 'package:vaultvoice/core/platform/device_capabilities.dart';
import 'package:vaultvoice/core/platform/gpu_trial_file.dart';
import 'package:vaultvoice/features/extraction/domain/llm_backend_policy.dart';

import '../../fakes/fake_device_capabilities.dart';

// LLM backend choice on top of the single shared STT/LLM policy
// (integration wave 2, ADR-INT-W2). Replaces LLM-02's llm_backend_policy_test
// and LLM-03's gpu_backend_guard_test; the [LLM-03/AC2] tags moved here.

const _adreno = GpuDevice(
  index: 0,
  name: 'GPUOpenCL',
  description: 'QUALCOMM Adreno(TM) 750',
);
const _mali = GpuDevice(index: 1, name: 'Vulkan0', description: 'Mali-G715');
const _metal = GpuDevice(index: 0, name: 'MTL0', description: 'Apple A17 Pro');

/// Test-only rule: Adreno 7xx over OpenCL.
const _rules = GpuRules(
  allow: [
    GpuRule(
      backend: GpuBackend.opencl,
      renderer: 'Adreno',
      reason: 'test-only',
    ),
  ],
);

GpuTrialGuard _memoryGuard(Map<String, String> m) => GpuTrialGuard(
  read: (k) async => m[k],
  write: (k, v) async => v == null ? m.remove(k) : m[k] = v,
);

void main() {
  group('GpuDevice', () {
    test('backend family from ggml device names', () {
      expect(_adreno.backend, GpuBackend.opencl);
      expect(_mali.backend, GpuBackend.vulkan);
      expect(_metal.backend, GpuBackend.metal);
      expect(
        const GpuDevice(index: 0, name: 'BLAS', description: 'x').backend,
        isNull,
      );
      expect(_mali.info.renderer, 'Mali-G715');
    });

    test('devices come from vv_backends_describe (gpu + igpu only)', () {
      final d = gpuDevicesFromDescribe(const [
        {'name': 'CPU', 'type': 'cpu', 'description': 'Apple M3'},
        {'name': 'MTL0', 'type': 'gpu', 'description': 'Apple M3 GPU'},
        {'name': 'Vulkan0', 'type': 'igpu', 'description': 'Mali-G715'},
      ]);
      expect(d, const [
        GpuDevice(index: 0, name: 'MTL0', description: 'Apple M3 GPU'),
        GpuDevice(index: 1, name: 'Vulkan0', description: 'Mali-G715'),
      ]);
    });
  });

  group('iOS (LLM-02)', () {
    final caps = FakeDeviceCapabilities(gpus: [_metal]);

    test('foreground uses Metal with full offload and q8_0 KV', () {
      final c = chooseLlmBackend(
        caps: caps,
        platform: DevicePlatform.ios,
        foreground: true,
      )!;
      expect(c.useGpu, isTrue);
      expect(c.gpuDevice, 0);
      expect(c.kvQuant, isTrue);
      expect(c.flashAttn, FlashAttn.auto);
    });

    test('background never attaches the GPU (hard rule)', () {
      final c = chooseLlmBackend(
        caps: caps,
        platform: DevicePlatform.ios,
        foreground: false,
      )!;
      expect(c.useGpu, isFalse);
      expect(c.gpuDevice, -1);
      expect(c.reason, 'ios-background');
    });

    test('user "CPU only" wins in the foreground', () {
      final c = chooseLlmBackend(
        caps: caps,
        platform: DevicePlatform.ios,
        foreground: true,
        userForceCpu: true,
      )!;
      expect(c.useGpu, isFalse);
    });
  });

  group('Android (LLM-03)', () {
    test('[LLM-03/AC2] unsupported CPU (missing dotprod) refuses to start', () {
      final choice = chooseLlmBackend(
        caps: FakeDeviceCapabilities(supported: false),
        platform: DevicePlatform.android,
        foreground: true,
      );
      expect(choice, isNull);
    });

    test('shipped rules: CPU even when a GPU is present', () {
      expect(kDefaultGpuRules.permits(GpuBackend.opencl, _adreno.info), false);
      final choice = chooseLlmBackend(
        caps: FakeDeviceCapabilities(gpus: [_adreno, _mali]),
        platform: DevicePlatform.android,
        foreground: true,
      )!;
      expect(choice.useGpu, isFalse);
    });

    test('allowed GPU is chosen by device index; same GPU via another '
        'backend is not', () {
      final on = chooseLlmBackend(
        caps: FakeDeviceCapabilities(gpus: [_mali, _adreno]),
        platform: DevicePlatform.android,
        foreground: true,
        rules: _rules,
      )!;
      expect(on.useGpu, isTrue);
      expect(on.gpuDevice, _adreno.index);
      final vulkanAdreno = chooseLlmBackend(
        caps: FakeDeviceCapabilities(
          gpus: const [
            GpuDevice(index: 0, name: 'Vulkan0', description: 'Adreno 750'),
          ],
        ),
        platform: DevicePlatform.android,
        foreground: true,
        rules: _rules,
      )!;
      expect(vulkanAdreno.useGpu, isFalse);
    });

    test('[LLM-03/AC2] a crash during a GPU run disables that backend on '
        'next start', () async {
      final persisted = <String, String>{};
      final caps = FakeDeviceCapabilities(gpus: [_adreno]);
      final guard = _memoryGuard(persisted);
      expect(await guard.crashed(), isEmpty);
      await guard.begin(GpuBackend.opencl);
      // Process dies here (driver crash) — next launch:
      final crashed = await _memoryGuard(persisted).crashed();
      expect(crashed, {GpuBackend.opencl});
      final c = chooseLlmBackend(
        caps: caps,
        platform: DevicePlatform.android,
        foreground: true,
        rules: _rules,
        crashedBackends: crashed,
      )!;
      expect(c.useGpu, isFalse);
      expect(c.reason, 'android-gpu crashed in a previous run');
      // Stays disabled on every later start.
      expect(await _memoryGuard(persisted).crashed(), {GpuBackend.opencl});
    });

    test(
      '[LLM-03/AC2] a bridge GPU->CPU fallback disables the backend',
      () async {
        final persisted = <String, String>{};
        final guard = _memoryGuard(persisted);
        await guard.begin(GpuBackend.opencl);
        await guard.failed(GpuBackend.opencl);
        expect(await guard.crashed(), {GpuBackend.opencl});
      },
    );

    test('a successful run keeps the backend; resetAll re-enables', () async {
      final persisted = <String, String>{};
      final guard = _memoryGuard(persisted);
      await guard.begin(GpuBackend.opencl);
      await guard.succeeded(GpuBackend.opencl);
      expect(await guard.crashed(), isEmpty);
      await guard.failed(GpuBackend.vulkan);
      await guard.resetAll();
      expect(await guard.crashed(), isEmpty);
    });
  });

  group('fileGpuTrialGuard', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('vv_trial'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('[LLM-03/AC2] running marker survives a new instance (process '
        'restart)', () async {
      final file = File('${dir.path}/vv/gpu_trials.json');
      await fileGpuTrialGuard(file).begin(GpuBackend.vulkan);
      expect(await fileGpuTrialGuard(file).crashed(), {GpuBackend.vulkan});
      expect(await fileGpuTrialGuard(file).crashed(), {GpuBackend.vulkan});
    });

    test('corrupt file is treated as empty', () async {
      final file = File('${dir.path}/t.json')..writeAsStringSync('{not json');
      final guard = fileGpuTrialGuard(file);
      expect(await guard.crashed(), isEmpty);
      await guard.begin(GpuBackend.opencl);
      expect(await fileGpuTrialGuard(file).crashed(), {GpuBackend.opencl});
    });
  });

  test('FlashAttn mirrors VV_LLM_FLASH_ATTN_* values', () {
    expect(FlashAttn.auto.native, -1);
    expect(FlashAttn.off.native, 0);
    expect(FlashAttn.on.native, 1);
  });
}
