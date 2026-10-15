import 'package:drift/drift.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_guard.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/library/domain/library_models.dart';

/// Full-text search over the FTS5 `search_index` (APP-02): recording titles
/// and tags, transcripts and extracted fields. Terms come from [ftsTerms],
/// so user input never reaches FTS syntax.
class SearchRepository {
  SearchRepository(this._db);

  final VaultVoiceDatabase _db;

  /// Best hit per recording for [input], most relevant first; empty for
  /// blank input. A recording matches when every term occurs in it (title,
  /// tags, any transcript segment or the extracted fields). At most [limit]
  /// recordings.
  Future<Result<List<SearchHit>>> search(String input, {int limit = 500}) {
    final terms = ftsTerms(input);
    if (terms.isEmpty) return Future.value(const Ok(<SearchHit>[]));
    // Recordings containing every term (each term may be in another row),
    // then the matching rows of those recordings ranked by bm25.
    final everyTerm = List.filled(
      terms.length,
      'SELECT recording_id FROM search_index WHERE search_index MATCH ?',
    ).join(' INTERSECT ');
    return guardDb(() async {
      final rows = await _db
          .customSelect(
            'SELECT recording_id, kind, '
            "snippet(search_index, 2, ?, ?, '…', 12) AS snip, "
            'bm25(search_index) AS rank '
            'FROM search_index WHERE search_index MATCH ? '
            'AND recording_id IN ($everyTerm) '
            'ORDER BY rank',
            variables: [
              const Variable(kSnippetOpen),
              const Variable(kSnippetClose),
              Variable(terms.join(' OR ')),
              for (final t in terms) Variable(t),
            ],
          )
          .get();
      final best = <String, SearchHit>{};
      for (final r in rows) {
        final id = r.read<String>('recording_id');
        if (best.containsKey(id)) continue;
        best[id] = SearchHit(
          recordingId: id,
          kind: r.read<String>('kind'),
          snippet: r.read<String>('snip'),
          rank: r.read<double>('rank'),
        );
        if (best.length == limit) break;
      }
      return best.values.toList();
    });
  }
}
