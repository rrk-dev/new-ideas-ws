import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/diagnostics/job_metrics.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/backend_policy.dart';
import 'package:vaultvoice/core/platform/clock.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';
import 'package:vaultvoice/features/export/data/app_local_vault_writer.dart';
import 'package:vaultvoice/features/export/data/bookmark_vault_writer.dart';
import 'package:vaultvoice/features/export/data/saf_vault_writer.dart';
import 'package:vaultvoice/features/extraction/data/ffi_llm_runtime.dart';
import 'package:vaultvoice/features/extraction/data/native_device_capabilities.dart';
import 'package:vaultvoice/features/extraction/data/native_schema_grammar_converter.dart';
import 'package:vaultvoice/features/extraction/domain/llm_backend_policy.dart';
import 'package:vaultvoice/features/extraction/domain/llm_service.dart';
import 'package:vaultvoice/features/extraction/domain/memory_planner.dart';
import 'package:vaultvoice/features/extraction/domain/model_residency.dart';
import 'package:vaultvoice/features/pipeline/data/active_engines.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_engines.dart';
import 'package:vaultvoice/features/pipeline/data/steps/render_write_steps.dart';
import 'package:vaultvoice/features/pipeline/domain/heavy_model_gate.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_step.dart';
import 'package:vaultvoice/features/profiles/data/profile_registry.dart';
import 'package:vaultvoice/features/profiles/domain/builtin_profiles.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/domain/profile_validator.dart';
import 'package:vaultvoice/features/templates/data/template_note_renderer.dart';
import 'package:vaultvoice/features/templates/domain/builtin_templates.dart';
import 'package:vaultvoice/features/transcription/data/whisper_stt_engine.dart';
import 'package:vv_native/vv_native.dart';

/// Sendable inputs of the production engine factory (FND-11), prepared on
/// the UI isolate (asset text, platform paths) and handed to the worker,
/// which calls [build] to create the real engines there:
///
/// - STT: [WhisperSttEngine] over the active installed model;
/// - LLM: [LlmService] over `vv_native` with the LLM-07 pre-load memory
///   check, the tier context and the shared STT/LLM backend policy;
/// - one [ModelResidency] + [HeavyModelGate]: never STT and LLM together;
/// - extraction profiles + grammars ([ProfileRegistry] with the native
///   converter) and [TemplateNoteRenderer] (built-ins + DB snapshot per job);
/// - a vault writer per configured target; JobMetrics for heavy steps.
final class ProductionEngineSpec {
  const ProductionEngineSpec({
    required this.profileSources,
    required this.templateSources,
    required this.appLocalVaultRoot,
    required this.metricsFile,
    required this.platform,
    this.appVersion = '0.0.0',
    this.nativeLibPath,
    this.rootIsolateToken,
    this.foreground = true,
  });

  /// Built-in profile assets (asset path → YAML text).
  final Map<String, String> profileSources;

  /// Built-in template assets (asset path → Mustache text).
  final Map<String, String> templateSources;

  /// Root of the app's own vault folder (app-local target).
  final String appLocalVaultRoot;

  /// FND-07 metrics JSON-lines file.
  final String metricsFile;
  final DevicePlatform platform;
  final String appVersion;

  /// Host tests/tools: `libvv_native` outside an app bundle (null on
  /// devices).
  final String? nativeLibPath;

  /// Lets the worker use platform channels (SAF / bookmark writers) through
  /// `BackgroundIsolateBinaryMessenger`; null in plain Dart tests.
  final RootIsolateToken? rootIsolateToken;

  /// App lifecycle when the worker starts (later changes are forwarded).
  final bool foreground;

