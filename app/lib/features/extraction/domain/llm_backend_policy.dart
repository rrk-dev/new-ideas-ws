import 'package:flutter/foundation.dart';

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

/// Platform the LLM runs on (kept separate from `dart:io` for testability).
enum LlmPlatform { ios, android, host }

/// Chooses the backend for an LLM run (LLM-02 iOS, LLM-03 Android).
///
/// iOS: Metal with full offload while the app is in the foreground; **CPU
/// only in the background** — iOS refuses GPU command submission from
/// background apps ("Insufficient Permission (to submit GPU work from
/// background)"), so a background job must never attach Metal.
///
/// Android: GPU only when the device's GPU is allowlisted (LLM-03,
/// `gpuAllowed`); otherwise CPU.
final class LlmBackendPolicy {
  const LlmBackendPolicy();

  LlmBackendChoice choose({
    required LlmPlatform platform,
    required bool foreground,
    bool gpuAllowed = true,
    int gpuDevice = -1,
  }) {
    switch (platform) {
      case LlmPlatform.ios:
        if (!foreground) {
          return const LlmBackendChoice(
            useGpu: false,
            reason: 'ios-background-cpu',
          );
        }
        return LlmBackendChoice(
          useGpu: gpuAllowed,
          gpuDevice: gpuDevice,
          reason: gpuAllowed ? 'ios-foreground-metal' : 'ios-gpu-disabled',
        );
      case LlmPlatform.android:
        return LlmBackendChoice(
          useGpu: gpuAllowed,
          gpuDevice: gpuAllowed ? gpuDevice : -1,
          reason: gpuAllowed ? 'android-gpu-allowlisted' : 'android-cpu',
        );
      case LlmPlatform.host:
        return LlmBackendChoice(
          useGpu: gpuAllowed,
          gpuDevice: gpuDevice,
          reason: 'host',
        );
    }
  }
}
