import 'package:flutter_riverpod/misc.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/ask/data/ask_providers.dart';
import 'package:vaultvoice/features/library/data/library_providers.dart';
import 'package:vaultvoice/features/library/data/recording_deleter.dart';
import 'package:vaultvoice/features/library/data/search_repository.dart';
import 'package:vaultvoice/features/library/domain/library_models.dart';
import 'package:vaultvoice/features/library/domain/recording_detail.dart';

final DateTime libraryT0 = DateTime.utc(2026, 10, 12, 9, 30);

/// Three recordings in different states.
List<LibraryItem> sampleLibrary() => [
  LibraryItem(
    id: 'rec-a',
    title: 'Weekly planning',
    createdAt: libraryT0,
    duration: const Duration(minutes: 23, seconds: 5),
    status: LibraryStatus.exported,
    profileId: 'meeting',
    tags: const ['team'],
    exports: [
      ExportInfo(
        targetId: 'v1',
        targetName: 'Obsidian',
        relPath: 'Meetings/2026-10-12-planning.md',
        written: true,
        failed: false,
        updatedAt: libraryT0,
      ),
    ],
  ),
  LibraryItem(
    id: 'rec-b',
    title: 'Dishwasher warranty',
    createdAt: libraryT0.subtract(const Duration(days: 1)),
    duration: const Duration(minutes: 2, seconds: 40),
    status: LibraryStatus.processing,
    profileId: 'warranty',
  ),
  LibraryItem(
    id: 'rec-c',
    title: '',
    createdAt: libraryT0.subtract(const Duration(days: 3)),
    duration: const Duration(seconds: 42),
    status: LibraryStatus.failed,
  ),
];

const List<TranscriptLine> sampleLines = [
  TranscriptLine(
    startMs: 5000,
    endMs: 11000,
    text: 'Let’s lock the API version today.',
    speaker: 'Priya',
  ),
  TranscriptLine(
    startMs: 12000,
    endMs: 19000,
    text: 'I’ll update the client SDK by Friday.',
    speaker: 'Sam',
  ),
  TranscriptLine(
    startMs: 20000,
    endMs: 26000,
    text: 'Who owns the migration guide?',
    speaker: 'Priya',
  ),
];

final ExtractionView sampleExtraction = ExtractionView(
  id: 'e1',
  profileId: 'meeting',
  profileVersion: 1,
  modelId: 'qwen',
  valid: true,
  createdAt: libraryT0,
  data: const {
    'title': 'API version decision',
    'summary': 'The team agreed on API v2.',
    'attendees': ['Priya', 'Sam'],
    'action_items': [
      {'task': 'Update the client SDK', 'owner': 'Sam', 'due': 'Friday'},
    ],
  },
);

/// [SearchRepository] answering from a fixed hit list.
class FakeSearchRepository implements SearchRepository {
  FakeSearchRepository([this.hits = const {}]);

  /// Query (lower-case) → hits.
  final Map<String, List<SearchHit>> hits;
  final queries = <String>[];

  @override
  Future<Result<List<SearchHit>>> search(
    String input, {
    int limit = 500,
  }) async {
    queries.add(input);
    return Ok(hits[input.trim().toLowerCase()] ?? const []);
  }
}

/// Records deletions.
class FakeRecordingDeleter implements RecordingDeleter {
  final calls = <({String id, bool notes})>[];

  @override
  Future<Result<RecordingDeletion>> delete(
    String recordingId, {
    required bool deleteExportedNotes,
  }) async {
    calls.add((id: recordingId, notes: deleteExportedNotes));
    return Ok(
      RecordingDeletion(
        notesDeleted: deleteExportedNotes ? 1 : 0,
        notesKept: deleteExportedNotes ? 0 : 1,
      ),
    );
  }
}

/// Hermetic Library / recording-detail data for widget, golden and
/// accessibility tests.
List<Override> libraryOverrides({
  List<LibraryItem>? items,
  FakeSearchRepository? search,
  FakeRecordingDeleter? deleter,
  String detailId = 'rec-a',
  List<ActionItemView> actionItems = const [],
  ExtractionView? extraction,
  List<TranscriptLine>? lines,
  bool askEnabled = false,
}) {
  final all = items ?? sampleLibrary();
  final detail = all.where((i) => i.id == detailId).firstOrNull;
  return [
    askEnabledProvider.overrideWithValue(askEnabled),
    libraryItemsProvider.overrideWith((ref) => Stream.value(all)),
    searchRepositoryProvider.overrideWithValue(
      search ?? FakeSearchRepository(),
    ),
    profileNamesProvider.overrideWith(
      (ref) => Stream.value(const {
        'meeting': 'Meeting Action Items',
        'warranty': 'Warranty & Receipt',
      }),
    ),
    recordingHeaderProvider(detailId).overrideWith(
      (ref) => Stream.value(
        detail == null
            ? null
            : RecordingHeader(
                id: detail.id,
                title: detail.title,
                createdAt: detail.createdAt,
                duration: detail.duration,
                tags: detail.tags,
                imported: false,
                profileId: detail.profileId,
              ),
      ),
    ),
    recordingTranscriptProvider(detailId)
        .overrideWith((ref) => Stream.value(lines ?? sampleLines)),
    recordingExtractionProvider(detailId)
        .overrideWith((ref) => Stream.value(extraction ?? sampleExtraction)),
    recordingExportsProvider(detailId)
        .overrideWith((ref) => Stream.value(detail?.exports ?? const [])),
    recordingDeleterProvider.overrideWith(
      (ref) async => deleter ?? FakeRecordingDeleter(),
    ),
    actionItemsProvider(openOnly: true)
        .overrideWith((ref) => Stream.value(actionItems)),
    actionItemsProvider(openOnly: false)
        .overrideWith((ref) => Stream.value(actionItems)),
  ];
}
