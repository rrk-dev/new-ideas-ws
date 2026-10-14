import 'package:flutter/foundation.dart';
import 'package:vaultvoice/core/platform/device_capabilities.dart';
import 'package:vaultvoice/features/extraction/domain/llm_backend_policy.dart';

/// Android backend choice for one LLM run (LLM-03): `null` when the CPU
/// lacks features the native build needs (refuse to start — no SIGILL);
/// otherwise the first allowlisted, healthy GPU or the CPU backend.
LlmBackendChoice? chooseAndroidBackend({
  required DeviceCapabilities caps,
  required GpuBackendGuard guard,
  required bool foreground,
  GpuAllowlist allowlist = kAndroidGpuAllowlist,
  LlmBackendPolicy policy = const LlmBackendPolicy(),
}) {
  if (!caps.cpuSupported()) return null;
  final gpu = guard.select(caps.gpuDevices(), allowlist);
  return policy.choose(
    platform: LlmPlatform.android,
    foreground: foreground,
    gpuAllowed: gpu != null,
    gpuDevice: gpu?.index ?? -1,
  );
}

/// One allowlist entry: a GPU backend + a pattern on the driver/GPU
/// description reported by ggml (ADR-LLM-03).
@immutable
final class GpuAllowRule {
  const GpuAllowRule({
    required this.backend,
    required this.descriptionPattern,
    required this.evidence,
  });

  final GpuBackend backend;

  /// Case-insensitive regular expression on [GpuDevice.description].
  final String descriptionPattern;

  /// Device-checklist row that proved this entry (no entry without one).
  final String evidence;

  bool matches(GpuDevice d) =>
      d.backend == backend &&
      RegExp(descriptionPattern, caseSensitive: false).hasMatch(d.description);
}

/// Which GPU devices may run the LLM. Anything not matched runs on CPU.
@immutable
final class GpuAllowlist {
  const GpuAllowlist(this.rules);

  final List<GpuAllowRule> rules;

  bool allows(GpuDevice d) => rules.any((r) => r.matches(d));
}

/// Android GPU allowlist. **Empty until the LLM-03 device rows prove a GPU
/// backend faster than CPU and crash-free** (docs/test-plans/device/LLM-03.md):
/// every Android device runs the CPU backend by default. Metal (iOS) is not
/// gated by this list.
const kAndroidGpuAllowlist = GpuAllowlist([]);

/// Persistence for [GpuBackendGuard]. Must be durable *before* the native
/// GPU init starts (a crash there must leave the marker behind).
abstract interface class BackendHealthStore {
  Set<String> readDisabled();
  void writeDisabled(Set<String> keys);
  String? readPending();
  void writePending(String? key);
}

/// Auto-disables GPU backends that crash or fail (LLM-03 AC2).
///
/// Protocol per run: [beginGpuRun] writes a pending marker → native GPU
/// init + inference → [endGpuRun] clears it. A process that dies in between
/// (driver crash, SIGSEGV in a shader compiler, watchdog kill) leaves the
/// marker; [recoverFromCrash] at the next start turns it into a permanent
/// local denylist entry. A run whose bridge reports a GPU→CPU fallback is
/// denylisted the same way.
final class GpuBackendGuard {
  GpuBackendGuard(this._store);

  final BackendHealthStore _store;

  /// Call once at app start, before any LLM run. Returns the key that was
  /// disabled because of a crash, if any.
  String? recoverFromCrash() {
    final pending = _store.readPending();
    if (pending == null) return null;
    _store
      ..writeDisabled({..._store.readDisabled(), pending})
      ..writePending(null);
    return pending;
  }

  bool isDisabled(GpuDevice d) => _store.readDisabled().contains(d.key);

  /// First allowlisted, not-disabled device, or `null` (= run on CPU).
  GpuDevice? select(List<GpuDevice> devices, GpuAllowlist allowlist) {
    for (final d in devices) {
      if (allowlist.allows(d) && !isDisabled(d)) return d;
    }
    return null;
  }

  void beginGpuRun(GpuDevice d) => _store.writePending(d.key);

  /// [gpuWorked] = false when the bridge fell back to CPU
  /// (`VV_LLM_FALLBACK_GPU_TO_CPU`) or the GPU run returned a backend error.
  void endGpuRun(GpuDevice d, {required bool gpuWorked}) {
    if (!gpuWorked) _store.writeDisabled({..._store.readDisabled(), d.key});
    _store.writePending(null);
  }

  /// User/diagnostics reset (e.g. after an OS/driver update).
  void resetAll() {
    _store
      ..writeDisabled(<String>{})
      ..writePending(null);
  }
}

/// In-memory store for tests and host tools.
final class MemoryBackendHealthStore implements BackendHealthStore {
  final Set<String> _disabled = {};
  String? _pending;

  @override
  Set<String> readDisabled() => {..._disabled};

  @override
  void writeDisabled(Set<String> keys) => _disabled
    ..clear()
    ..addAll(keys);

  @override
  String? readPending() => _pending;

  @override
  void writePending(String? key) => _pending = key;
}
