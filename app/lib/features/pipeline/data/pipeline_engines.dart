import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/platform/clock.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/core/platform/stt_engine.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';
import 'package:vaultvoice/features/pipeline/data/steps/render_write_steps.dart';
import 'package:vaultvoice/features/pipeline/domain/heavy_model_gate.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_step.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';

/// Engine configuration the pipeline uses until the owning tasks provide
/// richer settings (STT-07 model variants, PRF-01 profiles, EXP-03/04
/// targets).
class PipelineConfig {
  const PipelineConfig({
    this.sttModelId = 'ggml-base',
    this.sttLanguage = 'auto',
    this.llmModelId = 'default-llm',
    // PRODUCT-DECISION: recordings without a chosen profile are extracted with
    // the built-in Meeting profile (conservative default until PRF-06 auto
    // classification lands). Confirm with the product owner.
    this.defaultProfileId = 'meeting',
    this.maxLlmTokens = 1024,
  });

  final String sttModelId;
  final String sttLanguage;
  final String llmModelId;
  final String defaultProfileId;
  final int maxLlmTokens;
}

/// The id of the model a heavy step would use now, or null when no usable
/// model is installed (the step then waits: `waiting(model_missing)`).
typedef ActiveModelIdLookup = Future<String?> Function(HeavyModel model);

/// A profile by id (built-in or user/enterprise), or null when unknown.
typedef ProfileLookup = Future<Profile?> Function(String profileId);

/// The GBNF grammar of [profile]'s output schema, or null when it cannot be
/// built (extraction then runs unconstrained).
typedef ProfileGrammarLookup = Future<String?> Function(Profile profile);

/// Builds the renderer for one job (EXP-01 `TemplateNoteRenderer` over the
/// built-ins plus a DB snapshot of user profiles/templates, FND-11).
typedef NoteRendererLoader = Future<NoteRenderer> Function();

/// The writer for one configured vault target (app-local / SAF / bookmark).
typedef VaultWriterFor = VaultWriter Function(VaultTargetRow target);

/// Per-step performance measurement (FND-07 `JobMetrics`), started right
/// after a step's active state is persisted.
abstract interface class StepMetrics {
  /// Null when [step] is not measured.
  Future<StepMeasurement?> begin(JobSnapshot job, PipelineStep step);
}

/// An in-flight [StepMetrics] measurement.
abstract interface class StepMeasurement {
  /// Stores the measurement; [succeeded] is false for failed/cancelled runs.
  Future<void> finish({required bool succeeded});
}

/// Everything heavy the worker owns. Built *inside* the worker isolate by a
/// [PipelineEnginesFactory] so native handles and `NativeCallable`s are
/// created and closed in the isolate that uses them.
///
/// The optional members are the production seams (FND-11); tests may leave
/// them null to keep the FND-05 defaults (config model ids, placeholder
/// prompt/renderer, [vault] for every target, no metrics).
class PipelineEngines {
  PipelineEngines({
    required this.stt,
    required this.llm,
    required this.vault,
    HeavyModelGate? gate,
    this.clock = const SystemClock(),
    this.renderer,
    this.rendererLoader,
    this.activeModel,
    this.profiles,
    this.grammars,
    this.vaultFor,
    this.metrics,
    this.onForeground,
    this.onMemoryPressure,
    this.dispose,
  }) : gate = gate ?? HeavyModelGate();

  final SttEngine stt;
  final LlmEngine llm;

  /// Writer for every target unless [vaultFor] is set (then: fallback).
  final VaultWriter vault;
  final HeavyModelGate gate;
  final Clock clock;

  /// Markdown renderer for `RenderStep`; null keeps the FND-05 placeholder.
  /// Ignored when [rendererLoader] is set.
  final NoteRenderer? renderer;

  /// Renderer built per job (fresh user profiles/templates).
  final NoteRendererLoader? rendererLoader;

  /// Active STT/LLM model ids; null uses `PipelineConfig` ids.
  final ActiveModelIdLookup? activeModel;

  /// Profile resolution for extraction and filename patterns.
  final ProfileLookup? profiles;

  /// Grammar for a profile (structured extraction, LLM-05).
  final ProfileGrammarLookup? grammars;
  final VaultWriterFor? vaultFor;
  final StepMetrics? metrics;

  /// The app moved to the foreground (true) / background (false): GPU work
  /// is only allowed in the foreground (backend policy, iOS rule).
  final void Function({required bool foreground})? onForeground;

  /// OS memory warning: stop LLM work at the next token and unload.
  final void Function()? onMemoryPressure;

  /// Frees models when the worker stops.
  final Future<void> Function()? dispose;
}

/// What the worker isolate gives the engines factory: its database
/// connection (shared drift connection) and the storage layout.
class PipelineWorkerContext {
  const PipelineWorkerContext({required this.db, required this.paths});

  final VaultVoiceDatabase db;
  final StoragePaths paths;
}

/// Creates the engines in the worker isolate. Must be sendable: a top-level
/// or static function, or a closure capturing only sendable values.
typedef PipelineEnginesFactory = PipelineEngines Function(
  PipelineWorkerContext context,
);
