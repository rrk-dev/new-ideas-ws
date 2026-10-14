import 'package:flutter/foundation.dart';

/// A ggml GPU device as reported by the native bridge
/// (`vv_llm_gpu_device_info`): backend device name such as `Vulkan0`,
/// `GPUOpenCL` or `MTL0`, and the driver/GPU description such as
/// `Adreno (TM) 750`. Diagnostics/allowlisting only — never content.
@immutable
final class GpuDevice {
  const GpuDevice({
    required this.index,
    required this.name,
    required this.description,
  });

  final int index;
  final String name;
  final String description;

  /// Backend family derived from the ggml device name.
  GpuBackend get backend {
    final n = name.toLowerCase();
    if (n.startsWith('vulkan')) return GpuBackend.vulkan;
    if (n.contains('opencl')) return GpuBackend.opencl;
    if (n.startsWith('mtl') || n.contains('metal')) return GpuBackend.metal;
    return GpuBackend.other;
  }

  /// Stable key for persisted health state (`vulkan:Mali-G715`).
  String get key => '${backend.name}:$description';

  @override
  bool operator ==(Object other) =>
      other is GpuDevice &&
      other.index == index &&
      other.name == name &&
      other.description == description;

  @override
  int get hashCode => Object.hash(index, name, description);

  @override
  String toString() => 'GpuDevice($index, $name, $description)';
}

enum GpuBackend { metal, vulkan, opencl, other }

/// What this device can run (FND-02 engine interface; real implementation
/// over `vv_native`, fakes in tests).
abstract interface class DeviceCapabilities {
  /// GPU devices ggml registered in this build (empty for a CPU-only build).
  List<GpuDevice> gpuDevices();

  /// Performance-core count used for llama.cpp / whisper.cpp threads.
  int perfCores();

  /// False when the native build requires CPU features (e.g. dotprod) this
  /// CPU lacks — engines must refuse to start instead of hitting SIGILL.
  bool cpuSupported();
}
