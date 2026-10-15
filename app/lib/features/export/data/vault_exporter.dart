import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/clock.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';
import 'package:vaultvoice/core/utils/ids.dart';
import 'package:vaultvoice/features/export/domain/export_collision.dart';
import 'package:vaultvoice/features/export/domain/filename_pattern.dart';
import 'package:vaultvoice/features/export/domain/filename_sanitizer.dart';
import 'package:vaultvoice/features/export/domain/routing_engine.dart';
import 'package:vaultvoice/features/export/domain/routing_rule.dart';
import 'package:vaultvoice/features/export/domain/vault_target_options.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';

/// Opens a [VaultWriter] for a stored vault target (SAF tree, bookmark,
/// app-local). See `platformVaultWriterResolver`.
typedef VaultWriterResolver = VaultWriter Function(VaultTargetRow target);

/// An audio file to copy next to the note (`attachments/<note>.<ext>`).
typedef AudioAttachment = ({Uint8List bytes, String extension});

/// Supplies the recording's audio for the audio sidecar; null when no
/// exportable audio exists (deleted by retention, or no encoder yet).
typedef AudioAttachmentSource = Future<AudioAttachment?> Function(
  String recordingId,
);

/// One note to export.
class ExportRequest {
  const ExportRequest({
    required this.recordingId,
    required this.markdown,
    required this.routing,
    required this.filename,
    this.transcriptMarkdown,
  });

  final String recordingId;

  /// The rendered note (`rendered/<recording_id>.md`).
  final String markdown;
  final RoutingInput routing;
  final FilenameValues filename;

  /// Body of the optional transcript sidecar; null = no transcript.
  final String? transcriptMarkdown;
}

/// Result of exporting to one target (content-free).
class TargetExport {
  const TargetExport({
    required this.targetId,
    required this.source,
    this.relPath,
    this.reason,
    this.failure,
  });

  final String targetId;
  final RouteSource source;

  /// The note path in the target (user content: never log it).
  final String? relPath;
  final PlanReason? reason;
  final Failure? failure;

  bool get ok => failure == null;
}

/// Outcome of [VaultExporter.export].
sealed class ExportOutcome {
  const ExportOutcome(this.targets);

  final List<TargetExport> targets;
}

/// Every routed target holds the note (written, unchanged or skipped).
final class ExportDone extends ExportOutcome {
  const ExportDone(super.targets);
}

/// No usable destination: none configured, or a target's access was
/// revoked. The job waits (`waiting(destination)`) until the user adds or
/// re-grants a folder; done targets are not rewritten on retry.
final class ExportNeedsDestination extends ExportOutcome {
  const ExportNeedsDestination(super.targets);
}

/// A target failed transiently (unavailable storage, IO, disk full): retry.
final class ExportFailed extends ExportOutcome {
  const ExportFailed(super.targets, this.failure);

  final Failure failure;
}

/// Writes a rendered note to every destination chosen by the routing rules
/// (EXP-05), with EXP-02 stable identity and collision handling per target.
///
/// Idempotent: before each write the `exports` row is set to `writing`
/// with the planned path (persist before act); a crash before or after the
/// write is recovered on the next run without a duplicate — the planned path
/// is reused and a file whose hash equals the new content counts as ours.
/// A failure keeps the row's last *written* hash so a re-grant never
/// mistakes our own note for a user edit.
class VaultExporter {
  VaultExporter({
    required this.db,
    required this.writerFor,
    this.audio,
    this.clock = const SystemClock(),
  });

  final VaultVoiceDatabase db;
  final VaultWriterResolver writerFor;
  final AudioAttachmentSource? audio;
  final Clock clock;

  /// Exports [request]; never throws (DB errors become [ExportFailed]).
  Future<ExportOutcome> export(ExportRequest request) async {
    try {
      return await _export(request);
    } on _DbFailure catch (e) {
      return ExportFailed(const [], e.failure);
    } on Object catch (e) {
      return ExportFailed(
        const [],
        UnexpectedFailure(e.runtimeType.toString()),
      );
    }
  }

