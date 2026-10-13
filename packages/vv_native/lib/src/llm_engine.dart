import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:vv_native/src/llm_backend.dart';
import 'package:vv_native/src/loader.dart';
import 'package:vv_native/src/vv_bindings.g.dart';

/// Sampling + limits for one generation (`vv_gen_params`). Presets follow
/// vv-llm-inference → "Sampling presets".
final class LlmGenParams {
  const LlmGenParams({
    this.nPredict = 1024,
    this.seed = 42,
    this.temperature = 0.2,
    this.topK = 40,
    this.topP = 1.0,
    this.minP = 0.05,
    this.repeatPenalty = 1.0,
    this.repeatLastN = 64,
    this.grammar,
    this.tokenBatch = 4,
  });

  /// Structured extraction (default): grammar + temp 0.2, min_p 0.05,
  /// top_k 40, no repeat penalty, fixed seed.
  const LlmGenParams.extraction({String? grammar, int nPredict = 1024})
    : this(grammar: grammar, nPredict: nPredict);

  /// Deterministic tests: greedy, seed 42.
  const LlmGenParams.deterministic({String? grammar, int nPredict = 256})
    : this(grammar: grammar, nPredict: nPredict, temperature: 0, minP: 0);

  /// Free-text summary field.
  const LlmGenParams.summary({int nPredict = 512})
    : this(
        nPredict: nPredict,
        temperature: 0.5,
        topK: 0,
        topP: 0.95,
        repeatPenalty: 1.05,
      );

  /// Classification (PRF-06): grammar enum, greedy, max 16 tokens.
  const LlmGenParams.classification({required String grammar})
    : this(grammar: grammar, nPredict: 16, temperature: 0, minP: 0);

  final int nPredict;
  final int seed;
  final double temperature;
  final int topK;
  final double topP;
  final double minP;
  final double repeatPenalty;
  final int repeatLastN;

  /// GBNF (root rule `root`) or null = unconstrained.
  final String? grammar;
  final int tokenBatch;
}

/// Outcome of one generation (`on_done`).
final class LlmGenResult {
  const LlmGenResult({
    required this.status,
    required this.nPrompt,
    required this.nGen,
    required this.prefillMs,
    required this.decodeMs,
  });

  /// `VV_OK`, `VV_E_CANCELLED`, `VV_E_BACKEND`, …
  final int status;
  final int nPrompt;
  final int nGen;
  final double prefillMs;
  final double decodeMs;

  double get prefillTps => prefillMs > 0 ? nPrompt * 1000 / prefillMs : 0;
  double get decodeTps => decodeMs > 0 ? nGen * 1000 / decodeMs : 0;
}

/// A running generation: streamed text chunks + completion.
final class LlmGeneration {
  LlmGeneration._(this.text, this.done, this._cancel);

  /// UTF-8 text chunks in order (batched by the engine).
  final Stream<String> text;

  /// Completes after the last [text] chunk has been delivered.
  final Future<LlmGenResult> done;
  final void Function() _cancel;

  /// Requests cancellation; [done] then reports `VV_E_CANCELLED`.
  void cancel() => _cancel();
}

/// Effective backend of a loaded model (`vv_llm_info`).
final class LlmInfo {
  const LlmInfo({
    required this.usedGpu,
    required this.usedKvQuant,
    required this.fallbacks,
    required this.nCtx,
    required this.nThreads,
    required this.loadMs,
    required this.modelBytes,
  });

  final bool usedGpu;
  final bool usedKvQuant;
  final int fallbacks;
  final int nCtx;
  final int nThreads;
  final double loadMs;
  final int modelBytes;
}

/// One loaded model + context in native memory (`vv_llm*`). Destroy it
/// explicitly ([destroy]) — memory is the scarce resource (LLM-07).
final class VvLlm {
  VvLlm._(this._b, this._h);

  /// Loads [modelPath] on a background isolate (seconds) and returns the
  /// handle. Throws [VvLlmException] (`VV_E_MODEL_LOAD`, `VV_E_OOM`, …).
  static Future<VvLlm> load(
    String modelPath,
    LlmBackendParams params, {
    String? hostPath,
  }) async {
    final address = await Isolate.run(() {
      final b = VvBindings(openVvNative(hostPath: hostPath));
      return using((arena) {
        final p = arena<vv_llm_backend_params>();
        params.fill(p, b);
        final out = arena<Pointer<vv_llm>>();
        final rc = b.vv_llm_create(
          modelPath.toNativeUtf8(allocator: arena).cast(),
          p,
          out,
        );
        if (rc != VV_OK) throw VvLlmException(rc);
        return out.value.address;
      });
    });
    return VvLlm._(
      VvBindings(openVvNative(hostPath: hostPath)),
      Pointer<vv_llm>.fromAddress(address),
    );
  }

  final VvBindings _b;
  Pointer<vv_llm> _h;
  bool _running = false;

  bool get isLoaded => _h != nullptr;

  Pointer<vv_llm> get _handle {
    if (_h == nullptr) throw StateError('VvLlm destroyed');
    return _h;
  }

