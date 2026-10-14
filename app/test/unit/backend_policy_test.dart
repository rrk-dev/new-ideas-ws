import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/platform/backend_policy.dart';

const _adreno = GpuInfo(renderer: 'Adreno (TM) 740', driver: '0676.42');
const _mali = GpuInfo(renderer: 'Mali-G715', driver: 'r38p1');

final _rules = GpuRules(
  allow: [
    GpuRule(
      backend: GpuBackend.opencl,
      renderer: RegExp(r'^Adreno \(TM\) 7\d\d$'),
      reason: 'bench',
    ),
    const GpuRule(
      backend: GpuBackend.vulkan,
      renderer: 'Adreno',
      reason: 'bench',
    ),
    const GpuRule(backend: GpuBackend.vulkan, renderer: 'Mali', reason: 't'),
  ],
  deny: [
    const GpuRule(
      backend: GpuBackend.vulkan,
      renderer: 'Mali-G715',
      driver: 'r38',
      reason: 'driver crash',
    ),
  ],
);

BackendPolicyInput _android({
  GpuInfo? gpu = _adreno,
  bool foreground = true,
  Set<GpuBackend> built = const {GpuBackend.vulkan, GpuBackend.opencl},
  Set<GpuBackend> crashed = const {},
  bool forceCpu = false,
}) => BackendPolicyInput(
  platform: DevicePlatform.android,
  foreground: foreground,
  builtGpuBackends: built,
  gpu: gpu,
  crashedBackends: crashed,
  forceCpu: forceCpu,
);

void main() {
  group('[STT-02/AC2] backend auto-selection with safe CPU fallback', () {
    test('allowed Adreno prefers OpenCL, then Vulkan', () {
      final c = chooseBackend(_android(), rules: _rules);
      expect(c.gpu, GpuBackend.opencl);
      expect(c.gpuMask, GpuBackend.opencl.maskBit);
      final noCl = chooseBackend(
        _android(built: const {GpuBackend.vulkan}),
        rules: _rules,
      );
      expect(noCl.gpu, GpuBackend.vulkan);
    });

    test('denylisted Mali driver falls back to CPU (no GPU module loaded)', () {
      final c = chooseBackend(_android(gpu: _mali), rules: _rules);
      expect(c.useGpu, isFalse);
      expect(c.gpuMask, 0);
      // A newer, not denylisted driver is allowed again.
      final fixed = chooseBackend(
        _android(
          gpu: const GpuInfo(renderer: 'Mali-G715', driver: 'r44p0'),
        ),
        rules: _rules,
      );
      expect(fixed.gpu, GpuBackend.vulkan);
    });

    test('shipped rules keep every Android GPU on CPU until benchmarked', () {
      for (final gpu in [_adreno, _mali]) {
        final c = chooseBackend(_android(gpu: gpu));
        expect(c.useGpu, isFalse, reason: gpu.renderer);
        expect(c.gpuMask, 0);
      }
    });

    test('background, unknown GPU, force-CPU and missing module → CPU', () {
      expect(
        chooseBackend(_android(foreground: false), rules: _rules).reason,
        'background',
      );
      expect(chooseBackend(_android(gpu: null), rules: _rules).useGpu, false);
      expect(chooseBackend(_android(forceCpu: true), rules: _rules).gpu, null);
      expect(chooseBackend(_android(built: const {}), rules: _rules).gpu, null);
    });

    test('a backend that crashed a previous run is skipped', () {
      final c = chooseBackend(
        _android(crashed: const {GpuBackend.opencl}),
        rules: _rules,
      );
      expect(c.gpu, GpuBackend.vulkan);
      final none = chooseBackend(
        _android(crashed: const {GpuBackend.opencl, GpuBackend.vulkan}),
        rules: _rules,
      );
      expect(none.useGpu, isFalse);
      expect(none.reason, 'gpu crashed in a previous run');
    });

    test('iOS uses Metal in foreground only', () {
      const fg = BackendPolicyInput(
        platform: DevicePlatform.ios,
        foreground: true,
        builtGpuBackends: {GpuBackend.metal},
        gpu: GpuInfo(renderer: 'Apple A15 GPU'),
      );
      expect(chooseBackend(fg).gpu, GpuBackend.metal);
      const bg = BackendPolicyInput(
        platform: DevicePlatform.ios,
        foreground: false,
        builtGpuBackends: {GpuBackend.metal},
        gpu: GpuInfo(renderer: 'Apple A15 GPU'),
      );
      expect(chooseBackend(bg).useGpu, isFalse);
    });

    test(
      'trial guard: an unfinished GPU trial marks the backend crashed',
      () async {
        final kv = <String, String>{};
        GpuTrialGuard guard() => GpuTrialGuard(
          read: (k) async => kv[k],
          write: (k, v) async => v == null ? kv.remove(k) : kv[k] = v,
        );
        // Run 1: trial starts, process dies before succeeded().
        await guard().begin(GpuBackend.vulkan);
        // Run 2: startup sees the dangling trial.
        final crashed = await guard().crashed();
        expect(crashed, {GpuBackend.vulkan});
        expect(
          chooseBackend(
            _android(built: const {GpuBackend.vulkan}, crashed: crashed),
            rules: _rules,
          ).useGpu,
          isFalse,
        );
        // Stays disabled on later launches.
        expect(await guard().crashed(), {GpuBackend.vulkan});
        // A backend that completed its trial is never flagged.
        await guard().begin(GpuBackend.opencl);
        await guard().succeeded(GpuBackend.opencl);
        await guard().begin(GpuBackend.opencl);
        expect(await guard().crashed(), {GpuBackend.vulkan});
      },
    );
  });

  test('default thread count = perf cores capped at 4, never < 1', () {
    expect(defaultThreads(5), 4);
    expect(defaultThreads(2), 2);
    expect(defaultThreads(0), 1);
    expect(defaultThreads(6, cap: 6), 6);
  });

  test('mask bits match VV_GPU_* in vv_bridge.h', () {
    expect(GpuBackend.metal.maskBit, 0x1);
    expect(GpuBackend.vulkan.maskBit, 0x2);
    expect(GpuBackend.opencl.maskBit, 0x4);
  });
}
