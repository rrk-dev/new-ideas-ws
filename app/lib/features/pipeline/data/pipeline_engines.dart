import 'package:vaultvoice/core/platform/clock.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/core/platform/stt_engine.dart';
import 'package:vaultvoice/core/platform/vad_engine.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';
import 'package:vaultvoice/features/pipeline/data/steps/render_write_steps.dart';
import 'package:vaultvoice/features/pipeline/domain/heavy_model_gate.dart';

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

/// Everything heavy the worker owns. Built *inside* the worker isolate by a
/// [PipelineEnginesFactory] so native handles and `NativeCallable`s are
/// created and closed in the isolate that uses them.
class PipelineEngines {
  PipelineEngines({
    required this.stt,
    required this.llm,
    required this.vault,
    HeavyModelGate? gate,
    this.clock = const SystemClock(),
    this.renderer,
    this.vad,
  }) : gate = gate ?? HeavyModelGate();

  final SttEngine stt;
  final LlmEngine llm;
  final VaultWriter vault;
  final HeavyModelGate gate;
  final Clock clock;

  /// Markdown renderer for `RenderStep` (EXP-01 `TemplateNoteRenderer`);
  /// null keeps the FND-05 placeholder until the worker factory loads the
  /// built-in profiles and templates.
  final NoteRenderer? renderer;

  /// Speech timeline before STT (AUD-03, `FfiVadEngine`); null = whisper's
  /// built-in VAD still skips silence, but no `speech_segments` are stored.
  final VadEngine? vad;
}

/// Creates the engines in the worker isolate. Must be sendable: a top-level
/// or static function, or a closure capturing only sendable values.
typedef PipelineEnginesFactory = PipelineEngines Function();
