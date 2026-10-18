import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/extraction/domain/long_transcript/map_reduce_extractor.dart';
import 'package:vaultvoice/features/mindmap/domain/mind_map_generator.dart';
import 'package:vaultvoice/features/pipeline/data/long_transcript_strategy.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_step.dart';

/// `processing.mind_map` values (ADR-MAP-01).
enum MindMapMode {
  auto,
  onDemand;

  static MindMapMode parse(Object? raw, {required MindMapMode fallback}) =>
      switch (raw) {
        'auto' => auto,
        'on_demand' => onDemand,
        _ => fallback,
      };
}

/// Default of `processing.mind_map` (ADR-MAP-01 decides from the measured
/// seconds; PRODUCT-DECISION until the device rows exist).
/// PRODUCT-DECISION: provisional production method until the ADR is measured.
const MindMapMethod kDefaultMindMapMethod = MindMapMethod.hybrid;

const MindMapMode kDefaultMindMapMode = MindMapMode.onDemand;

/// The pipeline's view of mind-map generation (engine seam, like
/// `ExtractionStrategy`).
abstract interface class MindMapStrategy {
  Future<Result<MindMapResult>> generate(StepContext ctx, MindMapInput input);
}

/// Production strategy: [MindMapGenerator] over the LLM-06 map-reduce
/// extractor, checkpointing through the step context.
final class GeneratorMindMapStrategy implements MindMapStrategy {
  GeneratorMindMapStrategy({
    required this.method,
    this.extractor,
    this.grammarLoader,
  });

  final MindMapMethod method;
  final MapReduceExtractor? extractor;

  /// GBNF of the topic schema (null/absent for the projection method).
  final Future<String?> Function()? grammarLoader;

  @override
  Future<Result<MindMapResult>> generate(
    StepContext ctx,
    MindMapInput input,
  ) async {
    final String? grammar;
    if (method == MindMapMethod.projection) {
      grammar = null;
    } else {
      grammar = await grammarLoader?.call();
      if (grammar == null || extractor == null) {
        return const Err(UnexpectedFailure('no mind-map grammar'));
      }
    }
    return await MindMapGenerator(
      method: method,
      extractor: extractor,
      grammar: grammar,
    ).generate(
      input,
      cancel: ctx.cancel,
      onProgress: ctx.reportProgress,
      checkpoints: StepCheckpointStore(ctx),
    );
  }
}
