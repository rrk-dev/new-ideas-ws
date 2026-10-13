import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/platform/device_capabilities.dart';
import 'package:vaultvoice/features/extraction/data/file_backend_health_store.dart';
import 'package:vaultvoice/features/extraction/domain/gpu_backend_guard.dart';
import 'package:vaultvoice/features/extraction/domain/llm_backend_policy.dart';

import '../../fakes/fake_device_capabilities.dart';

const _adreno = GpuDevice(
  index: 0,
  name: 'GPUOpenCL',
  description: 'QUALCOMM Adreno(TM) 750',
);
const _mali = GpuDevice(index: 1, name: 'Vulkan0', description: 'Mali-G715');

const _list = GpuAllowlist([
  GpuAllowRule(
    backend: GpuBackend.opencl,
    descriptionPattern: r'adreno\s*\(tm\)\s*7\d\d',
    evidence: 'test-only',
  ),
]);

void main() {
  group('GpuDevice', () {
    test('backend family from ggml device names', () {
      expect(_adreno.backend, GpuBackend.opencl);
      expect(_mali.backend, GpuBackend.vulkan);
      expect(
        const GpuDevice(
          index: 0,
          name: 'MTL0',
          description: 'Apple A17 Pro',
        ).backend,
        GpuBackend.metal,
      );
      expect(_mali.key, 'vulkan:Mali-G715');
    });
  });

  group('GpuAllowlist', () {
    test('matches backend and description pattern', () {
      expect(_list.allows(_adreno), isTrue);
      expect(_list.allows(_mali), isFalse);
      // Same GPU through another backend is not allowlisted.
      expect(
        _list.allows(
          const GpuDevice(
            index: 2,
            name: 'Vulkan0',
            description: 'Adreno (TM) 750',
          ),
        ),
        isFalse,
      );
    });

    test('shipped Android allowlist is empty (CPU until device rows pass)', () {
      expect(kAndroidGpuAllowlist.rules, isEmpty);
      expect(kAndroidGpuAllowlist.allows(_adreno), isFalse);
    });
  });

  group('GpuBackendGuard', () {
    test('[LLM-03/AC2] a crash during a GPU run disables that backend on next start', () {
      final store = MemoryBackendHealthStore();
      final guard = GpuBackendGuard(store);
      expect(guard.select([_adreno, _mali], _list), _adreno);

      guard.beginGpuRun(_adreno);
      // Process dies here (driver crash) — next launch:
      final restarted = GpuBackendGuard(store);
      expect(restarted.recoverFromCrash(), _adreno.key);
      expect(restarted.isDisabled(_adreno), isTrue);
      expect(restarted.select([_adreno, _mali], _list), isNull); // -> CPU
      expect(restarted.recoverFromCrash(), isNull); // marker consumed once

      final choice = const LlmBackendPolicy().choose(
        platform: LlmPlatform.android,
        foreground: true,
        gpuAllowed: restarted.select([_adreno], _list) != null,
      );
      expect(choice.useGpu, isFalse);
    });

    test('[LLM-03/AC2] a bridge GPU->CPU fallback disables the backend', () {
      final guard = GpuBackendGuard(MemoryBackendHealthStore())
        ..beginGpuRun(_adreno)
        ..endGpuRun(_adreno, gpuWorked: false);
      expect(guard.isDisabled(_adreno), isTrue);
      expect(guard.recoverFromCrash(), isNull);
    });

    test('a successful run keeps the backend and clears the marker', () {
      final store = MemoryBackendHealthStore();
      GpuBackendGuard(store)
        ..beginGpuRun(_adreno)
        ..endGpuRun(_adreno, gpuWorked: true);
      expect(store.readPending(), isNull);
      expect(GpuBackendGuard(store).isDisabled(_adreno), isFalse);
    });

    test('resetAll re-enables everything', () {
      final guard = GpuBackendGuard(MemoryBackendHealthStore())
        ..beginGpuRun(_adreno)
        ..endGpuRun(_adreno, gpuWorked: false)
        ..resetAll();
      expect(guard.isDisabled(_adreno), isFalse);
    });
  });

  group('FileBackendHealthStore', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('vv_health'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('[LLM-03/AC2] pending marker survives a new store instance (process restart)', () {
      final file = File('${dir.path}/vv/llm_backend_health.json');
      GpuBackendGuard(FileBackendHealthStore(file)).beginGpuRun(_mali);
      final guard = GpuBackendGuard(FileBackendHealthStore(file));
      expect(guard.recoverFromCrash(), _mali.key);
      expect(
        GpuBackendGuard(FileBackendHealthStore(file)).isDisabled(_mali),
        isTrue,
      );
    });

    test('corrupt file is treated as empty', () {
      final file = File('${dir.path}/h.json')..writeAsStringSync('{not json');
      final store = FileBackendHealthStore(file);
      expect(store.readDisabled(), isEmpty);
      expect(store.readPending(), isNull);
      store.writePending('x');
      expect(FileBackendHealthStore(file).readPending(), 'x');
    });
  });

  test('LLM-03 Android policy: GPU only when allowlisted', () {
    const p = LlmBackendPolicy();
    expect(
      p
          .choose(
            platform: LlmPlatform.android,
            foreground: true,
            gpuAllowed: false,
          )
          .useGpu,
      isFalse,
    );
    final on = p.choose(
      platform: LlmPlatform.android,
      foreground: false,
      gpuDevice: 1,
    );
    expect(on.useGpu, isTrue);
    expect(on.gpuDevice, 1);
  });

  group('chooseAndroidBackend', () {
    test('[LLM-03/AC2] unsupported CPU (missing dotprod) refuses to start', () {
      final choice = chooseAndroidBackend(
        caps: FakeDeviceCapabilities(supported: false),
        guard: GpuBackendGuard(MemoryBackendHealthStore()),
        foreground: true,
      );
      expect(choice, isNull);
    });

    test('shipped allowlist: CPU even when a GPU is present', () {
      final choice = chooseAndroidBackend(
        caps: FakeDeviceCapabilities(gpus: [_adreno, _mali]),
        guard: GpuBackendGuard(MemoryBackendHealthStore()),
        foreground: true,
      )!;
      expect(choice.useGpu, isFalse);
    });

    test('allowlisted healthy GPU is chosen; disabled one is skipped', () {
      final store = MemoryBackendHealthStore();
      final caps = FakeDeviceCapabilities(gpus: [_mali, _adreno]);
      final guard = GpuBackendGuard(store);
      final on = chooseAndroidBackend(
        caps: caps,
        guard: guard,
        foreground: true,
        allowlist: _list,
      )!;
      expect(on.useGpu, isTrue);
      expect(on.gpuDevice, _adreno.index);
      guard
        ..beginGpuRun(_adreno)
        ..endGpuRun(_adreno, gpuWorked: false);
      final off = chooseAndroidBackend(
        caps: caps,
        guard: guard,
        foreground: true,
        allowlist: _list,
      )!;
      expect(off.useGpu, isFalse);
    });
  });
}