  Future<ExportOutcome> _export(ExportRequest request) async {
    final settings = db.settingsRepository;
    final targets = await db.vaultRepository.watchTargets().first;
    final rules = [
      for (final r in await db.vaultRepository.watchRules().first)
        RoutingRule.fromRow(
          id: r.id,
          priority: r.priority,
          targetId: r.targetId,
          match: r.match,
          subPath: r.subPath,
          filenamePattern: r.filenamePattern,
        ),
    ];
    final policy = RoutingPolicy.fromJson(
      (await settings.get(SettingKeys.exportRoutingPolicy)).valueOrNull,
    );
    final decisions = routeNote(
      input: request.routing,
      rules: rules,
      targetIds: [for (final t in targets) t.id],
      policy: policy,
    );
    if (decisions.isEmpty) return const ExportNeedsDestination([]);

    final options = decodeTargetOptions(
      (await settings.get(SettingKeys.exportTargetOptions)).valueOrNull,
    );
    final globalPattern =
        _string(
          (await settings.get(SettingKeys.exportFilenamePattern)).valueOrNull,
        ) ??
        kDefaultFilenamePattern;
    final globalMode = _mode(
      (await settings.get(SettingKeys.exportCollisionMode)).valueOrNull,
    );
    final byId = {for (final t in targets) t.id: t};

    final results = <TargetExport>[];
    for (final d in decisions) {
      final opts = options[d.targetId] ?? VaultTargetOptions.defaults;
      results.add(
        await _exportTo(
          request,
          byId[d.targetId]!,
          d,
          opts,
          pattern: d.filenamePattern ?? opts.filenamePattern ?? globalPattern,
          mode: opts.collision ?? globalMode,
        ),
      );
    }
    final failed = [
      for (final r in results)
        if (!r.ok) r,
    ];
    if (failed.isEmpty) return ExportDone(results);
    if (failed.any((r) => _needsDestination(r.failure!))) {
      return ExportNeedsDestination(results);
    }
    return ExportFailed(results, failed.first.failure!);
  }

  static bool _needsDestination(Failure f) =>
      f is PermissionFailure ||
      (f is VaultAccessFailure && f.access == VaultAccess.revoked);

