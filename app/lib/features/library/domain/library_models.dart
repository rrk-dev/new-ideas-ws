import 'package:flutter/foundation.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';

/// Where a recording is, as the Library shows it (APP-02).
enum LibraryStatus {
  /// Still being captured (or interrupted and not yet recovered).
  recording,

  /// Captured, never queued for processing.
  recorded,

  /// In the pipeline (queued, running, paused).
  processing,

  /// Parked until something clears (model download, review, folder access).
  waiting,

  /// Processed; the note is not (yet) in a vault folder.
  processed,

  /// The note was written to at least one vault folder.
  exported,

  /// Processing or export failed.
  failed,
}

/// One export of a recording's note (export history).
@immutable
final class ExportInfo {
  const ExportInfo({
    required this.targetId,
    required this.targetName,
    required this.relPath,
    required this.written,
    required this.failed,
    required this.updatedAt,
  });

  final String targetId;

  /// Folder name (user content: shown, never logged).
  final String targetName;
  final String relPath;
  final bool written;
  final bool failed;
  final DateTime updatedAt;
}

/// A recording in the Library list.
@immutable
final class LibraryItem {
  const LibraryItem({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.duration,
    required this.status,
    this.profileId,
    this.tags = const [],
    this.exports = const [],
    this.job,
  });

  final String id;

  /// User content: displayed, never logged.
  final String title;
  final DateTime createdAt;
  final Duration duration;
  final LibraryStatus status;

  /// Profile chosen for the recording, or of its newest extraction.
  final String? profileId;
  final List<String> tags;
  final List<ExportInfo> exports;

  /// The job that represents its processing (in the pipeline, else newest).
  final JobSnapshot? job;

  /// Folders the note was written to.
  List<String> get exportedTo => [
    for (final e in exports)
      if (e.written) e.targetName,
  ];
}

/// Library status from the recording, its representative job and exports.
LibraryStatus libraryStatus({
  required bool capturing,
  required JobSnapshot? job,
  required List<ExportInfo> exports,
}) {
  if (capturing) return LibraryStatus.recording;
  if (job != null) {
    switch (job.state) {
      case JobState.failed:
        return LibraryStatus.failed;
      case JobState.waiting:
        return LibraryStatus.waiting;
      case JobState.cancelled || JobState.done:
        break;
      case JobState.queued ||
          JobState.transcribing ||
          JobState.transcribed ||
          JobState.diarizing ||
          JobState.classifying ||
          JobState.extracting ||
          JobState.extracted ||
          JobState.rendering ||
          JobState.rendered ||
          JobState.writing ||
          JobState.paused:
        return LibraryStatus.processing;
    }
  }
  if (exports.any((e) => e.failed)) return LibraryStatus.failed;
  if (exports.any((e) => e.written)) return LibraryStatus.exported;
  if (job?.state == JobState.done) return LibraryStatus.processed;
  return LibraryStatus.recorded;
}

enum LibrarySort { newest, oldest, longest, title }

/// Library filters (all optional; empty = everything).
@immutable
final class LibraryFilter {
  const LibraryFilter({
    this.query = '',
    this.profileId,
    this.tag,
    this.statuses = const {},
    this.from,
    this.to,
    this.sort = LibrarySort.newest,
  });

  /// Full-text query (title, tags, transcripts, extracted fields).
  final String query;
  final String? profileId;
  final String? tag;
  final Set<LibraryStatus> statuses;

  /// Inclusive local-date range on `createdAt`.
  final DateTime? from;
  final DateTime? to;
  final LibrarySort sort;

  bool get hasFilters =>
      profileId != null ||
      tag != null ||
      statuses.isNotEmpty ||
      from != null ||
      to != null;

