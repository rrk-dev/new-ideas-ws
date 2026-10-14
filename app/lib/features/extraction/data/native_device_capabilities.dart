import 'package:vaultvoice/core/platform/device_capabilities.dart';
import 'package:vv_native/vv_native.dart';

/// [DeviceCapabilities] over the native bridge (LLM-03, unified in
/// integration wave 2). GPU devices come from `vv_backends_describe` — the
/// same registry STT-02's backend loader fills — so STT and LLM see one
/// device list. Cheap calls: no model load.
final class NativeDeviceCapabilities implements DeviceCapabilities {
  NativeDeviceCapabilities(this._native);

  final VvNative _native;

  @override
  List<GpuDevice> gpuDevices() =>
      gpuDevicesFromDescribe(_native.describeBackends());

  @override
  int perfCores() => _native.perfCores;

  @override
  bool cpuSupported() => _native.cpuSupported;
}
