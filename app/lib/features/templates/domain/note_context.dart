import 'package:vaultvoice/features/profiles/domain/render_context.dart';
import 'package:vaultvoice/features/templates/domain/template_lambdas.dart';

/// A speaker label and its optional display name.
typedef SpeakerName = ({String label, String? name});

/// One transcript line for the `transcript` context root.
typedef SegmentInput = ({int startMs, String? speaker, String text});

/// A user marker (`[hh:mm:ss] label`).
typedef MarkerInput = ({int atMs, String? label, String kind});

String _two(int v) => v.toString().padLeft(2, '0');

/// `hh:mm:ss` of [ms] (hours not wrapped).
String timestamp(int ms) {
  final s = (ms < 0 ? 0 : ms) ~/ 1000;
  return '${_two(s ~/ 3600)}:${_two((s % 3600) ~/ 60)}:${_two(s % 60)}';
}

/// ISO-8601 with an explicit UTC offset (`2026-10-13T14:05:00+02:00`).
String isoWithOffset(DateTime t) {
  final offset = t.isUtc ? Duration.zero : t.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final o = offset.abs();
  final date =
      '${t.year.toString().padLeft(4, '0')}-${_two(t.month)}-${_two(t.day)}';
  final time = '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';
  return '${date}T$time$sign${_two(o.inHours)}:${_two(o.inMinutes % 60)}';
}

/// The `meta` root of the rendering context (profile spec → "Rendering
/// context passed to templates"). [createdAt] is shown in its own time
/// zone (pass local time); `date`/`time` are always `YYYY-MM-DD`/`HH:mm`.
Map<String, Object?> buildNoteMeta({
  required String recordingId,
  required DateTime createdAt,
  required int durationMs,
  required String profileId,
  required String profileName,
  required String appVersion,
  String? title,
  List<SpeakerName> speakers = const [],
  List<String> tags = const [],
  List<MarkerInput> markers = const [],
  String? sttModel,
  String? llmModel,
  String? device,
  DateTime? consentAt,
}) => {
  'recording_id': recordingId,
  'title': title,
  'date':
      '${createdAt.year.toString().padLeft(4, '0')}-'
      '${_two(createdAt.month)}-${_two(createdAt.day)}',
  'time': '${_two(createdAt.hour)}:${_two(createdAt.minute)}',
  'duration_ms': durationMs,
  'duration_human': formatDuration(durationMs),
  'profile_id': profileId,
  'profile_name': profileName,
  'speakers': [
    for (final s in speakers) {'label': s.label, 'name': s.name},
  ],
  // Tags are stored without `#` (Obsidian convention).
  'tags': [
    for (final t in tags)
      if (t.replaceFirst(RegExp('^#+'), '').trim() case final tag
          when tag.isNotEmpty)
        tag,
  ],
  'markers': [
    for (final m in markers)
      {'t': timestamp(m.atMs), 'label': m.label, 'kind': m.kind},
  ],
  'model_ids': {'stt': sttModel, 'llm': llmModel},
  'app_version': appVersion,
  'device': device,
  'consent_at': consentAt == null ? null : isoWithOffset(consentAt),
};

/// The `transcript` root: `{segments: [{t, speaker, text}]}`.
Map<String, Object?> buildNoteTranscript(Iterable<SegmentInput> segments) => {
  'segments': [
    for (final s in segments)
      {'t': timestamp(s.startMs), 'speaker': s.speaker, 'text': s.text},
  ],
};

/// `data` shape of the `summary-only` fallback template, used when the
/// extraction is invalid or the profile is unknown (LLM-05): only an
/// optional `title` and free-text `summary`.
const MapShape kSummaryOnlyDataShape = MapShape(
  {
    'title': ScalarShape(ScalarKind.string, nullable: true),
    'summary': ScalarShape(ScalarKind.string, nullable: true),
  },
  helpersFor: {'title', 'summary'},
);

/// Root shape for the `summary-only` template (template check + render).
final MapShape kSummaryOnlyRootShape = MapShape({
  ContextKeys.data: kSummaryOnlyDataShape,
  ContextKeys.meta: kMetaShape,
  ContextKeys.transcript: kTranscriptShape,
}, helpersFor: kSummaryOnlyDataShape.helpersFor);

/// Normalizes a full context against [root] (same contract as PRF-01's
/// `buildRenderContext`, for shapes that are not a profile).
Map<String, Object?> normalizeContext(
  MapShape root, {
  required Map<String, Object?> data,
  required Map<String, Object?> meta,
  required Map<String, Object?> transcript,
}) {
  final dataShape = root.fields[ContextKeys.data]! as MapShape;
  final normalized = normalizeToShape(dataShape, data)! as Map<String, Object?>;
  return {
    ContextKeys.data: normalized,
    ContextKeys.meta: normalizeToShape(kMetaShape, meta),
    ContextKeys.transcript: normalizeToShape(kTranscriptShape, transcript),
    for (final f in root.helpersFor) 'has_$f': normalized['has_$f'],
  };
}
