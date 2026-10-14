import 'package:flutter/foundation.dart';
import 'package:vaultvoice/core/platform/backend_policy.dart';
import 'package:vaultvoice/core/platform/device_capabilities.dart';

/// Which llama.cpp backend configuration a run should request from the
/// native bridge (`vv_llm_backend_params` in `native/bridge/vv_llama.h`).
///
/// The bridge still falls back GPU → CPU and q8_0 → f16 KV on its own when
/// initialisation fails; this is the *requested* configuration.
@immutable
final class LlmBackendChoice {
  const LlmBackendChoice({
    required this.useGpu,
    required this.reason,
    this.gpuDevice = -1,
    this.kvQuant = true,
    this.flashAttn = FlashAttn.auto,
  });

  /// Offload all layers (`n_gpu_layers = -1`) to the GPU backend.
  final bool useGpu;

  /// ggml GPU device index, `-1` = llama.cpp default selection.
  final int gpuDevice;

  /// q8_0 K/V cache (halves KV RAM vs f16; needs flash attention).
  final bool kvQuant;

  final FlashAttn flashAttn;

  /// Diagnostics only (never content), e.g. `ios-background-cpu`.
  final String reason;

  @override
  bool operator ==(Object other) =>
      other is LlmBackendChoice &&
      other.useGpu == useGpu &&
      other.gpuDevice == gpuDevice &&
      other.kvQuant == kvQuant &&
      other.flashAttn == flashAttn &&
      other.reason == reason;

  @override
  int get hashCode =>
      Object.hash(useGpu, gpuDevice, kvQuant, flashAttn, reason);

  @override
  String toString() =>
      'LlmBackendChoice(gpu: $useGpu, device: $gpuDevice, kvQuant: $kvQuant, '
      'fa: ${flashAttn.name}, $reason)';
}

/// Mirrors `VV_LLM_FLASH_ATTN_*`.
enum FlashAttn {
  auto(-1),
  off(0),
  on(1);

  FlashAttn(this.native);

  final int native;
}

/// Per-context LLM backend from the **shared** STT/LLM policy
/// ([chooseBackend], ADR-STT-02; unified in ADR-INT-W2 — this replaces
/// LLM-02's `LlmBackendPolicy` and LLM-03's `chooseAndroidBackend`).
///
/// - `null` when the CPU lacks features the native build needs: the engine
///   must refuse to start (no SIGILL, LLM-03).
/// - [userForceCpu], background (hard rule: iOS refuses GPU work from
///   background apps — "Insufficient Permission (to submit GPU work from
///   background)") or no permitted, healthy GPU ⇒ CPU.
/// - Otherwise the first GPU device (registry order) whose backend is built,
///   matches [rules] (deny wins) and is not in [crashedBackends] (the shared
///   [GpuTrialStore] sentinel) is offloaded with `n_gpu_layers = -1`.
LlmBackendChoice? chooseLlmBackend({
  required DeviceCapabilities caps,
  required DevicePlatform platform,
  required bool foreground,
  Set<GpuBackend> crashedBackends = const {},
  bool userForceCpu = false,
  GpuRules rules = kDefaultGpuRules,
}) {
  if (!caps.cpuSupported()) return null;
  final gpus = caps.gpuDevices();
  BackendChoice decide(GpuDevice? d) => chooseBackend(
    BackendPolicyInput(
      platform: platform,
      foreground: foreground,
      builtGpuBackends: {?d?.backend},
      gpu: d?.info,
      crashedBackends: crashedBackends,
      forceCpu: userForceCpu,
    ),
    rules: rules,
  );
  String reason(BackendChoice c) => '${platform.name}-${c.reason}';
  for (final d in gpus) {
    final c = decide(d);
    if (c.useGpu) {
      return LlmBackendChoice(
        useGpu: true,
        gpuDevice: d.index,
        reason: reason(c),
      );
    }
  }
  final cpu = decide(gpus.isEmpty ? null : gpus.first);
  return LlmBackendChoice(useGpu: false, reason: reason(cpu));
}
