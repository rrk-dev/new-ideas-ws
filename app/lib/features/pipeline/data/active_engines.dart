import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/core/platform/stt_engine.dart';
import 'package:vaultvoice/features/extraction/domain/llm_runtime.dart';
import 'package:vaultvoice/features/extraction/domain/llm_service.dart';
import 'package:vaultvoice/features/extraction/domain/model_residency.dart';
import 'package:vaultvoice/features/pipeline/domain/active_models.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_step.dart';
import 'package:vaultvoice/features/transcription/data/whisper_stt_engine.dart';
import 'package:vaultvoice/features/transcription/domain/stt_model_policy.dart';

/// An installed model file the worker can load right now.
final class ActiveModel {
  const ActiveModel({
    required this.id,
    required this.path,
    required this.sizeBytes,
    this.contextSize = kFallbackLlmContext,
  });

  final String id;

  /// Absolute file path (resolved from the `models_installed` row).
  final String path;
  final int sizeBytes;

  /// LLM context for the device tier (published with the selection).
  final int contextSize;
}

/// Resolves the active model of a heavy step inside the worker: the id the
/// UI isolate published under [kActiveModelsKey] (FND-11), checked against
/// `models_installed` (type) and the file on disk. Null ⇒ `model_missing`.
final class InstalledModelResolver {
  InstalledModelResolver({required this.db, required this.paths});

  final VaultVoiceDatabase db;
  final StoragePaths paths;

  Future<ActiveModel?> resolve(HeavyModel kind) async {
    final published = await db.settingsRepository.get(kActiveModelsKey);
    final selection = ActiveModelSelection.fromJson(published.valueOrNull);
    final id = selection.idOf(switch (kind) {
      HeavyModel.stt => EngineModelKind.stt,
      HeavyModel.llm => EngineModelKind.llm,
    });
    if (id == null) return null;
    final row = (await db.modelsRepository.get(id)).valueOrNull;
    final type = kind == HeavyModel.stt ? ModelType.stt : ModelType.llm;
    if (row == null || row.type != type) return null;
    // A stored path escaping the storage root is never loaded.
    if (p.isAbsolute(row.path)) return null;
    final path = p.normalize(p.join(paths.root, row.path));
    if (!p.isWithin(paths.root, path)) return null;
    if (!File(path).existsSync()) return null;
    return ActiveModel(
      id: row.id,
      path: path,
      sizeBytes: row.size,
      contextSize: selection.llmContext,
    );
  }

  /// [resolve] as the steps' model-id lookup.
  Future<String?> activeId(HeavyModel kind) async => (await resolve(kind))?.id;
}

/// [SttEngine] over the active STT model: one [WhisperSttEngine] per model,
/// replaced (old one unloaded) when the active model changes. Registers with
/// the shared [ModelResidency] so loading STT unloads the LLM first. Also
/// windowed (STT-04 long-form ranges), like [WhisperSttEngine].
final class ActiveSttEngine implements WindowedSttEngine {
  ActiveSttEngine({
    required this.resolve,
    required this.create,
    required this.residency,
  }) {
    residency.register(ResidentModel.stt, () => unawaited(unload()));
  }

  final Future<ActiveModel?> Function() resolve;
  final WhisperSttEngine Function(ActiveModel model) create;
  final ModelResidency residency;

  WhisperSttEngine? _engine;
  ActiveModel? _model;

  /// Id of the model the current engine was built for (diagnostics/tests).
  String? get modelId => _model?.id;

  @override
  Future<Result<Transcript>> transcribe(
    String audioPath, {
    CancelToken? cancel,
    ProgressCallback? onProgress,
    SegmentCallback? onSegment,
    SttOptions options = const SttOptions(),
  }) async {
    final engine = await _current();
    if (engine == null) return const Err(ModelMissingFailure('stt'));
    return await engine.transcribe(
      audioPath,
      cancel: cancel,
      onProgress: onProgress,
      onSegment: onSegment,
      options: _forModel(options),
    );
  }

  @override
  Future<Result<Transcript>> transcribeRanges(
    List<SttAudioRange> ranges, {
    CancelToken? cancel,
    ProgressCallback? onProgress,
    SegmentCallback? onSegment,
    SttOptions options = const SttOptions(),
  }) async {
    final engine = await _current();
    if (engine == null) return const Err(ModelMissingFailure('stt'));
    return await engine.transcribeRanges(
      ranges,
      cancel: cancel,
      onProgress: onProgress,
      onSegment: onSegment,
      options: _forModel(options),
    );
  }

