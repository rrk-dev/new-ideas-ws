import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/clock.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';
import 'package:vaultvoice/core/utils/ids.dart';
import 'package:vaultvoice/features/export/data/export_identity.dart';
import 'package:vaultvoice/features/export/domain/export_collision.dart';
import 'package:vaultvoice/features/export/domain/filename_pattern.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_engines.dart';
import 'package:vaultvoice/features/pipeline/data/steps/step_support.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_step.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';

/// Inputs of a rendered note.
class NoteInput {
  const NoteInput({
    required this.recording,
    required this.extraction,
    required this.segments,
  });

  final RecordingRow recording;
  final ExtractionRow extraction;
  final List<TranscriptSegmentRow> segments;
}

/// Renders Markdown. EXP-01/02 replace the placeholder with Mustache
/// templates and safe YAML front-matter.
typedef NoteRenderer = String Function(NoteInput input);

String _placeholderRenderer(NoteInput input) {
  final title = input.recording.title.isEmpty
      ? 'Recording'
      : input.recording.title;
  final json = const JsonEncoder.withIndent('  ')
      .convert(input.extraction.json);
  return [
    '# $title',
    '',
    '```json',
    json,
    '```',
    '',
    '## Transcript',
    '',
    for (final s in input.segments) s.body,
    '',
  ].join('\n');
}

/// Renders the note to `rendered/<recording_id>.md` (atomic overwrite) and
/// replaces the extraction's action items.
class RenderStep implements PipelineStep {
  RenderStep({
    required this.db,
    required this.paths,
    NoteRenderer? renderer,
    this.loader,
  }) : renderer = renderer ?? _placeholderRenderer;

  final VaultVoiceDatabase db;
  final StoragePaths paths;
  final NoteRenderer renderer;

  /// Builds the renderer at job start (FND-11: built-ins + a DB snapshot of
  /// user profiles/templates); [renderer] is used when null.
  final NoteRendererLoader? loader;

  @override
  PipelineStepId get id => PipelineStepId.render;

  @override
  HeavyModel? get model => null;

  @override
  bool canRun(JobSnapshot job) => true;

  @override
  Future<StepResult> run(StepContext ctx) async {
    final job = ctx.job;
    final extraction = await db.extractionsRepository.get(
      extractionIdFor(job.id),
    );
    if (extraction case Err()) {
      return const StepFailed(
        StorageFailure('no extraction'),
        kind: FailureKind.permanent,
      );
    }
    final recording = unwrap(
      await db.recordingsRepository.get(job.recordingId),
    );
    final transcript = unwrap(
      await db.transcriptsRepository.latestFor(job.recordingId),
    );
    final segments = transcript == null
        ? const <TranscriptSegmentRow>[]
        : unwrap(await db.transcriptsRepository.segments(transcript.id));
    final ext = extraction.valueOrNull!;
    final render = loader == null ? renderer : await loader!();
    final markdown = render(
      NoteInput(recording: recording, extraction: ext, segments: segments),
    );
    await writeFileAtomic(paths.renderedFile(job.recordingId), markdown);
    ctx.reportProgress(1);
    final items = [
      for (final item in _actionItems(ext.json))
        ActionItemsCompanion.insert(
          recordingId: job.recordingId,
          extractionId: ext.id,
          body: item,
        ),
    ];
    return StepSucceeded(
      commit: () async {
        unwrap(
          await db.extractionsRepository.replaceActionItems(ext.id, items),
        );
      },
    );
  }

  static List<String> _actionItems(Map<String, Object?> json) {
    final raw = json['action_items'];
    if (raw is! List<Object?>) return const [];
    return [
      for (final e in raw)
        if (e is String)
          e
        else if (e is Map<String, Object?> && e['text'] is String)
          e['text']! as String,
    ];
  }
}

/// Writes the rendered note into the first vault target and records the
/// export (outbox row per recording × target). EXP-05/06 add routing rules
/// and the retrying outbox.
///
/// The note path comes from EXP-02's [FilenamePattern] (profile pattern →
/// `export.filename_pattern` setting → default) and [planExport] with the
/// stable identity from `exports` ([ExportIdentity]): a re-export updates
/// the same file, unchanged content is not rewritten, a foreign file is
/// never replaced (collision mode setting, default `suffix`).
class WriteStep implements PipelineStep {
  WriteStep({
    required this.db,
    required this.paths,
    required this.vault,
    this.clock = const SystemClock(),
    this.vaultFor,
    this.profiles,
  });

  final VaultVoiceDatabase db;
  final StoragePaths paths;

  /// Writer used for every target when [vaultFor] is null.
  final VaultWriter vault;
  final Clock clock;

