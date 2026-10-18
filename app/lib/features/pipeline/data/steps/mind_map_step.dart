import 'package:drift/drift.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/repositories/mind_maps_repository.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/clock.dart';
import 'package:vaultvoice/features/extraction/domain/long_transcript/transcript_chunker.dart';
import 'package:vaultvoice/features/mindmap/data/mind_map_strategy.dart';
import 'package:vaultvoice/features/mindmap/domain/mind_map_generator.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_engines.dart';
import 'package:vaultvoice/features/pipeline/data/steps/step_support.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_step.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';

/// Optional mind-map step between extraction and rendering (MAP-01).
///
/// Runs when `processing.mind_map` is `auto`, or when the user requested a
/// map for this recording (`mind_map.request.<id>`, on-demand generation for
/// older recordings = `rerun(from: mindMap)`). The tree is written only in
/// the step's `commit`, i.e. in the transaction that advances the job, under
/// the deterministic id `<recording>.mindmap`: a kill mid-step leaves no map
/// (or the previous one) and the resumed step produces exactly one. A result
/// the validator rejects is never stored.
class MindMapStep implements AsyncEnabledStep {
  MindMapStep({
    required this.db,
    required this.strategy,
    required this.config,
    this.activeModel,
    this.tier,
    this.clock = const SystemClock(),
  });

  final VaultVoiceDatabase db;
  final MindMapStrategy strategy;
  final PipelineConfig config;
  final ActiveModelIdLookup? activeModel;
  final DeviceTier Function()? tier;
  final Clock clock;

  @override
  PipelineStepId get id => PipelineStepId.mindMap;

  @override
  HeavyModel get model => HeavyModel.llm;

  @override
  bool canRun(JobSnapshot job) => true;

  @override
  Future<bool> isEnabled(JobSnapshot job) async {
    final mode = MindMapMode.parse(
      unwrap(await db.settingsRepository.get(SettingKeys.processingMindMap)),
      fallback: kDefaultMindMapMode,
    );
    if (mode == MindMapMode.auto) return true;
    final requested = unwrap(
      await db.settingsRepository.get(
        SettingKeys.mindMapRequestFor(job.recordingId),
      ),
    );
    return requested == true;
  }

  @override
  Future<StepResult> run(StepContext ctx) async {
    final job = ctx.job;
    final String modelId;
    if (activeModel case final lookup?) {
      final id = await lookup(HeavyModel.llm);
      if (id == null) return const StepWaiting(WaitingReason.modelMissing);
      modelId = id;
    } else {
      modelId = config.llmModelId;
    }
    final transcript = unwrap(
      await db.transcriptsRepository.latestFor(job.recordingId),
    );
    if (transcript == null) {
      return const StepFailed(
        StorageFailure('no transcript'),
        kind: FailureKind.permanent,
      );
    }
    final segments = unwrap(
      await db.transcriptsRepository.segments(transcript.id),
    );
    final recording = unwrap(
      await db.recordingsRepository.get(job.recordingId),
    );
    final extraction = (await db.extractionsRepository.get(
      extractionIdFor(job.id),
    )).valueOrNull;

    final result = await strategy.generate(
      ctx,
      MindMapInput(
        lines: [
          for (final s in segments)
            TranscriptLine(
              startMs: s.startMs,
              speaker: s.speaker,
              text: s.body,
            ),
        ],
        extraction: extraction?.json,
        tier: tier?.call() ?? DeviceTier.mid,
        modelId: modelId,
        fallbackTitle: recording.title,
      ),
    );
    switch (result) {
      case Err(:final failure):
        return StepFailed(failure);
      case Ok(value: final r):
        final tree = r.tree;
        return StepSucceeded(
          commit: () async {
            final repo = db.mindMapsRepository;
            if (tree == null) {
              // Rejected: never store a partial or invalid map, and drop a
              // stale one from before.
              unwrap(await repo.deleteForRecording(job.recordingId));
            } else {
              unwrap(
                await repo.upsert(
                  MindMapsCompanion.insert(
                    id: MindMapsRepository.idFor(job.recordingId),
                    recordingId: job.recordingId,
                    extractionId: Value(extraction?.id),
                    method: r.method.name,
                    modelId: Value(modelId),
                    json: tree.toJson(),
                    nodeCount: tree.count,
                    createdAt: clock.now(),
                  ),
                ),
              );
            }
            unwrap(
              await db.settingsRepository.remove(
                SettingKeys.mindMapRequestFor(job.recordingId),
              ),
            );
          },
        );
    }
  }
}
