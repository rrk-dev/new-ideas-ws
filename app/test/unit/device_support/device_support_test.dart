import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/platform/device_capabilities.dart';
import 'package:vaultvoice/features/device_support/domain/device_support.dart';

import '../../fakes/fake_device_capabilities.dart';

class _Throwing implements DeviceCapabilities {
  @override
  bool cpuSupported() => throw StateError('symbol missing');

  @override
  List<GpuDevice> gpuDevices() => const [];

  @override
  int perfCores() => 1;
}

// Product owner decision 2026-10-14: ARMv8.2-A + dotprod minimum, no
// Cortex-A53/A35 (the bridge folds the minimum into vv_cpu_supported()).
void main() {
  test('a CPU below the minimum (mocked A53: no dotprod) is unsupported', () {
    expect(isDeviceSupported(FakeDeviceCapabilities(supported: false)), false);
  });

  test('a CPU meeting the minimum is supported', () {
    expect(isDeviceSupported(FakeDeviceCapabilities()), true);
  });

  test('fails open when the bridge cannot answer', () {
    expect(isDeviceSupported(null), true);
    expect(isDeviceSupported(_Throwing()), true);
  });
}
