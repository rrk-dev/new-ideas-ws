import 'package:vaultvoice/core/platform/device_capabilities.dart';
import 'package:vv_native/vv_native.dart';

/// [DeviceCapabilities] over the native bridge (LLM-03). Cheap calls: they
/// only query ggml's device registry / CPU feature bits, no model load.
final class NativeDeviceCapabilities implements DeviceCapabilities {
  NativeDeviceCapabilities(this._native);

  final VvNative _native;

  @override
  List<GpuDevice> gpuDevices() => [
    for (final (i, name, desc) in _native.gpuDevices())
      GpuDevice(index: i, name: name, description: desc),
  ];

  @override
  int perfCores() => _native.perfCores;

  @override
  bool cpuSupported() => _native.cpuSupported;
}
