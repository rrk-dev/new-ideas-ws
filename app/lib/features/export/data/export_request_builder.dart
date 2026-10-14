import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/export/data/vault_exporter.dart';
import 'package:vaultvoice/features/export/domain/filename_pattern.dart';
import 'package:vaultvoice/features/export/domain/routing_engine.dart';
import 'package:vaultvoice/features/templates/domain/note_context.dart'
    show timestamp;

/// Collects the routing facts and filename values of a recording from the
/// database (used by `WriteStep`). [extraction] is the job's extraction
/// (null when extraction did not run); [fallbackProfileId] is used when
/// neither the extraction nor the recording names a profile.
Future<ExportRequest> buildExportRequest(
  VaultVoiceDatabase db, {
  required String recordingId,
  required String markdown,
  required String fallbackProfileId,
  ExtractionRow? extraction,
}) async {
  final recording = switch (await db.recordingsRepository.get(recordingId)) {
    Ok(:final value) => value,
    Err(:final failure) => throw StateError(failure.message),
  };
  final json = extraction?.json ?? const <String, Object?>{};
  final profileId =
      extraction?.profileId ?? recording.profileId ?? fallbackProfileId;
  final title = _text(json['title']) ?? _text(recording.title);
  final speakers = await db.recordingsRepository
      .watchSpeakers(recordingId)
      .first;
  final profile = (await db.profilesRepository.getProfile(profileId))
      .valueOrNull;

  final transcript = (await db.transcriptsRepository.latestFor(recordingId))
      .valueOrNull;
  final segments = transcript == null
      ? const <TranscriptSegmentRow>[]
      : (await db.transcriptsRepository.segments(transcript.id)).valueOrNull ??
            const <TranscriptSegmentRow>[];
  final names = {for (final s in speakers) s.label: s.displayName ?? s.label};

  return ExportRequest(
    recordingId: recordingId,
    markdown: markdown,
    routing: RoutingInput(
      profileId: profileId,
      title: title,
      summary: _text(json['summary']),
      tags: [
        ...recording.tags,
        if (json['tags'] case final List<Object?> tags)
          for (final t in tags)
            if (t is String) t,
      ],
      speakers: [for (final s in speakers) s.displayName ?? s.label],
      // PRF-06 (auto classification) does not persist its result yet, so
      // `classifiedProfileId` stays unset and the `classification_any`
      // matcher is inert until it does (follow-up EXP-09).
      profileDefaultTargetId: _defaultTarget(profile?.definition),
    ),
    filename: FilenameValues(
      recordingId: recordingId,
      createdAt: recording.createdAt.toLocal(),
      profileId: profileId,
      title: title,
    ),
    transcriptMarkdown: segments.isEmpty
        ? null
        : transcriptSidecarMarkdown(
            title: title,
            lines: [
              for (final s in segments)
                (
                  startMs: s.startMs,
                  speaker: s.speaker == null
                      ? null
                      : names[s.speaker] ?? s.speaker,
                  text: s.body,
                ),
            ],
          ),
  );
}

/// The transcript sidecar (`<note>.transcript.md`): a heading and one
/// `[hh:mm:ss] Speaker: text` line per segment. Line breaks inside a
/// segment are collapsed so each segment stays one Markdown line.
String transcriptSidecarMarkdown({
  required String? title,
  required List<({int startMs, String? speaker, String text})> lines,
}) {
  final b = StringBuffer()
    ..writeln('# ${_oneLine(title ?? 'Transcript')}')
    ..writeln();
  for (final l in lines) {
    final who = l.speaker == null ? '' : '${_oneLine(l.speaker!)}: ';
    b
      ..writeln('[${timestamp(l.startMs)}] $who${_oneLine(l.text)}')
      ..writeln();
  }
  return b.toString();
}

String _oneLine(String s) => s.replaceAll(RegExp(r'\s*[\r\n]+\s*'), ' ').trim();

String? _text(Object? v) => v is String && v.trim().isNotEmpty ? v : null;

String? _defaultTarget(Map<String, Object?>? definition) {
  final routing = definition?['routing'];
  if (routing is! Map) return null;
  return _text(routing['default_target']);
}
