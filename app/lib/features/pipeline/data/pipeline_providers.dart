import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/features/pipeline/data/job_mapper.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_engines.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_isolate.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_client.dart';

part 'pipeline_providers.g.dart';

/// Builds the real engines inside the worker isolate. No default: STT-03,
/// LLM-04 and EXP-05 supply it via `bootstrap(overrides: …)`; tests use a
/// factory of fakes.
@Riverpod(keepAlive: true)
PipelineEnginesFactory pipelineEnginesFactory(Ref ref) =>
    throw UnimplementedError(
      'pipelineEnginesFactoryProvider must be overridden',
    );

@Riverpod(keepAlive: true)
PipelineConfig pipelineConfig(Ref ref) => const PipelineConfig();

/// The pipeline worker, running on its own background isolate and sharing
/// the process's single database connection.
@Riverpod(keepAlive: true)
Future<PipelineClient> pipelineClient(Ref ref) async {
  final db = ref.watch(vaultVoiceDatabaseProvider);
  final paths = await ref.watch(storagePathsProvider.future);
  final client = await PipelineIsolateClient.spawn(
    database: await db.serializableConnection(),
    storageRoot: paths.root,
    engines: ref.watch(pipelineEnginesFactoryProvider),
    config: ref.watch(pipelineConfigProvider),
  );
  ref.onDispose(client.dispose);
  return client;
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
