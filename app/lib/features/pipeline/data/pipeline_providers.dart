import 'package:drift/isolate.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/db/repositories/jobs_repository.dart';
import 'package:vaultvoice/features/pipeline/data/engine_providers.dart';
import 'package:vaultvoice/features/pipeline/data/job_mapper.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_engines.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_isolate.dart';
import 'package:vaultvoice/features/pipeline/data/production_engines.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_client.dart';

part 'pipeline_providers.g.dart';

/// Builds the engines inside the worker isolate. Default (FND-11): the
/// production factory — whisper/llama engines over the active installed
/// models, the template renderer and the vault writers
/// ([ProductionEngineSpec.build]); tests override it with a factory of
/// fakes.
@Riverpod(keepAlive: true)
Future<PipelineEnginesFactory> pipelineEnginesFactory(Ref ref) async =>
    (await ref.watch(productionEngineSpecProvider.future)).build;

@Riverpod(keepAlive: true)
PipelineConfig pipelineConfig(Ref ref) => const PipelineConfig();

/// The pipeline worker, running on its own background isolate and sharing
/// the process's single database connection.
@Riverpod(keepAlive: true)
Future<PipelineClient> pipelineClient(Ref ref) async {
  final db = ref.watch(vaultVoiceDatabaseProvider);
  final paths = await ref.watch(storagePathsProvider.future);
  final engines = await ref.watch(pipelineEnginesFactoryProvider.future);
  // The worker reads the active models from the DB: publish them first.
  final publisher = ref.watch(activeModelsPublisherProvider);
  await publisher.publish();
  final client = await PipelineIsolateClient.spawn(
    database: await db.serializableConnection(),
    storageRoot: paths.root,
    engines: engines,
    config: ref.watch(pipelineConfigProvider),
  );
  // A model became usable (install, selection, plan change): resume jobs
  // parked in `waiting(model_missing)`.
  final sub = publisher.watch(
    onAvailable: (_) => resumeModelWaits(db.jobsRepository, client),
  );
  ref.onDispose(() async {
    await sub.cancel();
    await client.dispose();
  });
  return client;
}

/// Resolves every job waiting for a model (they re-check and park again if
/// their model is still missing).
Future<void> resumeModelWaits(
  JobsRepository jobs,
  PipelineClient client,
) async {
  final rows = await jobs.findByStatus({JobState.waiting.name});
  for (final row in rows.valueOrNull ?? const <JobRow>[]) {
    final job = jobFromRow(row);
    if (job.waitingReason == WaitingReason.modelMissing) {
      await client.resolveWaiting(job.id);
    }
  }
}

/// Every job in queue order (global queue indicator, APP-04).
@Riverpod(keepAlive: true)
Stream<List<JobSnapshot>> pipelineJobs(Ref ref) => ref
    .watch(jobsRepositoryProvider)
    .watchAll()
    .map((rows) => [for (final r in rows) jobFromRow(r)]);

/// Jobs of one recording (per-recording progress, APP-04).
@riverpod
Stream<List<JobSnapshot>> recordingJobs(Ref ref, String recordingId) => ref
    .watch(jobsRepositoryProvider)
    .watchForRecording(recordingId)
    .map((rows) => [for (final r in rows) jobFromRow(r)]);
