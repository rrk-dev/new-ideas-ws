import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/diarization_engine.dart';
import 'package:vaultvoice/core/platform/vad_engine.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_engines.dart';
import 'package:vaultvoice/features/pipeline/data/steps/step_support.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_step.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';
import 'package:vaultvoice/features/transcription/domain/speaker_alignment.dart';

/// Speaker labels for the transcript (STT-05), after STT and before
/// extraction. Optional per profile (`stt.diarization`, else the
/// `processing.diarization_default` setting, default off): when off the step
/// is a no-op and the transcript keeps `speaker = null`.
///
/// Turns from the [DiarizationEngine] are aligned to the Whisper segments
/// (max overlap, split at token boundaries on a long speaker change) and
/// written with the anonymous labels "Speaker 1…N" (numbered by first
/// appearance) in one transaction with the job's move to the next step, so a
/// kill never leaves half-labelled transcripts. Re-running replaces the
/// speakers (old display names belong to the old clustering).
///
/// No voiceprints: the engine's embeddings never leave the engine; the
/// step's scratch directory is deleted in every outcome, and nothing but
/// anonymous labels and the user's display names is stored.
class DiarizeStep implements PipelineStep {
  DiarizeStep({
    required this.db,
    required this.paths,
    required this.engine,
    required this.config,
    this.profiles,
  });

  final VaultVoiceDatabase db;
  final StoragePaths paths;
  final DiarizationEngine engine;
  final PipelineConfig config;
  final ProfileLookup? profiles;

  @override
  PipelineStepId get id => PipelineStepId.diarize;

  /// The diarization models are small and run between STT and LLM; they are
  /// loaded and freed by the engine itself.
  @override
  HeavyModel? get model => null;

  @override
  bool canRun(JobSnapshot job) => true;

  /// Label for 0-based display index [i].
  static String labelFor(int i) => 'Speaker ${i + 1}';

  /// (enabled, requested speaker count).
  Future<(bool, int?)> _options(RecordingRow recording) async {
    final profile = await profiles?.call(
      recording.profileId ?? config.defaultProfileId,
    );
    final stt = profile?.stt;
    var enabled = stt?.diarization;
    if (enabled == null) {
      final v = await db.settingsRepository.get(
        SettingKeys.processingDiarization,
      );
      enabled = switch (v) {
        Ok(:final value) => value is bool && value,
        Err() => false,
      };
    }
    return (enabled, stt?.numSpeakers);
  }

  @override
  Future<StepResult> run(StepContext ctx) async {
    final job = ctx.job;
    final recording = unwrap(
      await db.recordingsRepository.get(job.recordingId),
    );
    final (enabled, numSpeakers) = await _options(recording);
    if (!enabled) return const StepSucceeded();

    final transcript = unwrap(
      await db.transcriptsRepository.latestFor(job.recordingId),
    );
    if (transcript == null) return const StepSucceeded();
    final segments = unwrap(
      await db.transcriptsRepository.segments(transcript.id),
    );
    if (segments.isEmpty) return const StepSucceeded();

    final chunks = await db.recordingsRepository
        .watchChunks(job.recordingId)
        .first;
    if (chunks.isEmpty) {
      return const StepFailed(
        StorageFailure('no audio chunks'),
        kind: FailureKind.permanent,
      );
    }
    final speech = await db.recordingsRepository
        .watchSpeechSegments(job.recordingId)
        .first;

    final scratch = Directory(p.join(paths.workDir(job.id), 'diarization'));
    final List<SpeakerTurn> turns;
    try {
      await scratch.create(recursive: true);
      final result = await engine.diarize(
        [
          for (final c in chunks)
            (path: paths.resolve(c.path), startMs: c.startMs, endMs: c.endMs),
        ],
        speechSpans: [for (final s in speech) SpeechSpan(s.startMs, s.endMs)],
        numSpeakers: numSpeakers,
        scratchDir: scratch.path,
        cancel: ctx.cancel,
        onProgress: ctx.reportProgress,
      );
      switch (result) {
        case Err(:final failure):
          return StepFailed(failure);
        case Ok(:final value):
          turns = value;
      }
    } finally {
      if (scratch.existsSync()) scratch.deleteSync(recursive: true);
    }
    if (turns.isEmpty) return const StepSucceeded();

    final pieces = alignSpeakers([
      for (final s in segments)
        AlignSegment(
          id: s.id,
          startMs: s.startMs,
          endMs: s.endMs,
          body: s.body,
          // A user-edited segment keeps its text: never split it.
          tokensJson: s.originalText == null ? s.tokensJson : null,
        ),
    ], turns);

    final order = <int>[];
    for (final piece in pieces) {
      final sp = piece.speaker;
      if (sp != null && !order.contains(sp)) order.add(sp);
    }
    String? label(int? sp) => sp == null ? null : labelFor(order.indexOf(sp));
    final labels = [for (var i = 0; i < order.length; i++) labelFor(i)];
    ctx.reportProgress(1);
    return StepSucceeded(
      commit: () async {
        unwrap(
          await db.transcriptsRepository.applyDiarization(transcript.id, [
            for (final x in pieces)
              (
                sourceId: x.sourceId,
                startMs: x.startMs,
                endMs: x.endMs,
                body: x.body,
                tokensJson: x.tokensJson,
                speaker: label(x.speaker),
                isSplit: x.isSplit,
              ),
          ]),
        );
        unwrap(
          await db.recordingsRepository.replaceSpeakers(
            job.recordingId,
            labels,
          ),
        );
      },
    );
  }
}
