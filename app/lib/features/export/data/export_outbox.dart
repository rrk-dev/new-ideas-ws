import 'package:drift/drift.dart';
import 'package:vaultvoice/core/app_info.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/clock.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';
import 'package:vaultvoice/core/utils/ids.dart';
import 'package:vaultvoice/features/export/data/vault_exporter.dart';
import 'package:vaultvoice/features/export/domain/pending_export.dart';
import 'package:vaultvoice/features/export/domain/vault_folder.dart';
import 'package:vaultvoice/features/pipeline/data/job_mapper.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_client.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';

/// Id of the app's own folder when used as a vault target ("Save on this
/// device").
const String kAppLocalTargetId = 'app-local';

VaultTargetKind kindOfPlatform(VaultPlatform p) => switch (p) {
  VaultPlatform.androidSaf => VaultTargetKind.saf,
  VaultPlatform.iosBookmark => VaultTargetKind.bookmark,
  VaultPlatform.appLocal => VaultTargetKind.appLocal,
};

VaultPlatform platformOfKind(VaultTargetKind k) => switch (k) {
  VaultTargetKind.saf => VaultPlatform.androidSaf,
  VaultTargetKind.bookmark => VaultPlatform.iosBookmark,
  VaultTargetKind.appLocal => VaultPlatform.appLocal,
};

/// The export outbox (EXP-06): what still has to reach a vault folder, and
/// the user actions that unblock it. The rendered note always stays in app
/// storage, so nothing is lost while a folder is unavailable; every retry
/// goes through the pipeline's write step, which is idempotent (EXP-02
/// stable identity, EXP-05 `VaultExporter`) — a re-grant never duplicates.
class ExportOutbox {
  ExportOutbox({
    required this.db,
    required this.client,
    this.folders,
    this.writerFor,
    this.clock = const SystemClock(),
  });

  final VaultVoiceDatabase db;

  /// The pipeline worker (resolve waiting / retry jobs).
  final Future<PipelineClient> Function() client;

  /// Folder picker for re-grant / change destination (null in tests that
  /// do not pick).
  final VaultFolderAccess? folders;

  /// Access check for [recheck].
  final VaultWriterResolver? writerFor;
  final Clock clock;

  /// The pending list, re-emitted on every change of jobs, exports,
  /// targets or recordings.
  Stream<List<PendingExport>> watch() async* {
    // A closed database (app shutdown, tests) ends the stream quietly.
    final first = await _safeSnapshot();
    if (first == null) return;
    yield first;
    await for (final _ in db.tableUpdates(
      TableUpdateQuery.onAllTables([
        db.jobs,
        db.exports,
        db.vaultTargets,
        db.recordings,
      ]),
    )) {
      final next = await _safeSnapshot();
      if (next == null) return;
      yield next;
    }
  }

  Future<List<PendingExport>?> _safeSnapshot() async {
    try {
      return await snapshot();
      // A stream `.first` on a closed database throws StateError.
      // ignore: avoid_catching_errors
    } on StateError {
      return null;
    }
  }

  Future<List<PendingExport>> snapshot() async {
    final jobs = [
      for (final r in await db.jobsRepository.watchAll().first) jobFromRow(r),
    ];
    final exports = await db.select(db.exports).get();
    final targets = await db.vaultRepository.watchTargets().first;
    final ids = {
      for (final j in jobs) j.recordingId,
      for (final e in exports) e.recordingId,
    };
    final recordings = await (db.select(
      db.recordings,
    )..where((r) => r.id.isIn(ids))).get();
    return buildPendingExports(
      jobs: jobs,
      exports: exports,
      targets: targets,
      titles: {for (final r in recordings) r.id: r.title},
    );
  }

  /// Runs the write step again for [item]: resolves a waiting job, retries
  /// a failed one, or re-runs the write of a finished job.
  Future<Result<void>> retry(PendingExport item) async {
    final jobId = item.jobId;
    if (jobId == null) return const Err(StorageFailure('no job'));
    final row = await db.jobsRepository.get(jobId);
    if (row case Err(:final failure)) return Err(failure);
    final job = jobFromRow(row.valueOrNull!);
    final c = await client();
    return switch (job.state) {
      JobState.waiting => await c.resolveWaiting(jobId),
      JobState.failed || JobState.cancelled => await c.retry(jobId),
      JobState.done => await c.rerun(jobId, PipelineStepId.write),
      // Queued / resting / active: the pipeline is already on it.
      _ => const Ok(null),
    };
  }

