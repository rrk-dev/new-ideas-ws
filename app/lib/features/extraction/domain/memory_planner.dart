import 'package:flutter/foundation.dart';
import 'package:vaultvoice/features/extraction/domain/device_tiering.dart';

/// RAM estimate for loading an LLM (vv-llm-inference → Memory math).
///
/// total ≈ weights + KV cache + compute buffers. KV bytes/token depend on
/// the architecture; before load we only know the file size, so the
/// per-token figure is interpolated from the measured classes:
/// Llama-3.2-1B (16 layers × 8 KV heads × 64) ≈ 32 KiB/token f16,
/// Llama-3.2-3B (28 × 8 × 128) ≈ 112 KiB/token f16; q8_0 ≈ 0.53×.
///
/// Weights are counted in full on every path: on Android / any CPU run the
/// repacked weights live in anonymous memory (LLM-01: 3B Q4_K_M peaks at
/// ≈ 2.3 GiB on CPU), and on iOS the mmap'd pages still need physical RAM.
@immutable
final class LlmMemoryEstimate {
  const LlmMemoryEstimate({
    required this.weightsBytes,
    required this.kvBytes,
    required this.computeBytes,
  });

  factory LlmMemoryEstimate.of({
    required int modelFileBytes,
    required int contextSize,
    bool kvQuant = true,
  }) {
    const kib = 1024;
    final perTokenF16 = modelFileBytes <= 1200 * 1000 * 1000
        ? 32 * kib
        : (112 * kib * (modelFileBytes / 2.0e9)).round();
    final perToken = kvQuant ? (perTokenF16 * 0.53).round() : perTokenF16;
    return LlmMemoryEstimate(
      weightsBytes: modelFileBytes,
      kvBytes: perToken * contextSize,
      computeBytes: modelFileBytes > 1200 * 1000 * 1000
          ? 400 * kib * kib
          : 250 * kib * kib,
    );
  }

  final int weightsBytes;
  final int kvBytes;
  final int computeBytes;

  int get totalBytes => weightsBytes + kvBytes + computeBytes;
}

/// Outcome of [planLlmLoad].
@immutable
final class LoadPlan {
  const LoadPlan._(this.allowed, this.contextSize, this.estimate, this.reason);

  final bool allowed;

  /// Context to load with (may be reduced from the requested one).
  final int contextSize;
  final LlmMemoryEstimate estimate;

  /// `fits`, `reduced-context`, `insufficient-memory` (diagnostics).
  final String reason;
}

/// Headroom rule: require `available ≥ estimate × 1.2` before loading.
const kMemoryHeadroom = 1.2;

/// Smallest context worth loading (shorter transcripts go to map-reduce).
const kMinContext = 2048;

/// Pre-load memory check: keep the requested context if it fits, else halve
/// it down to [kMinContext], else refuse (caller unloads other models /
/// picks a smaller model / uses map-reduce, LLM-06).
LoadPlan planLlmLoad({
  required int modelFileBytes,
  required int availableBytes,
  required int requestedContext,
  bool kvQuant = true,
}) {
  var ctx = requestedContext;
  while (true) {
    final e = LlmMemoryEstimate.of(
      modelFileBytes: modelFileBytes,
      contextSize: ctx,
      kvQuant: kvQuant,
    );
    if (availableBytes >= e.totalBytes * kMemoryHeadroom) {
      return LoadPlan._(
        true,
        ctx,
        e,
        ctx == requestedContext ? 'fits' : 'reduced-context',
      );
    }
    if (ctx <= kMinContext) {
      return LoadPlan._(false, ctx, e, 'insufficient-memory');
    }
    ctx = (ctx ~/ 2).clamp(kMinContext, requestedContext);
  }
}

/// Whether a user-selected model suits the device (model management UI).
enum ModelFit { ok, warn, block }

/// Block when the model's own minimum exceeds the device RAM or the
/// estimate at [kMinContext] needs > 60% of total RAM (the OS, the app and
/// STT-free headroom need the rest); warn above 40%.
ModelFit assessModelFit({
  required int modelFileBytes,
  required int minRamMb,
  required DeviceProfile device,
}) {
  final totalMb = device.totalRamBytes ~/ (1024 * 1024);
  if (minRamMb > totalMb) return ModelFit.block;
  final need = LlmMemoryEstimate.of(
    modelFileBytes: modelFileBytes,
    contextSize: kMinContext,
  ).totalBytes;
  final share = need / device.totalRamBytes;
  if (share > 0.60) return ModelFit.block;
  if (share > 0.40) return ModelFit.warn;
  return ModelFit.ok;
}
