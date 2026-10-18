import 'package:flutter/foundation.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';

/// Inclusive calendar-day range (local time) of a date filter.
@immutable
final class AskDateRange {
  const AskDateRange(this.start, this.end);

  final DateTime start;
  final DateTime end;

  DateTime get startInclusive => DateTime(start.year, start.month, start.day);

  /// First instant after the range.
  DateTime get endExclusive => DateTime(end.year, end.month, end.day + 1);

  @override
  bool operator ==(Object other) =>
      other is AskDateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// One question. [recordingId] scopes the Ask to a single recording; the
/// other filters are explicit (UI chips) and merge with the ones parsed from
/// the question text.
@immutable
final class AskRequest {
  const AskRequest({
    required this.question,
    this.recordingId,
    this.profileId,
    this.tags = const [],
    this.dateRange,
    this.threadId,
  });

  final String question;
  final String? recordingId;
  final String? profileId;
  final List<String> tags;
  final AskDateRange? dateRange;

  /// Appends the turn to this stored thread (new thread when null).
  final String? threadId;
}

enum AskPassageKind { transcript, title, extraction }

/// A retrieved piece of a recording. Its [text] is user content: never
/// log it.
@immutable
final class AskPassage {
  const AskPassage({
    required this.recordingId,
    required this.tMs,
    required this.text,
    required this.kind,
    required this.recordedAt,
    this.title = '',
    this.segmentId,
  });

  final String recordingId;
  final int tMs;
  final String text;
  final AskPassageKind kind;
  final DateTime recordedAt;
  final String title;
  final int? segmentId;

  /// `HH:MM:SS`, the form the model cites and the validator compares.
  String get timestamp => formatAskTimestamp(tMs);

  String get key => '$recordingId|$timestamp';
}

String formatAskTimestamp(int ms) {
  final s = ms ~/ 1000;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(s ~/ 3600)}:${two(s % 3600 ~/ 60)}:${two(s % 60)}';
}

/// A validated reference to a retrieved passage.
@immutable
final class Citation {
  const Citation({required this.recordingId, required this.tMs});

  final String recordingId;
  final int tMs;

  String get timestamp => formatAskTimestamp(tMs);

  @override
  bool operator ==(Object other) =>
      other is Citation &&
      other.recordingId == recordingId &&
      other.timestamp == timestamp;

  @override
  int get hashCode => Object.hash(recordingId, timestamp);
}

enum AskOutcome {
  /// The model answered and at least one valid citation survived.
  answered,

  /// Nothing relevant: "I couldn't find that in your notes."
  notFound,

  /// The model could not run now (busy pipeline, memory, cancelled
  /// residency); the retrieved passages are shown instead.
  retrievalOnly,
}

const String kAskNotFoundText = "I couldn't find that in your notes.";

@immutable
final class AskAnswer {
  const AskAnswer({
    required this.outcome,
    required this.answer,
    this.citations = const [],
    this.passages = const [],
    this.turnId,
    this.threadId,
  });

  final AskOutcome outcome;
  final String answer;

  /// Only citations that point to a passage in [passages].
  final List<Citation> citations;
  final List<AskPassage> passages;
  final String? turnId;
  final String? threadId;
}

/// Answers questions about the library, on device only (ADR-ASK-02).
abstract interface class AskEngine {
  Future<Result<AskAnswer>> ask(AskRequest request, {CancelToken? cancel});
}