  /// Runs inside the worker isolate.
  PipelineEngines build(PipelineWorkerContext context) {
    // Only a background isolate needs (and may set up) the messenger.
    if (rootIsolateToken case final token?
        when RootIsolateToken.instance == null) {
      BackgroundIsolateBinaryMessenger.ensureInitialized(token);
    }
    final db = context.db;
    final builtins = BuiltinProfiles.parse(profileSources);
    final templates = BuiltinTemplates.parse(templateSources);
    final converter = NativeSchemaGrammarConverter(hostPath: nativeLibPath);
    final registry = ProfileRegistry(
      dao: db.profilesRepository,
      builtins: builtins,
      grammarConverter: converter,
      clock: const SystemClock(),
    );
    final models = InstalledModelResolver(db: db, paths: context.paths);
    final residency = ModelResidency();
    final stats = LlmStatsTap();
    final native = _LazyNative(nativeLibPath);
    var inForeground = foreground;

    LlmBackendChoice? backend() => chooseLlmBackend(
      caps: native.caps,
      platform: platform,
      foreground: inForeground,
    );

    final stt = ActiveSttEngine(
      resolve: () => models.resolve(HeavyModel.stt),
      residency: residency,
      create: (m) => WhisperSttEngine(
        modelId: m.id,
        modelPath: () async => m.path,
        // Shared policy (ADR-STT-02 / ADR-INT-W2): background ⇒ CPU.
        useGpu: () => backend()?.useGpu ?? false,
        hostLibPath: nativeLibPath,
      ),
    );
    final llm = ActiveLlmEngine(
      resolve: () => models.resolve(HeavyModel.llm),
      residency: residency,
      create: (m) => LlmService(
        runtime: FfiLlmRuntime(native.value),
        modelPath: m.path,
        // A CPU lacking the build's required features cannot run llama.cpp;
        // the run then fails (permanent) instead of crashing (LLM-03).
        backend: () =>
            backend() ??
            const LlmBackendChoice(useGpu: false, reason: 'cpu-unsupported'),
        contextSize: m.contextSize,
        loadGate: (requested) {
          final plan = planLlmLoad(
            modelFileBytes: m.sizeBytes,
            availableBytes: native.value.deviceMemory.$2,
            requestedContext: requested,
          );
          return plan.allowed
              ? Ok(plan.contextSize)
              : const Err(OutOfMemoryFailure());
        },
        onBeforeLoad: () => residency.acquire(ResidentModel.llm),
        onStats: stats.add,
      ),
    );
    final gate = HeavyModelGate(
      release: (model) async {
        switch (model) {
          case HeavyModel.stt:
            await stt.unload();
          case HeavyModel.llm:
            llm.unload();
        }
      },
    );
    final appLocal = AppLocalVaultWriter.at(Directory(appLocalVaultRoot));

    Future<Profile?> profile(String id) async =>
        (await registry.get(id)).valueOrNull;

    return PipelineEngines(
      stt: stt,
      llm: llm,
      vault: appLocal,
      gate: gate,
      activeModel: models.activeId,
      profiles: profile,
      grammars: (p) async =>
          (await registry.grammarsFor(p)).valueOrNull?.schema,
      rendererLoader: () => loadNoteRenderer(
        db,
        builtins: builtins,
        templates: templates,
        appVersion: appVersion,
      ),
      vaultFor: (target) => vaultWriterFor(target, appLocal: appLocal, db: db),
      metrics: PipelineJobMetrics(
        db: db,
        recorder: JobMetricsRecorder(
          store: JsonlMetricsStore(File(metricsFile)),
        ),
        llmStats: stats,
      ),
      onForeground: ({required foreground}) {
        inForeground = foreground;
        llm.setForeground(foreground: foreground);
      },
      onMemoryPressure: llm.onMemoryPressure,
      dispose: () async {
        await stt.unload();
        llm.unload();
      },
    );
  }
}

/// Opens `vv_native` on first use (the factory itself never touches FFI).
final class _LazyNative {
  _LazyNative(this.hostPath);

  final String? hostPath;
  VvNative? _native;
  NativeDeviceCapabilities? _caps;

  VvNative get value => _native ??= VvNative.open(hostPath: hostPath);
  NativeDeviceCapabilities get caps =>
      _caps ??= NativeDeviceCapabilities(value);
}

