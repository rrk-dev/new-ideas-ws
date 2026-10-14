import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:vv_native/src/vv_bindings.g.dart';

/// Requested llama.cpp backend configuration (`vv_llm_backend_params`).
final class LlmBackendParams {
  const LlmBackendParams({
    this.useGpu = true,
    this.gpuDevice = -1,
    this.kvQuant = true,
    this.flashAttn = -1,
    this.nCtx = 4096,
    this.nBatch = 512,
    this.nThreads = 0,
    this.useMmap = true,
  });

  final bool useGpu;
  final int gpuDevice;
  final bool kvQuant;

  /// `VV_LLM_FLASH_ATTN_*`: -1 auto, 0 off, 1 on.
  final int flashAttn;
  final int nCtx;
  final int nBatch;

  /// 0 = performance-core count.
  final int nThreads;
  final bool useMmap;

  void _fill(Pointer<vv_llm_backend_params> p, VvBindings b) {
    p.ref = b.vv_llm_default_backend_params();
    p.ref
      ..use_gpu = useGpu ? 1 : 0
      ..gpu_device = gpuDevice
      ..kv_quant = kvQuant ? 1 : 0
      ..flash_attn = flashAttn
      ..n_ctx = nCtx
      ..n_batch = nBatch
      ..n_threads = nThreads
      ..use_mmap = useMmap ? 1 : 0;
  }
}

/// Result of [runLlmBench]: effective backend after fallbacks + speed/RAM.
final class LlmBenchResult {
  const LlmBenchResult({
    required this.usedGpu,
    required this.usedKvQuant,
    required this.fallbacks,
    required this.nThreads,
    required this.nPrompt,
    required this.nGen,
    required this.loadMs,
    required this.ctxInitMs,
    required this.prefillTps,
    required this.decodeTps,
    required this.modelBytes,
    required this.peakMemBytes,
    required this.outputHash,
  });

  final bool usedGpu;
  final bool usedKvQuant;

  /// `VV_LLM_FALLBACK_*` bits.
  final int fallbacks;
  final int nThreads;
  final int nPrompt;
  final int nGen;
  final double loadMs;
  final double ctxInitMs;
  final double prefillTps;
  final double decodeTps;
  final int modelBytes;
  final int peakMemBytes;
  final int outputHash;

  bool get fellBackToCpu => fallbacks & VV_LLM_FALLBACK_GPU_TO_CPU != 0;

  /// Diagnostics/metrics map (numbers only, no content).
  Map<String, Object> toJson() => {
    'used_gpu': usedGpu,
    'used_kv_quant': usedKvQuant,
    'fallbacks': fallbacks,
    'n_threads': nThreads,
    'n_prompt': nPrompt,
    'n_gen': nGen,
    'load_ms': loadMs,
    'ctx_init_ms': ctxInitMs,
    'prefill_tps': prefillTps,
    'decode_tps': decodeTps,
    'model_bytes': modelBytes,
    'peak_mem_bytes': peakMemBytes,
    'output_hash': outputHash.toUnsigned(64).toRadixString(16),
  };
}

/// Native error from the LLM bridge (`VV_E_*`).
final class VvLlmException implements Exception {
  const VvLlmException(this.code);

  final int code;

  @override
  String toString() => 'VvLlmException($code)';
}

/// GPU devices registered in ggml: `(index, name, description)`.
List<(int, String, String)> listGpuDevices(VvBindings b) {
  final n = b.vv_llm_gpu_device_count();
  return using((arena) {
    final name = arena<Char>(128);
    final desc = arena<Char>(256);
    return [
      for (var i = 0; i < n; i++)
        if (b.vv_llm_gpu_device_info(i, name, 128, desc, 256) == VV_OK)
          (
            i,
            name.cast<Utf8>().toDartString(),
            desc.cast<Utf8>().toDartString(),
          ),
    ];
  });
}

/// Blocking benchmark/probe (`vv_llm_bench`). Heavy: call from a background
/// isolate (`Isolate.run`), never the UI isolate.
LlmBenchResult runLlmBench(
  VvBindings b,
  String modelPath,
  LlmBackendParams params, {
  required int nPrompt,
  required int nGen,
}) {
  return using((arena) {
    final p = arena<vv_llm_backend_params>();
    params._fill(p, b);
    final r = arena<vv_llm_bench_result>();
    r.ref.struct_size = sizeOf<vv_llm_bench_result>();
    final rc = b.vv_llm_bench(
      modelPath.toNativeUtf8(allocator: arena).cast(),
      p,
      nPrompt,
      nGen,
      r,
    );
    if (rc != VV_OK) throw VvLlmException(rc);
    final o = r.ref;
    return LlmBenchResult(
      usedGpu: o.used_gpu != 0,
      usedKvQuant: o.used_kv_quant != 0,
      fallbacks: o.fallbacks,
      nThreads: o.n_threads,
      nPrompt: o.n_prompt,
      nGen: o.n_gen,
      loadMs: o.load_ms,
      ctxInitMs: o.ctx_init_ms,
      prefillTps: o.prefill_tps,
      decodeTps: o.decode_tps,
      modelBytes: o.model_bytes,
      peakMemBytes: o.peak_mem_bytes,
      outputHash: o.output_hash,
    );
  });
}
