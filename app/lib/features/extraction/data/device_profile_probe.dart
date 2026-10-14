import 'dart:convert';
import 'dart:io';

import 'package:vaultvoice/core/platform/device_capabilities.dart';
import 'package:vaultvoice/features/extraction/domain/device_tiering.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';
import 'package:vv_native/vv_native.dart';

/// Device capability probe (LLM-07) over the native bridge: RAM
/// (`vv_device_memory`), GPU devices, perf cores, CPU-feature guard, OS
/// version. Thermal state stays [ThermalState.unknown] until the platform
/// source (iOS `ProcessInfo.thermalState`, Android `PowerManager`) is wired.
final class NativeDeviceProfileProbe {
  NativeDeviceProfileProbe(this._native, this._caps);

  final VvNative _native;
  final DeviceCapabilities _caps;

  DeviceProfile probe() {
    final (total, available) = _native.deviceMemory;
    return DeviceProfile(
      platform: Platform.isIOS
          ? 'ios'
          : Platform.isAndroid
          ? 'android'
          : 'host',
      osVersion: Platform.operatingSystemVersion,
      totalRamBytes: total,
      availableRamBytes: available,
      gpus: _caps.gpuDevices(),
      perfCores: _caps.perfCores(),
      cpuSupported: _caps.cpuSupported(),
    );
  }

  /// Fresh available-RAM reading right before a model load.
  int availableRamBytes() => _native.deviceMemory.$2;
}

/// Caches the capability tier in `<appSupport>/vv/device_tier.json` so the
/// UI and catalog filtering do not re-probe on every start. The cache is
/// keyed by total RAM + OS version: an OS update or a restored backup on a
/// different phone re-probes.
final class DeviceTierCache {
  DeviceTierCache(this.file);

  final File file;

  DeviceTier tierFor(DeviceProfile p) {
    final key = '${p.totalRamBytes}|${p.osVersion}';
    try {
      if (file.existsSync()) {
        final m = jsonDecode(file.readAsStringSync());
        if (m is Map && m['key'] == key) {
          final hit = DeviceTier.values.where((t) => t.wire == m['tier']);
          if (hit.isNotEmpty) return hit.first;
        }
      }
    } on FormatException {
      // corrupt cache: re-probe below
    } on FileSystemException {
      // unreadable: re-probe below
    }
    final tier = tierForRam(p.totalRamBytes);
    try {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(jsonEncode({'key': key, 'tier': tier.wire}));
    } on FileSystemException {
      // cache is an optimisation only
    }
    return tier;
  }
}
