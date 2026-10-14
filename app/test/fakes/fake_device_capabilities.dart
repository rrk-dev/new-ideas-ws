import 'package:vaultvoice/core/platform/device_capabilities.dart';

/// Scripted [DeviceCapabilities] for tests.
class FakeDeviceCapabilities implements DeviceCapabilities {
  FakeDeviceCapabilities({
    this.gpus = const [],
    this.cores = 4,
    this.supported = true,
  });

  List<GpuDevice> gpus;
  int cores;
  bool supported;

  @override
  List<GpuDevice> gpuDevices() => gpus;

  @override
  int perfCores() => cores;

  @override
  bool cpuSupported() => supported;
}
