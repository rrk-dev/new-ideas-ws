import 'package:flutter/foundation.dart';
import 'package:vaultvoice/core/platform/backend_policy.dart';

/// A ggml GPU device as reported by the native bridge
/// (`vv_backends_describe`, entries of type `gpu`/`igpu`): backend device name
/// such as `Vulkan0`, `GPUOpenCL` or `MTL0`, and the driver/GPU description
/// such as `Adreno (TM) 750`. [index] is the position among the GPU devices
/// (the `gpu_device` index the LLM bridge takes). Diagnostics/policy only —
/// never content.
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

  /// Backend family derived from the ggml device name; null for a family
  /// the shared backend policy does not know (always runs on CPU).
  GpuBackend? get backend {
    final n = name.toLowerCase();
    if (n.startsWith('vulkan')) return GpuBackend.vulkan;
    if (n.contains('opencl')) return GpuBackend.opencl;
    if (n.startsWith('mtl') || n.contains('metal')) return GpuBackend.metal;
    return null;
  }

  /// Identity for the shared allow/deny rules ([GpuRules]).
  GpuInfo get info => GpuInfo(renderer: description);

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

/// GPU devices from the `vv_backends_describe` JSON (`[{name, type,
/// description}]`): `gpu` and `igpu` entries in registry order.
List<GpuDevice> gpuDevicesFromDescribe(List<Map<String, Object?>> devices) {
  final out = <GpuDevice>[];
  for (final d in devices) {
    final type = d['type'];
    if (type != 'gpu' && type != 'igpu') continue;
    out.add(
      GpuDevice(
        index: out.length,
        name: '${d['name'] ?? ''}',
        description: '${d['description'] ?? ''}',
      ),
    );
  }
  return out;
}

/// What this device can run (FND-02 engine interface; real implementation
/// over `vv_native`, fakes in tests). Shared by STT and LLM backend choice
/// (ADR-INT-W2).
abstract interface class DeviceCapabilities {
  /// GPU devices ggml registered in this build (empty for a CPU-only build).
  List<GpuDevice> gpuDevices();

  /// Performance-core count used for llama.cpp / whisper.cpp threads.
  int perfCores();

  /// False when the native build requires CPU features (e.g. dotprod) this
  /// CPU lacks — engines must refuse to start instead of hitting SIGILL.
  bool cpuSupported();
}
