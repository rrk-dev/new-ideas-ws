import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/platform/stt_engine.dart';

/// Window transcripts produced while the recording was still running
/// (near-real-time mode, STT-04). The transcribe step reuses an entry only
/// when the window's audio key *and* the decode parameters match, so a
/// changed model/language or a re-planned window is transcribed again.
abstract interface class WindowResultCache {
  Future<List<TranscriptSegment>?> lookup(
    String recordingId,
    String windowKey,
    String paramsKey,
  );

  Future<void> store(
    String recordingId,
    String windowKey,
    String paramsKey,
    List<TranscriptSegment> segments,
  );

  /// Drops everything for [recordingId] (job finished / recording deleted).
  Future<void> clear(String recordingId);
}

/// No cache (near-real-time mode off).
class NoWindowResultCache implements WindowResultCache {
  const NoWindowResultCache();

  @override
  Future<List<TranscriptSegment>?> lookup(String r, String w, String k) async =>
      null;

  @override
  Future<void> store(
    String r,
    String w,
    String k,
    List<TranscriptSegment> s,
  ) async {}

  @override
  Future<void> clear(String recordingId) async {}
}

/// JSON file per recording under `<root>/work/live/<recordingId>.json`
/// (app-private storage, excluded from backup like the rest of `work/`).
/// Transcript text is user content: it never leaves this file / the DB and
/// is never logged.
class FileWindowResultCache implements WindowResultCache {
  FileWindowResultCache(this.root);

  /// Storage root (`StoragePaths.root`).
  final String root;

  File _file(String recordingId) {
    if (!RegExp(r'^[A-Za-z0-9_.-]{1,64}$').hasMatch(recordingId) ||
        recordingId.contains('..')) {
      throw ArgumentError.value(recordingId, 'recordingId');
    }
    return File(p.join(root, 'work', 'live', '$recordingId.json'));
  }

  Future<Map<String, Object?>> _read(String recordingId) async {
    final f = _file(recordingId);
    if (!f.existsSync()) return {};
    try {
      final doc = jsonDecode(await f.readAsString());
      return doc is Map<String, Object?> ? doc : {};
    } on FormatException {
      return {}; // torn write: recompute
    }
  }

  @override
  Future<List<TranscriptSegment>?> lookup(
    String recordingId,
    String windowKey,
    String paramsKey,
  ) async {
    final doc = await _read(recordingId);
    final entry = doc['$paramsKey#$windowKey'];
    if (entry is! List) return null;
    return [
      for (final s in entry.whereType<Map<String, Object?>>())
        TranscriptSegment(
          start: Duration(milliseconds: (s['t0'] as num?)?.toInt() ?? 0),
          end: Duration(milliseconds: (s['t1'] as num?)?.toInt() ?? 0),
          text: s['text'] as String? ?? '',
          avgLogprob: (s['lp'] as num?)?.toDouble(),
          noSpeechProb: (s['ns'] as num?)?.toDouble(),
          tokens: [
            for (final t
                in (s['tok'] as List?)?.whereType<Map<String, Object?>>() ??
                    const <Map<String, Object?>>[])
              TranscriptToken(
                text: t['text'] as String? ?? '',
                p: (t['p'] as num?)?.toDouble() ?? 0,
              ),
          ],
        ),
    ];
  }

  @override
  Future<void> store(
    String recordingId,
    String windowKey,
    String paramsKey,
    List<TranscriptSegment> segments,
  ) async {
    final doc = await _read(recordingId);
    doc['$paramsKey#$windowKey'] = [
      for (final s in segments)
        {
          't0': s.start.inMilliseconds,
          't1': s.end.inMilliseconds,
          'text': s.text,
          'lp': s.avgLogprob,
          'ns': s.noSpeechProb,
          'tok': [
            for (final t in s.tokens) {'text': t.text, 'p': t.p},
          ],
        },
    ];
    final f = _file(recordingId);
    await f.parent.create(recursive: true);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(doc), flush: true);
    await tmp.rename(f.path);
  }

  @override
  Future<void> clear(String recordingId) async {
    final f = _file(recordingId);
    if (f.existsSync()) await f.delete();
  }
}
