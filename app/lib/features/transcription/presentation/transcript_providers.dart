import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/pipeline/data/job_mapper.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_providers.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/transcription/data/just_audio_transcript_player.dart';
import 'package:vaultvoice/features/transcription/data/recording_audio_source.dart';
import 'package:vaultvoice/features/transcription/domain/transcript_player.dart';
import 'package:vaultvoice/features/transcription/domain/transcript_view.dart';

part 'transcript_providers.g.dart';

/// Everything the transcript screen shows for one recording.
@immutable
final class TranscriptViewData {
  const TranscriptViewData({
    required this.transcriptId,
    required this.edited,
    required this.segments,
    required this.markers,
  });

  final String transcriptId;

  /// The user changed at least one segment.
  final bool edited;

  /// Sorted by start time.
  final List<TranscriptSegmentView> segments;
  final List<TranscriptMarkerView> markers;

  List<TranscriptItem> get items => interleaveMarkers(segments, markers);
}

/// Id + edited flag of the newest transcript (provider-friendly: generated
/// drift row classes cannot appear in provider signatures).
@immutable
final class TranscriptMeta {
  const TranscriptMeta({required this.id, required this.edited});

  final String id;
  final bool edited;

  @override
  bool operator ==(Object other) =>
      other is TranscriptMeta && other.id == id && other.edited == edited;

  @override
  int get hashCode => Object.hash(id, edited);
}

@riverpod
Stream<TranscriptMeta?> latestTranscript(Ref ref, String recordingId) => ref
    .watch(transcriptsRepositoryProvider)
    .watchLatestFor(recordingId)
    .map((t) => t == null ? null : TranscriptMeta(id: t.id, edited: t.edited));

/// Segments of one transcript (speaker = raw label), sorted by start.
@riverpod
Stream<List<TranscriptSegmentView>> transcriptSegments(
  Ref ref,
  String transcriptId,
) => ref
    .watch(transcriptsRepositoryProvider)
    .watchSegments(transcriptId)
    .map(
      (rows) => [
        for (final r in rows)
          TranscriptSegmentView(
            id: r.id,
            seq: r.seq,
            startMs: r.startMs,
            endMs: r.endMs,
            text: r.body,
            originalText: r.originalText,
            speaker: r.speaker,
            tokens: parseTokensJson(r.tokensJson),
          ),
      ]..sort((a, b) => a.startMs.compareTo(b.startMs)),
    );

/// Timeline markers shown in the transcript. Consent markers are
/// bookkeeping (SEC-09), not timeline content.
@riverpod
Stream<List<TranscriptMarkerView>> transcriptMarkers(
  Ref ref,
  String recordingId,
) => ref
    .watch(recordingsRepositoryProvider)
    .watchMarkers(recordingId)
    .map(
      (rows) => [
        for (final m in rows)
          if (_markerKind(m.kind) case final kind?)
            TranscriptMarkerView(
              id: m.id,
              atMs: m.atMs,
              label: m.label,
              kind: kind,
            ),
      ],
    );

/// Speaker label → display name (renames from STT-05/APP).
@riverpod
Stream<Map<String, String>> speakerNames(Ref ref, String recordingId) => ref
    .watch(recordingsRepositoryProvider)
    .watchSpeakers(recordingId)
    .map((rows) => {for (final s in rows) s.label: s.displayName ?? s.label});

/// The newest transcript of [recordingId] with its segments, speaker names
/// and user markers; null before the first transcription.
@riverpod
Future<TranscriptViewData?> transcriptView(Ref ref, String recordingId) async {
  final t = await ref.watch(latestTranscriptProvider(recordingId).future);
  if (t == null) return null;
  final segments = await ref.watch(transcriptSegmentsProvider(t.id).future);
  final markers = await ref.watch(
    transcriptMarkersProvider(recordingId).future,
  );
  final names = await ref.watch(speakerNamesProvider(recordingId).future);
  return TranscriptViewData(
    transcriptId: t.id,
    edited: t.edited,
    segments: [
      for (final s in segments) s.withSpeaker(names[s.speaker] ?? s.speaker),
    ],
    markers: markers,
  );
}

TranscriptMarkerKind? _markerKind(MarkerKind k) => switch (k) {
  MarkerKind.user => TranscriptMarkerKind.user,
  MarkerKind.gap => TranscriptMarkerKind.gap,
  MarkerKind.callInterruption => TranscriptMarkerKind.callInterruption,
  MarkerKind.consent => null,
};

/// Creates the audio player (tests override with a fake).
@riverpod
TranscriptPlayerFactory transcriptPlayerFactory(Ref ref) =>
    JustAudioTranscriptPlayer.new;

/// Playback of [recordingId]'s chunks; disposed with the screen.
@riverpod
Future<TranscriptPlayback> transcriptPlayback(
  Ref ref,
  String recordingId,
) async {
  final paths = await ref.watch(storagePathsProvider.future);
  final chunks = switch (await ref
      .watch(recordingsRepositoryProvider)
      .chunksOf(recordingId)) {
    Ok(:final value) => value,
    Err(:final failure) => throw StateError(failure.message),
  };
  final timeline = await loadPlaybackTimeline([
    for (final c in chunks) (path: paths.resolve(c.path), startMs: c.startMs),
  ]);
  final playback = TranscriptPlayback(
    ref.watch(transcriptPlayerFactoryProvider)(),
    timeline,
  );
  ref.onDispose(playback.dispose);
  return playback;
}

/// Edits and re-extraction for the transcript screen. Kept alive: commands
/// outlive the widget that started them (a dialog closes mid-write).
@Riverpod(keepAlive: true)
TranscriptEditor transcriptEditor(Ref ref, String recordingId) =>
    TranscriptEditor(ref, recordingId);

class TranscriptEditor {
  TranscriptEditor(this._ref, this.recordingId);

  final Ref _ref;
  final String recordingId;

  /// Inline edit; the first pre-edit text stays in `original_text`.
  Future<Result<void>> editSegment(int segmentId, String text) => _ref
      .read(transcriptsRepositoryProvider)
      .editSegment(segmentId, text.trim());

  /// Find & replace across this transcript only. Returns the number of
  /// segments changed.
  Future<Result<int>> replaceAll(
    TranscriptViewData view,
    String find,
    String replacement, {
    bool caseSensitive = false,
  }) async {
    final edits = replaceInTranscript(
      view.segments,
      find,
      replacement,
      caseSensitive: caseSensitive,
    );
    if (edits.isEmpty) return const Ok(0);
    final r = await _ref
        .read(transcriptsRepositoryProvider)
        .editSegments(view.transcriptId, edits);
    return r.map((_) => edits.length);
  }

  /// Re-runs extraction (and everything after it) on the edited transcript
  /// via the pipeline (`rerun(fromStep: extract)`); STT does not run again.
  Future<Result<void>> reExtract() async {
    final rows = await _ref
        .read(jobsRepositoryProvider)
        .watchForRecording(recordingId)
        .first;
    final jobs = [for (final r in rows) jobFromRow(r)];
    if (jobs.isEmpty) {
      return const Err(UnsupportedFeatureFailure('re-extract without a job'));
    }
    final newest = jobs.reduce(
      (a, b) => b.createdAt.isAfter(a.createdAt) ? b : a,
    );
    final client = await _ref.read(pipelineClientProvider.future);
    return await client.rerun(newest.id, PipelineStepId.extract);
  }
}