  /// The writer of one configured target (FND-11).
  final VaultWriterFor? vaultFor;

  /// Profile lookup for the profile's own filename pattern.
  final ProfileLookup? profiles;

  @override
  PipelineStepId get id => PipelineStepId.write;

  @override
  HeavyModel? get model => null;

  @override
  bool canRun(JobSnapshot job) => true;

  @override
  Future<StepResult> run(StepContext ctx) async {
    final job = ctx.job;
    final targets = await db.vaultRepository.watchTargets().first;
    if (targets.isEmpty) return const StepWaiting(WaitingReason.destination);
    final target = targets.first;
    final writer = vaultFor?.call(target) ?? vault;

    final file = File(paths.renderedFile(job.recordingId));
    if (!file.existsSync()) {
      return const StepFailed(
        StorageFailure('no rendered note'),
        kind: FailureKind.permanent,
      );
    }
    final markdown = await file.readAsString();
    final hash = fnv1a32(markdown);
    final recording = unwrap(
      await db.recordingsRepository.get(job.recordingId),
    );
    final extraction = (await db.extractionsRepository.get(
      extractionIdFor(job.id),
    )).valueOrNull;
    final profileId = extraction?.profileId ?? recording.profileId ?? 'note';
    final profile = await profiles?.call(profileId);
    final pattern = await _pattern(profile?.filenamePattern);
    final extractedTitle = extraction?.json['title'];
    final title = extractedTitle is String && extractedTitle.trim().isNotEmpty
        ? extractedTitle
        : recording.title.trim().isEmpty
        ? null
        : recording.title;
    final desired = pattern.renderPath(
      FilenameValues(
        recordingId: job.recordingId,
        createdAt: recording.createdAt.toLocal(),
        profileId: profileId,
        title: title,
      ),
    );
    final identity = await ExportIdentity.load(
      db.vaultRepository,
      recordingId: job.recordingId,
      targetId: target.id,
    );
    final planned = await planExport(
      desired: desired,
      contentHash: hash,
      mode: await _collisionMode(),
      exists: writer.exists,
      prior: identity.prior,
      claimedByOthers: identity.claimedByOthers,
    );
    final ExportPlan plan;
    switch (planned) {
      case Err(:final failure):
        return StepFailed(failure);
      case Ok(:final value):
        plan = value;
    }
    if (plan case WritePlan(:final overwrite)) {
      final written = await writer.write(
        NoteDraft(relativePath: plan.relPath, markdown: markdown),
        overwrite: overwrite,
      );
      if (written case Err(:final failure)) return StepFailed(failure);
    }
    ctx.reportProgress(1);
    // `skip` mode left a taken path alone: nothing was exported.
    if (plan.reason == PlanReason.skippedCollision) {
      return const StepSucceeded();
    }
    final wrote = plan is WritePlan;
    final previousAttempts = await _attempts(job.recordingId, target.id);
    return StepSucceeded(
      commit: () async {
        unwrap(
          await db.vaultRepository.upsertExport(
            ExportsCompanion.insert(
              id: '${job.recordingId}.${target.id}',
              recordingId: job.recordingId,
              targetId: target.id,
              relPath: plan.relPath,
              contentHash: hash,
              status: ExportStatus.written,
              attempts: Value(previousAttempts + (wrote ? 1 : 0)),
              updatedAt: clock.now(),
            ),
          ),
        );
      },
    );
  }

  Future<int> _attempts(String recordingId, String targetId) async {
    final row =
        await (db.select(db.exports)..where(
              (e) =>
                  e.recordingId.equals(recordingId) &
                  e.targetId.equals(targetId),
            ))
            .getSingleOrNull();
    return row?.attempts ?? 0;
  }

  /// Profile pattern, else the setting, else the default; an invalid
  /// pattern (validated on save, so only a stale/foreign value) falls back.
  Future<FilenamePattern> _pattern(String? profilePattern) async {
    final setting = (await db.settingsRepository.get(
      SettingKeys.exportFilenamePattern,
    )).valueOrNull;
    for (final source in [
      profilePattern,
      if (setting is String) setting,
      kDefaultFilenamePattern,
    ]) {
      if (source == null || source.trim().isEmpty) continue;
      if (FilenamePattern.parse(source) case Ok(:final value)) return value;
    }
    return FilenamePattern.parse(kDefaultFilenamePattern).valueOrNull!;
  }

  Future<CollisionMode> _collisionMode() async {
    final v = (await db.settingsRepository.get(SettingKeys.exportCollisionMode))
        .valueOrNull;
    return CollisionMode.values.firstWhere(
      (m) => m.name == v,
      orElse: () => CollisionMode.suffix,
    );
  }
}
