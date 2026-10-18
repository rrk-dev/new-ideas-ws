import 'package:drift/drift.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_guard.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/ask/domain/ask_models.dart';
import 'package:vaultvoice/features/ask/domain/ask_query.dart';
import 'package:vaultvoice/features/ask/domain/ask_retriever.dart';

/// FTS5 retrieval over the app's `search_index` (APP-02) with the scope and
/// date filters as SQL, so another recording's passage can never be returned
/// for a per-recording Ask.
final class DbAskRetriever implements AskRetriever {
  DbAskRetriever(this.db, {this.k = 10, this.expandTop = 3});

  final VaultVoiceDatabase db;

  /// Candidate count (ADR-ASK-02: 10).
  final int k;

  /// How many top transcript hits also bring their ±1 neighbour segments.
  final int expandTop;

  static const int _maxBodyChars = 600;

  @override
  Future<Result<List<AskPassage>>> retrieve(AskQuery query) =>
      guardDb(() async {
        final filters = <String>[];
        final args = <Variable<Object>>[];
        if (query.recordingId case final id?) {
          filters.add('r.id = ?');
          args.add(Variable<String>(id));
        }
        if (query.range case final range?) {
          filters.add('r.created_at >= ? AND r.created_at < ?');
          args
            ..add(Variable<int>(range.startInclusive.millisecondsSinceEpoch))
            ..add(Variable<int>(range.endExclusive.millisecondsSinceEpoch));
        }
        if (query.profileId case final id?) {
          filters.add('r.profile_id = ?');
          args.add(Variable<String>(id));
        }
        for (final tag in query.tags) {
          filters.add(
            'EXISTS (SELECT 1 FROM json_each(r.tags) WHERE lower(value) = ?)',
          );
          args.add(Variable<String>(tag));
        }
        final where = filters.isEmpty ? '' : ' AND ${filters.join(' AND ')}';

        final match = query.ftsMatch;
        if (match == null) {
          return query.dateOnly
              ? await _recordingsIn(where, args)
              : <AskPassage>[];
        }
        final rows = await db
            .customSelect(
              'SELECT s.rowid AS rid, s.recording_id AS rec, s.kind AS kind, '
              's.body AS body, r.title AS title, r.created_at AS created '
              'FROM search_index AS s JOIN recordings AS r '
              'ON r.id = s.recording_id WHERE search_index MATCH ?$where '
              'ORDER BY bm25(search_index) LIMIT ?',
              variables: [Variable<String>(match), ...args, Variable<int>(k)],
            )
            .get();
        // The period is the only usable clue ("the lecture on Friday"): list
        // that period's recordings, as for a date-only question.
        if (rows.isEmpty && query.range != null) {
          return await _recordingsIn(where, args);
        }

        final ranked = <AskPassage>[];
        final seen = <String>{};
        var expanded = 0;
        for (final row in rows) {
          final kind = row.read<String>('kind');
          final rec = row.read<String>('rec');
          final created = DateTime.fromMillisecondsSinceEpoch(
            row.read<int>('created'),
          );
          final title = row.read<String>('title');
          if (kind == 'transcript') {
            final segmentId = -row.read<int>('rid');
            final seg = await _segment(segmentId);
            if (seg == null) continue;
            final hit = AskPassage(
              recordingId: rec,
              tMs: seg.startMs,
              text: row.read<String>('body'),
              kind: AskPassageKind.transcript,
              recordedAt: created,
              title: title,
              segmentId: segmentId,
              speaker: seg.speaker,
            );
            if (seen.add('s$segmentId')) ranked.add(hit);
            if (expanded < expandTop) {
              expanded++;
              for (final n in await _neighbours(seg, rec, created, title)) {
                if (seen.add('s${n.segmentId}')) ranked.add(n);
              }
            }
          } else {
            if (!seen.add('$kind|$rec')) continue;
            ranked.add(
              AskPassage(
                recordingId: rec,
                tMs: 0,
                text: _clip(row.read<String>('body')),
                kind: kind == 'title'
                    ? AskPassageKind.title
                    : AskPassageKind.extraction,
                recordedAt: created,
                title: title,
              ),
            );
          }
        }
        return ranked;
      });

  Future<List<AskPassage>> _recordingsIn(
    String where,
    List<Variable<Object>> args,
  ) async {
    final rows = await db
        .customSelect(
          'SELECT r.id AS rec, r.title AS title, r.created_at AS created, '
          '(SELECT body FROM search_index WHERE recording_id = r.id AND '
          "kind = 'extraction' LIMIT 1) AS body "
          'FROM recordings AS r WHERE 1 = 1$where '
          'ORDER BY r.created_at DESC LIMIT ?',
          variables: [...args, Variable<int>(k)],
        )
        .get();
    return [
      for (final row in rows)
        AskPassage(
          recordingId: row.read<String>('rec'),
          tMs: 0,
          text: _clip(row.readNullable<String>('body') ?? ''),
          kind: AskPassageKind.extraction,
          recordedAt: DateTime.fromMillisecondsSinceEpoch(
            row.read<int>('created'),
          ),
          title: row.read<String>('title'),
        ),
    ];
  }

  Future<_Seg?> _segment(int id) async {
    final row = await db
        .customSelect(
          'SELECT transcript_id AS t, seq, start_ms AS s, speaker '
          'FROM transcript_segments WHERE id = ?',
          variables: [Variable<int>(id)],
        )
        .getSingleOrNull();
    if (row == null) return null;
    return (
      transcriptId: row.read<String>('t'),
      seq: row.read<int>('seq'),
      startMs: row.read<int>('s'),
      speaker: row.readNullable<String>('speaker'),
    );
  }

  Future<List<AskPassage>> _neighbours(
    _Seg seg,
    String rec,
    DateTime created,
    String title,
  ) async {
    final rows = await db
        .customSelect(
          'SELECT id, start_ms AS s, speaker, body FROM transcript_segments '
          'WHERE transcript_id = ? AND seq IN (?, ?) ORDER BY seq',
          variables: [
            Variable<String>(seg.transcriptId),
            Variable<int>(seg.seq - 1),
            Variable<int>(seg.seq + 1),
          ],
        )
        .get();
    return [
      for (final r in rows)
        AskPassage(
          recordingId: rec,
          tMs: r.read<int>('s'),
          text: r.read<String>('body'),
          kind: AskPassageKind.transcript,
          recordedAt: created,
          title: title,
          segmentId: r.read<int>('id'),
          speaker: r.readNullable<String>('speaker'),
        ),
    ];
  }

  static String _clip(String s) =>
      s.length <= _maxBodyChars ? s : '${s.substring(0, _maxBodyChars)}…';
}

typedef _Seg = ({String transcriptId, int seq, int startMs, String? speaker});
