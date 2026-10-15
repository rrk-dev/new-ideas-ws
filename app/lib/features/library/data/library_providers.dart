import 'package:drift/drift.dart' show OrderingTerm, innerJoin;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';
import 'package:vaultvoice/features/export/data/export_providers.dart';
import 'package:vaultvoice/features/export/domain/vault_folder.dart';
import 'package:vaultvoice/features/library/data/recording_deleter.dart';
import 'package:vaultvoice/features/library/data/search_repository.dart';
import 'package:vaultvoice/features/library/domain/library_models.dart';
import 'package:vaultvoice/features/library/domain/recording_detail.dart';
import 'package:vaultvoice/features/pipeline/data/job_mapper.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_providers.dart';
import 'package:vaultvoice/features/pipeline/domain/job_progress.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/profiles/data/profile_providers.dart';

part 'library_providers.g.dart';

@Riverpod(keepAlive: true)
SearchRepository searchRepository(Ref ref) =>
    SearchRepository(ref.watch(vaultVoiceDatabaseProvider));

/// The Library's search text, filters and sort (kept across tab switches).
@Riverpod(keepAlive: true)
class LibraryFilterState extends _$LibraryFilterState {
  @override
  LibraryFilter build() => const LibraryFilter();

  // A setter would read worse at the call sites (`notifier.update(...)`).
  // ignore: use_setters_to_change_properties
  void update(LibraryFilter filter) => state = filter;
}

/// Every recording as a Library item, recomputed whenever recordings, jobs,
/// exports, vault targets or extractions change.
@riverpod
Stream<List<LibraryItem>> libraryItems(Ref ref) {
  final db = ref.watch(vaultVoiceDatabaseProvider);
  return db
      .customSelect(
        'SELECT 1',
        readsFrom: {
          db.recordings,
          db.jobs,
          db.exports,
          db.vaultTargets,
          db.extractions,
        },
      )
      .watch()
      .asyncMap((_) => loadLibraryItems(db));
}

/// Builds [LibraryItem]s from the current rows (one query per table).
Future<List<LibraryItem>> loadLibraryItems(VaultVoiceDatabase db) async {
  final recordings = await (db.select(
    db.recordings,
  )..orderBy([(r) => OrderingTerm.desc(r.createdAt)])).get();
  final jobs = await db.jobsRepository.watchAll().first;
  final exports = await db.select(db.exports).get();
  final targets = {
    for (final t in await db.select(db.vaultTargets).get()) t.id: t,
  };
  final extractionProfile = <String, String>{};
  for (final e
      in await (db.select(db.extractions)..orderBy([
            (e) => OrderingTerm.asc(e.createdAt),
            (e) => OrderingTerm.asc(e.id),
          ]))
          .get()) {
    extractionProfile[e.recordingId] = e.profileId; // newest wins
  }
  final jobByRecording = <String, JobSnapshot>{};
  for (final row in jobs) {
    final job = jobFromRow(row);
    final current = jobByRecording[job.recordingId];
    if (current == null ||
        (isInPipeline(job) && !isInPipeline(current)) ||
        (isInPipeline(job) == isInPipeline(current) &&
            job.createdAt.isAfter(current.createdAt))) {
      jobByRecording[job.recordingId] = job;
    }
  }
  final exportsByRecording = <String, List<ExportInfo>>{};
  for (final e in exports) {
    (exportsByRecording[e.recordingId] ??= []).add(
      ExportInfo(
        targetId: e.targetId,
        targetName: targets[e.targetId]?.displayName ?? '',
        relPath: e.relPath,
        written: e.status == ExportStatus.written,
        failed: e.status == ExportStatus.failed,
        updatedAt: e.updatedAt,
      ),
    );
  }
  return [
    for (final r in recordings)
      () {
        final job = jobByRecording[r.id];
        final ex = exportsByRecording[r.id] ?? const <ExportInfo>[];
        return LibraryItem(
          id: r.id,
          title: r.title,
          createdAt: r.createdAt,
          duration: Duration(milliseconds: r.durationMs),
          profileId: r.profileId ?? extractionProfile[r.id],
          tags: r.tags,
          exports: ex,
          job: job,
          status: libraryStatus(
            capturing:
                r.status == RecordingStatus.recording ||
                r.status == RecordingStatus.inProgress,
            job: job,
            exports: ex,
          ),
        );
      }(),
  ];
}

/// Filtered, sorted Library items with their search hits (by recording id).
typedef LibraryResults = ({
  List<LibraryItem> items,
  Map<String, SearchHit> hits,
  bool searching,
});

@riverpod
Future<LibraryResults> libraryResults(Ref ref) async {
  final filter = ref.watch(libraryFilterStateProvider);
  final items = await ref.watch(libraryItemsProvider.future);
  final searching = ftsTerms(filter.query).isNotEmpty;
  if (!searching) {
    return (
      items: applyLibraryFilter(items, filter),
      hits: const <String, SearchHit>{},
      searching: false,
    );
  }
  final found =
      (await ref.watch(searchRepositoryProvider).search(filter.query))
          .valueOrNull ??
      const <SearchHit>[];
  final hits = {for (final h in found) h.recordingId: h};
  return (
    items: applyLibraryFilter(
      items,
      filter,
      matches: {for (final h in found) h.recordingId: h.rank},
    ),
    hits: hits,
    searching: true,
  );
}