/// The writer of one configured vault target. App-local targets use the
/// app's own folder; SAF/bookmark writers call the platform host APIs (from
/// the worker via `BackgroundIsolateBinaryMessenger`). A refreshed iOS
/// bookmark is stored back on the target row.
VaultWriter vaultWriterFor(
  VaultTargetRow target, {
  required VaultWriter appLocal,
  required VaultVoiceDatabase db,
}) => switch (target.platform) {
  VaultPlatform.appLocal => appLocal,
  VaultPlatform.androidSaf => SafVaultWriter(treeUri: target.handle),
  VaultPlatform.iosBookmark => BookmarkVaultWriter(
    bookmark: target.handle,
    onRefreshed: (refreshed) => unawaited(
      (db.update(db.vaultTargets)..where((t) => t.id.equals(target.id))).write(
        VaultTargetsCompanion(handle: Value(refreshed)),
      ),
    ),
  ),
};

/// A [TemplateNoteRenderer] over the built-ins plus a snapshot of the user
/// profiles and templates stored now (FND-11: taken at job start, so edits
/// apply to the next job, never mid-render). Stored profiles that no longer
/// validate are left out (their notes fall back to `summary-only`).
Future<NoteRenderer> loadNoteRenderer(
  VaultVoiceDatabase db, {
  required BuiltinProfiles builtins,
  required BuiltinTemplates templates,
  required String appVersion,
}) async {
  const validator = ProfileValidator();
  final rows = await db.profilesRepository.watchProfiles().first;
  final userProfiles = <String, Profile>{};
  for (final row in rows) {
    final p = validator.validate(row.definition, source: row.source).profile;
    if (p != null) userProfiles[p.id] = p;
  }
  final userTemplates = {
    for (final t in await db.profilesRepository.watchTemplates().first)
      t.id: t.body,
  };
  return TemplateNoteRenderer(
    profiles: builtins,
    templates: templates,
    appVersion: appVersion,
    userProfiles: userProfiles,
    userTemplates: userTemplates,
  ).call;
}

/// FND-07 [JobMetrics] for the heavy steps: transcribe (audio duration =
/// the recording's chunks) and extract (prompt/generated tokens and
/// prefill/decode time summed over the step's LLM runs). Only successful
/// runs are stored.
final class PipelineJobMetrics implements StepMetrics {
  PipelineJobMetrics({
    required this.db,
    required this.recorder,
    required this.llmStats,
  });

  final VaultVoiceDatabase db;
  final JobMetricsRecorder recorder;
  final LlmStatsTap llmStats;

  @override
  Future<StepMeasurement?> begin(JobSnapshot job, PipelineStep step) async {
    final model = step.model;
    if (model == null) return null;
    llmStats.take(); // drop runs of earlier steps
    final session = await recorder.start(job.id, step.id.name);
    return _Measurement(this, session, job.recordingId, model);
  }
}

final class _Measurement implements StepMeasurement {
  _Measurement(this._owner, this._session, this._recordingId, this._model);

  final PipelineJobMetrics _owner;
  final JobMetricsSession _session;
  final String _recordingId;
  final HeavyModel _model;

  @override
  Future<void> finish({required bool succeeded}) async {
    final runs = _owner.llmStats.take();
    if (!succeeded) return;
    switch (_model) {
      case HeavyModel.stt:
        final chunks = await _owner.db.recordingsRepository
            .watchChunks(_recordingId)
            .first;
        var audioMs = 0;
        for (final c in chunks) {
          audioMs += c.endMs - c.startMs;
        }
        await _session.finish(audioDuration: Duration(milliseconds: audioMs));
      case HeavyModel.llm:
        var prompt = 0;
        var generated = 0;
        var prefill = Duration.zero;
        var decode = Duration.zero;
        for (final r in runs) {
          prompt += r.promptTokens;
          generated += r.generatedTokens;
          prefill += r.prefill;
          decode += r.decode;
        }
        await _session.finish(
          promptTokens: prompt,
          generatedTokens: generated,
          prefillTime: prefill,
          decodeTime: decode,
        );
    }
  }
}

/// [DevicePlatform] of the running process.
DevicePlatform currentDevicePlatform() => Platform.isIOS
    ? DevicePlatform.ios
    : Platform.isAndroid
    ? DevicePlatform.android
    : DevicePlatform.host;