  Future<TargetExport> _exportTo(
    ExportRequest request,
    VaultTargetRow target,
    RouteDecision decision,
    VaultTargetOptions opts, {
    required String pattern,
    required CollisionMode mode,
  }) async {
    TargetExport fail(Failure f, [String? path]) => TargetExport(
      targetId: target.id,
      source: decision.source,
      relPath: path,
      failure: f,
    );

    final desired = _desiredPath(pattern, decision.subPath, request.filename);
    if (desired == null) return fail(const StorageFailure('bad pattern'));
    final rows = await db.vaultRepository.watchExports().first;
    final own = rows
        .where(
          (r) =>
              r.recordingId == request.recordingId && r.targetId == target.id,
        )
        .firstOrNull;

    final VaultWriter writer;
    try {
      writer = writerFor(target);
    } on Object catch (e) {
      final f = UnexpectedFailure(e.runtimeType.toString());
      await _markFailed(request.recordingId, target.id, own, desired.path);
      return fail(f);
    }
    switch (await writer.checkAccess()) {
      case VaultAccess.ok:
        break;
      case VaultAccess.revoked:
        await _markFailed(request.recordingId, target.id, own, desired.path);
        return fail(const VaultAccessFailure.revoked());
      case VaultAccess.unavailable:
        await _markFailed(request.recordingId, target.id, own, desired.path);
        return fail(const VaultAccessFailure.unavailable());
    }

    final hash = fnv1a32(request.markdown);
    // A failed read is not "no file": retry once, then fail the export so an
    // unreadable (possibly user-edited) note is never overwritten.
    Future<String?> diskHash(String path) async {
      var read = await writer.read(path);
      if (read is Err<Uint8List?>) read = await writer.read(path);
      return switch (read) {
        Ok(value: final Uint8List bytes) => fnv1a32(
          utf8.decode(bytes, allowMalformed: true),
        ),
        Ok() => null,
        Err(:final failure) => throw _ReadFailure(failure),
      };
    }

    // Stable identity (EXP-02). A row without a hash was never confirmed
    // written: it pins its path only while that path is free or already
    // holds exactly this content (crash between write and commit).
    PriorExport? prior;
    if (own != null) {
      if (own.contentHash.isNotEmpty) {
        prior = PriorExport(relPath: own.relPath, contentHash: own.contentHash);
      } else {
        try {
          final onDisk = await diskHash(own.relPath);
          if (onDisk == null || onDisk == hash) {
            prior = PriorExport(relPath: own.relPath, contentHash: '');
          }
        } on _ReadFailure catch (e) {
          await _markFailed(request.recordingId, target.id, own, desired.path);
          return fail(e.failure, desired.path);
        }
      }
    }
    final claimed = {
      for (final r in rows)
        if (r.targetId == target.id && r.recordingId != request.recordingId)
          r.relPath,
    };

    final Result<ExportPlan> planned;
    try {
      planned = await planExport(
        desired: desired,
        contentHash: hash,
        mode: mode,
        exists: writer.exists,
        prior: prior,
        claimedByOthers: claimed,
        // Our own new content on disk is not a user edit (crash after write).
        currentHash: (path) async {
          final onDisk = await diskHash(path);
          return onDisk == hash ? prior?.contentHash : onDisk;
        },
      );
    } on _ReadFailure catch (e) {
      await _markFailed(request.recordingId, target.id, own, desired.path);
      return fail(e.failure, desired.path);
    }
    final ExportPlan plan;
    switch (planned) {
      case Err(:final failure):
        await _markFailed(request.recordingId, target.id, own, desired.path);
        return fail(failure, desired.path);
      case Ok(:final value):
        plan = value;
    }

    // The note is ours at plan.relPath unless a foreign file was skipped.
    final ownsNote = plan.reason != PlanReason.skippedCollision;
    if (plan is WritePlan) {
      await _upsert(
        request.recordingId,
        target.id,
        relPath: plan.relPath,
        // Keep the last confirmed hash until the write succeeded.
        hash: prior != null && prior.relPath == plan.relPath
            ? prior.contentHash
            : '',
        status: ExportStatus.writing,
        attempts: own?.attempts ?? 0,
      );
      final written = await writer.write(
        NoteDraft(relativePath: plan.relPath, markdown: request.markdown),
        overwrite: plan.overwrite,
      );
      if (written case Err(:final failure)) {
        await _markFailed(request.recordingId, target.id, null, plan.relPath);
        return fail(failure, plan.relPath);
      }
    }
    if (ownsNote) {
      final sidecar = await _sidecars(
        request,
        writer,
        plan.relPath,
        opts,
        refreshable: own != null && own.contentHash.isNotEmpty,
        claimed: claimed,
      );
      if (sidecar != null) {
        if (plan is WritePlan) {
          await _upsert(
            request.recordingId,
            target.id,
            relPath: plan.relPath,
            hash: hash,
            status: ExportStatus.failed,
            attempts: (own?.attempts ?? 0) + 1,
          );
        } else {
          await _markFailed(request.recordingId, target.id, own, plan.relPath);
        }
        return fail(sidecar, plan.relPath);
      }
    }
    // A skipped collision leaves a confirmed row alone but settles an
    // unconfirmed (failed/pending) one so it does not stay in the outbox.
    if (!ownsNote && own != null && own.status != ExportStatus.written) {
      await _upsert(
        request.recordingId,
        target.id,
        relPath: own.relPath,
        hash: own.contentHash,
        status: ExportStatus.skipped,
        attempts: own.attempts,
      );
    }
    if (ownsNote) {
      await _upsert(
        request.recordingId,
        target.id,
        relPath: plan.relPath,
        hash: hash,
        status: ExportStatus.written,
        attempts: (own?.attempts ?? 0) + (plan is WritePlan ? 1 : 0),
      );
    }
    return TargetExport(
      targetId: target.id,
      source: decision.source,
      relPath: plan.relPath,
      reason: plan.reason,
    );
  }