/// Profile names by id (built-in + user), for list subtitles and filters.
@riverpod
Stream<Map<String, String>> profileNames(Ref ref) async* {
  final registry = await ref.watch(profileRegistryProvider.future);
  yield* registry.watchAll().map(
    (profiles) => {for (final p in profiles) p.id: p.name},
  );
}

@riverpod
Stream<RecordingHeader?> recordingHeader(Ref ref, String recordingId) => ref
    .watch(recordingsRepositoryProvider)
    .watch(recordingId)
    .map(
      (r) => r == null
          ? null
          : RecordingHeader(
              id: r.id,
              title: r.title,
              createdAt: r.createdAt,
              duration: Duration(milliseconds: r.durationMs),
              tags: r.tags,
              imported: r.source == RecordingSource.imported,
              profileId: r.profileId,
            ),
    );

/// Lines of the newest transcript (empty before transcription).
@riverpod
Stream<List<TranscriptLine>> recordingTranscript(Ref ref, String recordingId) {
  final db = ref.watch(vaultVoiceDatabaseProvider);
  final repo = db.transcriptsRepository;
  return db
      .customSelect(
        'SELECT 1',
        readsFrom: {db.transcripts, db.transcriptSegments},
      )
      .watch()
      .asyncMap((_) async {
        final t = (await repo.latestFor(recordingId)).valueOrNull;
        if (t == null) return const <TranscriptLine>[];
        final rows = (await repo.segments(t.id)).valueOrNull ?? const [];
        return [
          for (final s in rows)
            TranscriptLine(
              startMs: s.startMs,
              endMs: s.endMs,
              text: s.body,
              speaker: s.speaker,
            ),
        ];
      });
}

/// Export history of one recording.
@riverpod
Stream<List<ExportInfo>> recordingExports(Ref ref, String recordingId) {
  final db = ref.watch(vaultVoiceDatabaseProvider);
  return db
      .customSelect('SELECT 1', readsFrom: {db.exports, db.vaultTargets})
      .watch()
      .asyncMap((_) async {
        final targets = {
          for (final t in await db.select(db.vaultTargets).get()) t.id: t,
        };
        final rows = await db.vaultRepository
            .watchExports(recordingId: recordingId)
            .first;
        return [
          for (final e in rows)
            ExportInfo(
              targetId: e.targetId,
              targetName: targets[e.targetId]?.displayName ?? '',
              relPath: e.relPath,
              written: e.status == ExportStatus.written,
              failed: e.status == ExportStatus.failed,
              updatedAt: e.updatedAt,
            ),
        ];
      });
}

@riverpod
Stream<ExtractionView?> recordingExtraction(Ref ref, String recordingId) => ref
    .watch(extractionsRepositoryProvider)
    .watchForRecording(recordingId)
    .map(
      (rows) => rows.isEmpty
          ? null
          : ExtractionView(
              id: rows.first.id,
              profileId: rows.first.profileId,
              profileVersion: rows.first.profileVersion,
              modelId: rows.first.modelId,
              data: rows.first.json,
              valid: rows.first.valid,
              createdAt: rows.first.createdAt,
            ),
    );

/// Action items across recordings, newest recording first.
@riverpod
Stream<List<ActionItemView>> actionItems(Ref ref, {required bool openOnly}) {
  final db = ref.watch(vaultVoiceDatabaseProvider);
  final query = db.select(db.actionItems).join([
    innerJoin(
      db.recordings,
      db.recordings.id.equalsExp(db.actionItems.recordingId),
    ),
  ]);
  if (openOnly) query.where(db.actionItems.done.equals(false));
  query.orderBy([
    OrderingTerm.desc(db.recordings.createdAt),
    OrderingTerm.asc(db.actionItems.id),
  ]);
  return query.watch().map(
    (rows) => [
      for (final row in rows)
        () {
          final a = row.readTable(db.actionItems);
          final r = row.readTable(db.recordings);
          return ActionItemView(
            id: a.id,
            recordingId: a.recordingId,
            recordingTitle: r.title,
            body: a.body,
            done: a.done,
            owner: a.owner,
            due: a.dueIso,
            tMs: a.tMs,
          );
        }(),
    ],
  );
}

/// Deletes recordings (and, on request, their exported notes).
@Riverpod(keepAlive: true)
Future<RecordingDeleter> recordingDeleter(Ref ref) async {
  final db = ref.watch(vaultVoiceDatabaseProvider);
  final paths = await ref.watch(storagePathsProvider.future);
  return LocalRecordingDeleter(
    db: db,
    paths: paths,
    writerFor: (target) => writerForTarget(ref, target),
    stopJobs: (jobIds) async {
      if (jobIds.isEmpty) return;
      try {
        final client = await ref.read(pipelineClientProvider.future);
        for (final id in jobIds) {
          await client.cancel(id);
        }
      } on Object {
        // No worker running: nothing writes for these jobs.
      }
    },
  );
}

/// The vault writer for a stored target, or null when unavailable.
VaultWriter? writerForTarget(Ref ref, VaultTargetRow target) {
  try {
    return switch (target.platform) {
      VaultPlatform.appLocal => ref.read(appLocalVaultWriterProvider),
      VaultPlatform.androidSaf =>
        ref
            .read(vaultFolderAccessProvider)
            .writerFor(
              VaultFolder(kind: VaultTargetKind.saf, handle: target.handle),
            ),
      VaultPlatform.iosBookmark =>
        ref
            .read(vaultFolderAccessProvider)
            .writerFor(
              VaultFolder(
                kind: VaultTargetKind.bookmark,
                handle: target.handle,
              ),
            ),
    };
  } on Object {
    return null;
  }
}
