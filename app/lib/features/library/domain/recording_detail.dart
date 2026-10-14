import 'package:flutter/foundation.dart';

/// Header facts of one recording (detail screen).
@immutable
final class RecordingHeader {
  const RecordingHeader({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.duration,
    required this.tags,
    required this.imported,
    this.profileId,
  });

  final String id;

  /// User content: displayed, never logged.
  final String title;
  final DateTime createdAt;
  final Duration duration;
  final List<String> tags;
  final bool imported;
  final String? profileId;
}

/// One timed transcript line (read-only view; STT-06 owns editing).
@immutable
final class TranscriptLine {
  const TranscriptLine({
    required this.startMs,
    required this.endMs,
    required this.text,
    this.speaker,
  });

  final int startMs;
  final int endMs;

  /// User content: displayed, never logged.
  final String text;
  final String? speaker;
}

/// The newest extraction of a recording.
@immutable
final class ExtractionView {
  const ExtractionView({
    required this.id,
    required this.profileId,
    required this.profileVersion,
    required this.modelId,
    required this.data,
    required this.valid,
    required this.createdAt,
  });

  final String id;
  final String profileId;
  final int profileVersion;
  final String modelId;

  /// Extracted JSON (user content).
  final Map<String, Object?> data;
  final bool valid;
  final DateTime createdAt;
}

/// An action item across recordings (`action_items`).
@immutable
final class ActionItemView {
  const ActionItemView({
    required this.id,
    required this.recordingId,
    required this.recordingTitle,
    required this.body,
    required this.done,
    this.owner,
    this.due,
    this.tMs,
  });

  final int id;
  final String recordingId;

  /// User content: displayed, never logged.
  final String recordingTitle;
  final String body;
  final bool done;
  final String? owner;
  final String? due;
  final int? tMs;
}

/// `[h:]mm:ss` for a position in milliseconds.
String formatTimestamp(int ms) {
  final total = ms ~/ 1000;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}
