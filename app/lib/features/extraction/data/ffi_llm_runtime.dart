import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/features/extraction/domain/llm_backend_policy.dart';
import 'package:vaultvoice/features/extraction/domain/llm_runtime.dart';
import 'package:vaultvoice/features/extraction/domain/llm_service.dart';
import 'package:vv_native/vv_native.dart';

/// [LlmRuntime] over `vv_native` (`vv_llm_*`, LLM-04).
final class FfiLlmRuntime implements LlmRuntime {
  FfiLlmRuntime(this._native);

  final VvNative _native;

  @override
  Future<LlmSession> load(
    String modelPath,
    LlmBackendChoice choice, {
    required int contextSize,
  }) async {
    try {
      final llm = await _native.loadLlm(
        modelPath,
        LlmBackendParams(
          useGpu: choice.useGpu,
          gpuDevice: choice.gpuDevice,
          kvQuant: choice.kvQuant,
          flashAttn: choice.flashAttn.native,
          nCtx: contextSize,
        ),
      );
      return _FfiSession(llm);
    } on VvLlmException catch (e) {
      throw LlmLoadException(e.code);
    }
  }
}

/// Maps an [LlmSampling] request to native generation params.
LlmGenParams genParamsFor(
  LlmSampling s,
  int maxTokens,
  String? grammar, {
  bool reusePrefix = false,
}) {
  final base = switch (s.preset) {
    LlmPreset.extraction => LlmGenParams.extraction(
      grammar: grammar,
      nPredict: maxTokens,
    ),
    LlmPreset.deterministic => LlmGenParams.deterministic(
      grammar: grammar,
      nPredict: maxTokens,
    ),
    LlmPreset.summary => LlmGenParams.summary(nPredict: maxTokens),
    LlmPreset.classification => LlmGenParams(
      grammar: grammar,
      nPredict: maxTokens < 16 ? maxTokens : 16,
      temperature: 0,
      minP: 0,
    ),
  };
  return LlmGenParams(
    nPredict: base.nPredict,
    seed: s.seed ?? base.seed,
    temperature: s.temperature ?? base.temperature,
    topK: base.topK,
    topP: base.topP,
    minP: base.minP,
    repeatPenalty: base.repeatPenalty,
    repeatLastN: base.repeatLastN,
    grammar: grammar,
    tokenBatch: base.tokenBatch,
    reusePrefix: reusePrefix,
  );
}

LlmRunStatus statusOf(int code) => switch (code) {
  VV_OK => LlmRunStatus.ok,
  VV_E_CANCELLED => LlmRunStatus.cancelled,
  VV_E_INVALID_ARG => LlmRunStatus.invalid,
  VV_E_BACKEND => LlmRunStatus.backend,
  VV_E_OOM => LlmRunStatus.outOfMemory,
  VV_E_BUSY => LlmRunStatus.busy,
  _ => LlmRunStatus.other,
};

final class _FfiSession implements LlmSession {
  _FfiSession(this._llm) : _info = _llm.info;

  final VvLlm _llm;
  final LlmInfo _info;

  @override
  bool get usedGpu => _info.usedGpu;

  @override
  int get contextSize => _info.nCtx;

  @override
  int countTokens(String text) => _llm.countTokens(text);

  @override
  String applyChatTemplate(List<(String, String)> messages) {
    try {
      return _llm.applyChatTemplate(messages);
    } on VvLlmException {
      throw const LlmRequestException(LlmRejection.unsupportedTemplate);
    }
  }

  @override
  LlmRun generate(
    String prompt, {
    required LlmSampling sampling,
    required int maxTokens,
    String? grammar,
    bool reusePrefix = false,
  }) {
    try {
      final g = _llm.generate(
        prompt,
        genParamsFor(sampling, maxTokens, grammar, reusePrefix: reusePrefix),
      );
      return _FfiRun(g, gpu: usedGpu);
    } on VvLlmException catch (e) {
      throw LlmRequestException(
        e.code == VV_E_BUSY ? LlmRejection.busy : LlmRejection.invalidGrammar,
      );
    }
  }

  @override
  void dispose() => _llm.destroy();
}

final class _FfiRun implements LlmRun {
  _FfiRun(this._g, {required this.gpu});

  final LlmGeneration _g;
  final bool gpu;

  @override
  Stream<String> get text => _g.text;

  @override
  Future<LlmRunStats> get done => _g.done.then(
    (r) => LlmRunStats(
      status: statusOf(r.status),
      nativeCode: r.status,
      promptTokens: r.nPrompt,
      generatedTokens: r.nGen,
      prefill: Duration(microseconds: (r.prefillMs * 1000).round()),
      decode: Duration(microseconds: (r.decodeMs * 1000).round()),
      usedGpu: gpu,
      reusedPromptTokens: r.reusedTokens,
    ),
  );

  @override
  void cancel() => _g.cancel();
}