  LlmInfo get info => using((arena) {
    final i = arena<vv_llm_info>();
    i.ref.struct_size = sizeOf<vv_llm_info>();
    final rc = _b.vv_llm_get_info(_handle, i);
    if (rc != VV_OK) throw VvLlmException(rc);
    final r = i.ref;
    return LlmInfo(
      usedGpu: r.used_gpu != 0,
      usedKvQuant: r.used_kv_quant != 0,
      fallbacks: r.fallbacks,
      nCtx: r.n_ctx,
      nThreads: r.n_threads,
      loadMs: r.load_ms,
      modelBytes: r.model_bytes,
    );
  });

  /// Exact token count (vv-llm-inference → Token budget).
  int countTokens(String text) => using((arena) {
    final out = arena<Int32>();
    final rc = _b.vv_llm_count_tokens(
      _handle,
      text.toNativeUtf8(allocator: arena).cast(),
      out,
    );
    if (rc != VV_OK) throw VvLlmException(rc);
    return out.value;
  });

  /// Applies the GGUF's chat template. Messages are `(role, content)`.
  /// Throws `VV_E_INVALID_ARG` when the template is unsupported.
  String applyChatTemplate(List<(String, String)> messages) => using((arena) {
    final msgs = arena<vv_chat_msg>(messages.length);
    for (var i = 0; i < messages.length; i++) {
      msgs[i]
        ..role = messages[i].$1.toNativeUtf8(allocator: arena).cast()
        ..content = messages[i].$2.toNativeUtf8(allocator: arena).cast();
    }
    final out = arena<Pointer<Char>>();
    final rc = _b.vv_llm_apply_chat_template(
      _handle,
      msgs,
      messages.length,
      out,
    );
    if (rc != VV_OK) throw VvLlmException(rc);
    try {
      return _decode(out.value);
    } finally {
      _b.vv_free_string(out.value);
    }
  });

  /// Starts a generation on the native worker thread. Throws
  /// [VvLlmException] for `VV_E_BUSY` / `VV_E_INVALID_ARG` (bad grammar).
  LlmGeneration generate(String prompt, LlmGenParams params) {
    if (_running) throw const VvLlmException(VV_E_BUSY);
    final controller = StreamController<String>();
    final done = Completer<LlmGenResult>();
    var received = 0;
    int? expected;
    LlmGenResult? result;
    late final NativeCallable<vv_llm_text_cbFunction> onText;
    late final NativeCallable<vv_llm_done_cbFunction> onDone;

    void finishIfComplete() {
      if (result == null || received < expected!) return;
      onText.close();
      onDone.close();
      _running = false;
      unawaited(controller.close());
      done.complete(result);
    }

    onText = NativeCallable<vv_llm_text_cbFunction>.listener((
      Pointer<Void> _,
      Pointer<Char> text,
    ) {
      final s = _decode(text);
      _b.vv_free_string(text);
      received++;
      controller.add(s);
      finishIfComplete();
    });
    onDone = NativeCallable<vv_llm_done_cbFunction>.listener((
      Pointer<Void> _,
      int status,
      int nChunks,
      int nPrompt,
      int nGen,
      double prefillMs,
      double decodeMs,
    ) {
      expected = nChunks;
      result = LlmGenResult(
        status: status,
        nPrompt: nPrompt,
        nGen: nGen,
        prefillMs: prefillMs,
        decodeMs: decodeMs,
      );
      finishIfComplete();
    });

    final rc = using((arena) {
      final g = arena<vv_gen_params>()..ref = _b.vv_llm_default_gen_params();
      g.ref
        ..n_predict = params.nPredict
        ..seed = params.seed
        ..temperature = params.temperature
        ..top_k = params.topK
        ..top_p = params.topP
        ..min_p = params.minP
        ..repeat_penalty = params.repeatPenalty
        ..repeat_last_n = params.repeatLastN
        ..token_batch = params.tokenBatch
        ..grammar = params.grammar == null
            ? nullptr
            : params.grammar!.toNativeUtf8(allocator: arena).cast();
      final cb = arena<vv_llm_callbacks>();
      cb.ref
        ..on_text = onText.nativeFunction
        ..on_done = onDone.nativeFunction
        ..user = nullptr;
      // prompt / grammar are copied synchronously by the bridge.
      return _b.vv_llm_generate_async(
        _handle,
        prompt.toNativeUtf8(allocator: arena).cast(),
        g,
        cb.ref,
      );
    });
    if (rc != VV_OK) {
      onText.close();
      onDone.close();
      unawaited(controller.close());
      throw VvLlmException(rc);
    }
    _running = true;
    final h = _h;
    return LlmGeneration._(controller.stream, done.future, () {
      if (_h == h && h != nullptr) _b.vv_llm_cancel(h);
    });
  }

  /// Cancels the running generation (if any); returns immediately.
  void cancel() {
    if (_h != nullptr) _b.vv_llm_cancel(_h);
  }

  /// Cancels, waits for the worker and frees model + context. Idempotent.
  void destroy() {
    if (_h == nullptr) return;
    _b.vv_llm_destroy(_h);
    _h = nullptr;
  }

  static String _decode(Pointer<Char> p) {
    final bytes = p.cast<Uint8>();
    var n = 0;
    while (bytes[n] != 0) {
      n++;
    }
    return utf8.decode(
      Uint8List.fromList(bytes.asTypedList(n)),
      allowMalformed: true,
    );
  }
}