  /// Writes the enabled sidecars; returns the first failure.
  Future<Failure?> _sidecars(
    ExportRequest request,
    VaultWriter writer,
    String notePath,
    VaultTargetOptions opts, {
    required bool refreshable,
    required Set<String> claimed,
  }) async {
    if (opts.transcriptSidecar && request.transcriptMarkdown != null) {
      final path = SidecarPaths.transcript(notePath);
      // Overwritten only when this recording already exported here and no
      // other recording's note lives at that path; otherwise a pre-existing
      // file is foreign and never replaced.
      final r = await writer.write(
        NoteDraft(relativePath: path, markdown: request.transcriptMarkdown!),
        overwrite: refreshable && !claimed.contains(path),
      );
      if (r case Err(:final failure)) return failure;
    }
    final source = audio;
    if (opts.audioSidecar && source != null) {
      final file = await source(request.recordingId);
      if (file != null) {
        final path = SidecarPaths.audio(notePath, file.extension);
        switch (await writer.exists(path)) {
          case Err(:final failure):
            return failure;
          case Ok(value: true):
            break; // audio never changes: keep the copy
          case Ok(value: false):
            final r = await writer.writeBytes(path, file.bytes);
            if (r case Err(:final failure)) return failure;
        }
      }
    }
    return null;
  }

  /// A failed attempt. The last confirmed hash (and path) is kept so the
  /// retry recognises our note; a new row has no hash.
  Future<void> _markFailed(
    String recordingId,
    String targetId,
    ExportRow? known,
    String path,
  ) async {
    final row =
        known ??
        (await db.vaultRepository.getExport(exportId(recordingId, targetId)))
            .valueOrNull;
    await _upsert(
      recordingId,
      targetId,
      relPath: row?.relPath ?? path,
      hash: row?.contentHash ?? '',
      status: ExportStatus.failed,
      attempts: (row?.attempts ?? 0) + 1,
    );
  }

  Future<void> _upsert(
    String recordingId,
    String targetId, {
    required String relPath,
    required String hash,
    required ExportStatus status,
    required int attempts,
  }) async {
    final r = await db.vaultRepository.upsertExport(
      ExportsCompanion.insert(
        id: exportId(recordingId, targetId),
        recordingId: recordingId,
        targetId: targetId,
        relPath: relPath,
        contentHash: hash,
        status: status,
        attempts: Value(attempts),
        updatedAt: clock.now(),
      ),
    );
    if (r case Err(:final failure)) throw _DbFailure(failure);
  }

  static NotePath? _desiredPath(
    String pattern,
    String subPath,
    FilenameValues values,
  ) {
    final parsed =
        FilenamePattern.parse(pattern).valueOrNull ??
        FilenamePattern.parse(kDefaultFilenamePattern).valueOrNull;
    if (parsed == null) return null;
    final note = parsed.renderPath(values);
    final sub = sanitizeSubPath(subPath);
    if (sub.isEmpty) return note;
    return NotePath(
      note.folder.isEmpty ? sub : '$sub/${note.folder}',
      note.file,
    );
  }

  static String? _string(Object? v) =>
      v is String && v.trim().isNotEmpty ? v : null;

  static CollisionMode _mode(Object? v) =>
      CollisionMode.values.where((m) => m.name == v).firstOrNull ??
      CollisionMode.suffix;
}

/// The `exports.id` of a recording × target (same as FND-05's WriteStep).
String exportId(String recordingId, String targetId) =>
    '$recordingId.$targetId';

/// A rule's sub-folder, each segment sanitized (EXP-02); `''` = root.
String sanitizeSubPath(String raw) => [
  for (final s in raw.split(RegExp(r'[/\\]')))
    if (s.trim() case final t when t.isNotEmpty && t != '.' && t != '..')
      sanitizeSegment(t),
].join('/');

class _ReadFailure implements Exception {
  const _ReadFailure(this.failure);
  final Failure failure;
}

class _DbFailure implements Exception {
  const _DbFailure(this.failure);

  final Failure failure;
}