  LibraryFilter copyWith({
    String? query,
    String? Function()? profileId,
    String? Function()? tag,
    Set<LibraryStatus>? statuses,
    DateTime? Function()? from,
    DateTime? Function()? to,
    LibrarySort? sort,
  }) => LibraryFilter(
    query: query ?? this.query,
    profileId: profileId != null ? profileId() : this.profileId,
    tag: tag != null ? tag() : this.tag,
    statuses: statuses ?? this.statuses,
    from: from != null ? from() : this.from,
    to: to != null ? to() : this.to,
    sort: sort ?? this.sort,
  );
}

/// Applies [filter] to [items]. [matches] are the full-text hits (recording
/// id → rank, lower = better) or null when there is no query; with a query,
/// only hits are kept and the newest-first sort becomes relevance order.
List<LibraryItem> applyLibraryFilter(
  List<LibraryItem> items,
  LibraryFilter filter, {
  Map<String, double>? matches,
}) {
  final from = filter.from;
  final to = filter.to;
  final kept = [
    for (final i in items)
      if ((matches == null || matches.containsKey(i.id)) &&
          (filter.profileId == null || i.profileId == filter.profileId) &&
          (filter.tag == null || i.tags.contains(filter.tag)) &&
          (filter.statuses.isEmpty || filter.statuses.contains(i.status)) &&
          (from == null || !i.createdAt.toLocal().isBefore(_day(from))) &&
          (to == null ||
              i.createdAt.toLocal().isBefore(
                _day(to).add(const Duration(days: 1)),
              )))
        i,
  ];
  int byNewest(LibraryItem a, LibraryItem b) {
    final c = b.createdAt.compareTo(a.createdAt);
    return c != 0 ? c : a.id.compareTo(b.id);
  }

  kept.sort(switch (filter.sort) {
    LibrarySort.newest when matches != null => (a, b) {
      final c = matches[a.id]!.compareTo(matches[b.id]!);
      return c != 0 ? c : byNewest(a, b);
    },
    LibrarySort.newest => byNewest,
    LibrarySort.oldest => (a, b) => -byNewest(a, b),
    LibrarySort.longest => (a, b) {
      final c = b.duration.compareTo(a.duration);
      return c != 0 ? c : byNewest(a, b);
    },
    // Untitled recordings go last.
    LibrarySort.title => (a, b) {
      final ea = a.title.trim().isEmpty;
      final eb = b.title.trim().isEmpty;
      if (ea != eb) return ea ? 1 : -1;
      final c = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      return c != 0 ? c : byNewest(a, b);
    },
  });
  return kept;
}

DateTime _day(DateTime d) {
  final l = d.toLocal();
  return DateTime(l.year, l.month, l.day);
}

/// FTS5 terms for free text typed by the user (empty when it holds no
/// searchable term). Every term is quoted, so FTS operators such as `"`,
/// `*`, `-`, `AND`, `NEAR` are taken literally, and the last one is a prefix
/// query so results appear while typing. A recording matches when it
/// contains every term (in any of its rows).
List<String> ftsTerms(String input) {
  final terms = [
    for (final t in input.split(RegExp(r'\s+')))
      if (t.replaceAll('"', '').trim().isNotEmpty)
        '"${t.replaceAll('"', '""')}"',
  ];
  if (terms.isNotEmpty) terms[terms.length - 1] = '${terms.last}*';
  return terms;
}

/// A full-text hit: where in the recording the query matched.
@immutable
final class SearchHit {
  const SearchHit({
    required this.recordingId,
    required this.kind,
    required this.snippet,
    required this.rank,
  });

  final String recordingId;

  /// `title`, `transcript` or `extraction`.
  final String kind;

  /// Matched text with [kSnippetOpen] / [kSnippetClose] around matches.
  final String snippet;

  /// bm25 rank (lower = more relevant).
  final double rank;
}

/// Markers FTS5 `snippet()` puts around matched terms (control characters
/// cannot occur in transcript text).
const kSnippetOpen = '\u0002';
const kSnippetClose = '\u0003';