  SttOptions _forModel(SttOptions o) {
    final path = _model?.path;
    return path == null ? o : sttOptionsForModelFile(path, o);
  }

  /// The engine of the active model (rebuilt when the selection changed),
  /// marked resident; null when no usable STT model is installed.
  Future<WhisperSttEngine?> _current() async {
    final model = await resolve();
    if (model == null) return null;
    if (_model?.id != model.id || _model?.path != model.path) {
      await _engine?.unload();
      _engine = create(model);
      _model = model;
    }
    residency.acquire(ResidentModel.stt);
    return _engine;
  }

  /// Frees the whisper model (idempotent).
  Future<void> unload() async {
    await _engine?.unload();
    residency.release(ResidentModel.stt);
  }
}

/// [LlmEngine] over the active LLM: one [LlmService] per (model, context),
/// rebuilt when the selection changes. Foreground/background and memory
/// pressure are forwarded to the current service. Also the exact
/// [LlmTokenizer] of the active model (LLM-06 token budgets).
final class ActiveLlmEngine implements LlmEngine, LlmTokenizer {
  ActiveLlmEngine({
    required this.resolve,
    required this.create,
    required this.residency,
  }) {
    residency.register(ResidentModel.llm, unload);
  }

  final Future<ActiveModel?> Function() resolve;
  final LlmService Function(ActiveModel model) create;
  final ModelResidency residency;

  LlmService? _service;
  ActiveModel? _model;
  bool _foreground = true;

  /// The current service (diagnostics/tests).
  LlmService? get service => _service;

  /// The service of the active model (rebuilt when the selection changed),
  /// or null when no usable LLM is installed.
  Future<LlmService?> _current() async {
    final model = await resolve();
    if (model == null) return null;
    final current = _model;
    if (current == null ||
        current.id != model.id ||
        current.path != model.path ||
        current.contextSize != model.contextSize) {
      unload();
      final service = _service = create(model);
      _model = model;
      if (!_foreground) service.onBackgrounded();
    }
    return _service;
  }

  @override
  Future<Result<String>> generate(
    LlmRequest request, {
    CancelToken? cancel,
    void Function(String token)? onToken,
  }) async {
    final service = await _current();
    if (service == null) return const Err(ModelMissingFailure('llm'));
    return await service.generate(request, cancel: cancel, onToken: onToken);
  }

  @override
  Future<Result<int>> countTokens(String text) async {
    final service = await _current();
    if (service == null) return const Err(ModelMissingFailure('llm'));
    return await service.countTokens(text);
  }

  @override
  Future<Result<int>> countPromptTokens(
    String user, {
    String? systemPrompt,
  }) async {
    final service = await _current();
    if (service == null) return const Err(ModelMissingFailure('llm'));
    return await service.countPromptTokens(user, systemPrompt: systemPrompt);
  }

  @override
  Future<Result<int>> contextWindow() async {
    final service = await _current();
    if (service == null) return const Err(ModelMissingFailure('llm'));
    return await service.contextWindow();
  }

  /// Frees the model (a running generation is cancelled first).
  void unload() {
    _service?.unload();
    residency.release(ResidentModel.llm);
  }

  void setForeground({required bool foreground}) {
    _foreground = foreground;
    if (foreground) {
      _service?.onForegrounded();
    } else {
      _service?.onBackgrounded();
    }
  }

  void onMemoryPressure() {
    _service?.onMemoryPressure();
    residency.release(ResidentModel.llm);
  }
}

/// Collects [LlmRunStats] of the running step (FND-07 metrics).
final class LlmStatsTap {
  final List<LlmRunStats> _runs = [];

  void add(LlmRunStats stats) => _runs.add(stats);

  /// Returns and clears the runs since the last call.
  List<LlmRunStats> take() {
    final out = List<LlmRunStats>.of(_runs);
    _runs.clear();
    return out;
  }
}

/// STT-07 `sttLanguageFor` applied to the model file at [path]: `.en` models
/// always decode English; multilingual ones get the requested language
/// (`auto` detects). Unknown file names keep [o] unchanged.
SttOptions sttOptionsForModelFile(String path, SttOptions o) {
  final variant = SttVariant.fromFile(p.basename(path));
  if (variant == null) return o;
  final language = sttLanguageFor(variant, o.language);
  if (language == o.language) return o;
  return SttOptions(
    language: language,
    initialPrompt: o.initialPrompt,
    beamSize: o.beamSize,
    temperatureFallback: o.temperatureFallback,
    tokenTimestamps: o.tokenTimestamps,
    threads: o.threads,
    vadModelPath: o.vadModelPath,
  );
}
