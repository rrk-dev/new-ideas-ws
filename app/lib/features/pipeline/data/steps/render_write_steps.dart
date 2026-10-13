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
import 'package:vaultvoice/features/pipeline/data/steps/step_support.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_step.dart';

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
  RenderStep({required this.db, required this.paths, NoteRenderer? renderer})
    : renderer = renderer ?? _placeholderRenderer;

  final VaultVoiceDatabase db;
  final StoragePaths paths;
  final NoteRenderer renderer;

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
    final markdown = renderer(
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
/// export (outbox row per recording × target). EXP-05/06 add routing rules,
/// filename patterns and the retrying outbox.
class WriteStep implements PipelineStep {
  WriteStep({
    required this.db,
    required this.paths,
    required this.vault,
    this.clock = const SystemClock(),
  });

  final VaultVoiceDatabase db;
  final StoragePaths paths;
  final VaultWriter vault;
  final Clock clock;

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

    final file = File(paths.renderedFile(job.recordingId));
    if (!file.existsSync()) {
      return const StepFailed(
        StorageFailure('no rendered note'),
        kind: FailureKind.permanent,
      );
    }
    final markdown = await file.readAsString();
    final hash = fnv1a32(markdown);
    final relPath = '${job.recordingId}.md';
    final existing =
        await (db.select(db.exports)..where(
              (e) =>
                  e.recordingId.equals(job.recordingId) &
                  e.targetId.equals(target.id),
            ))
            .getSingleOrNull();
    final alreadyWritten =
        existing != null &&
        existing.status == ExportStatus.written &&
        existing.contentHash == hash;

    if (!alreadyWritten) {
      final written = await vault.write(
        NoteDraft(relativePath: relPath, markdown: markdown),
      );
      if (written case Err(:final failure)) return StepFailed(failure);
    }
    ctx.reportProgress(1);
    return StepSucceeded(
      commit: () async {
        unwrap(
          await db.vaultRepository.upsertExport(
            ExportsCompanion.insert(
              id: '${job.recordingId}.${target.id}',
              recordingId: job.recordingId,
              targetId: target.id,
              relPath: relPath,
              contentHash: hash,
              status: ExportStatus.written,
              attempts: Value(
                (existing?.attempts ?? 0) + (alreadyWritten ? 0 : 1),
              ),
              updatedAt: clock.now(),
            ),
          ),
        );
      },
    );
  }
}