  /// Retries every pending item matching [where] (of [items], default:
  /// the current list).
  Future<Result<void>> retryWhere(
    bool Function(PendingExport) where, {
    List<PendingExport>? items,
  }) async {
    Result<void> last = const Ok(null);
    final done = <String>{};
    for (final p in items ?? await snapshot()) {
      if (!where(p) || p.jobId == null || !done.add(p.jobId!)) continue;
      final r = await retry(p);
      if (r case Err()) last = r;
    }
    return last;
  }

  /// Re-grants access to [targetId] (system picker pre-selects the old
  /// folder; [sameFolder] false = "Choose another folder"), stores the new
  /// handle in place — rules and options stay attached to the target — and
  /// retries its pending notes. `Ok(false)` = the user cancelled.
  Future<Result<bool>> regrant(
    String targetId, {
    bool sameFolder = true,
  }) async {
    final access = folders;
    if (access == null) return const Err(UnsupportedFeatureFailure('picker'));
    final row = await db.vaultRepository.getTarget(targetId);
    if (row case Err(:final failure)) return Err(failure);
    final target = row.valueOrNull!;
    final previous = VaultFolder(
      kind: kindOfPlatform(target.platform),
      handle: target.handle,
      displayName: target.displayName,
    );
    final picked = await access.pick(previous: sameFolder ? previous : null);
    switch (picked) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: null):
        return const Ok(false);
      case Ok(value: final VaultFolder folder):
        if (!sameFolder && folder.handle != target.handle) {
          await access.release(previous);
        }
        final saved = await db.vaultRepository.upsertTarget(
          target
              .copyWith(
                handle: folder.handle,
                platform: platformOfKind(folder.kind),
                displayName: folder.displayName ?? target.displayName,
              )
              .toCompanion(true),
        );
        if (saved case Err(:final failure)) return Err(failure);
        await retryWhere((p) => p.targetId == targetId);
        return const Ok(true);
    }
  }

  /// The folder the user just chose becomes the default target.
  Future<void> _makeDefault(String targetId) =>
      db.settingsRepository.set(SettingKeys.exportDefaultTarget, targetId);

  /// Adds a picked folder as a vault target and retries the notes that
  /// had no destination. `Ok(false)` = cancelled.
  Future<Result<bool>> addFolder() async {
    final access = folders;
    if (access == null) return const Err(UnsupportedFeatureFailure('picker'));
    final before = await snapshot();
    switch (await access.pick()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: null):
        return const Ok(false);
      case Ok(value: final VaultFolder folder):
        final newId = newUuidV4();
        final saved = await db.vaultRepository.upsertTarget(
          VaultTargetsCompanion.insert(
            id: newId,
            platform: platformOfKind(folder.kind),
            displayName: folder.displayName ?? kAppName,
            handle: folder.handle,
            createdAt: clock.now(),
          ),
        );
        if (saved case Err(:final failure)) return Err(failure);
        await _makeDefault(newId);
        await retryWhere(
          (p) => p.reason == PendingReason.noDestination,
          items: before,
        );
        return const Ok(true);
    }
  }

  /// "Save on this device": uses the app's own folder (Android app storage,
  /// iOS Files › On My iPhone › VaultVoice) as a vault target and retries
  /// the notes that had no destination.
  Future<Result<void>> saveOnDevice() async {
    final before = await snapshot();
    final existing = await db.vaultRepository.getTarget(kAppLocalTargetId);
    if (existing case Err()) {
      final saved = await db.vaultRepository.upsertTarget(
        VaultTargetsCompanion.insert(
          id: kAppLocalTargetId,
          platform: VaultPlatform.appLocal,
          displayName: kAppName,
          handle: '',
          createdAt: clock.now(),
        ),
      );
      if (saved case Err()) return saved;
    }
    await _makeDefault(kAppLocalTargetId);
    return await retryWhere(
      (p) => p.reason == PendingReason.noDestination,
      items: before,
    );
  }

  /// Checks the folders of pending notes (e.g. on app resume) and retries
  /// the ones whose folder is reachable again. Returns how many targets
  /// were retried.
  Future<int> recheck() async {
    final resolve = writerFor;
    if (resolve == null) return 0;
    final pending = await snapshot();
    final targetIds = {
      for (final p in pending)
        if (p.targetId != null &&
            (p.reason == PendingReason.accessRevoked ||
                p.reason == PendingReason.failed))
          p.targetId!,
    };
    var retried = 0;
    for (final id in targetIds) {
      final row = (await db.vaultRepository.getTarget(id)).valueOrNull;
      if (row == null) continue;
      try {
        if (await resolve(row).checkAccess() != VaultAccess.ok) continue;
      } on Object {
        continue;
      }
      await retryWhere((p) => p.targetId == id);
      retried++;
    }
    return retried;
  }
}
