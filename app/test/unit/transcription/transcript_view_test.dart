import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/transcription/domain/transcript_view.dart';

TranscriptSegmentView _seg(
  int id,
  int start,
  int end,
  String text, {
  String? original,
  List<SegmentToken> tokens = const [],
}) => TranscriptSegmentView(
  id: id,
  seq: id,
  startMs: start,
  endMs: end,
  text: text,
  originalText: original,
  tokens: tokens,
);

void main() {
  group('[STT-06/AC1] user markers sit at their positions', () {
    final segments = [
      _seg(1, 0, 4000, 'one'),
      _seg(2, 5000, 9000, 'two'),
      _seg(3, 12000, 15000, 'three'),
    ];

    List<String> order(List<TranscriptMarkerView> markers) => [
      for (final i in interleaveMarkers(segments, markers))
        switch (i) {
          SegmentItem(:final segment) => 's${segment.id}',
          MarkerItem(:final marker) => 'm${marker.atMs}',
        },
    ];

    test('inside a segment → after it; in a pause → between; at a start → '
        'before; before/after everything', () {
      expect(
        order(const [
          TranscriptMarkerView(id: 1, atMs: 2000), // inside s1
          TranscriptMarkerView(id: 2, atMs: 4500), // pause s1|s2
          TranscriptMarkerView(id: 3, atMs: 12000), // exactly at s3 start
          TranscriptMarkerView(id: 4, atMs: 20000), // after the end
        ]),
        ['s1', 'm2000', 'm4500', 's2', 'm12000', 's3', 'm20000'],
      );
      expect(order(const [TranscriptMarkerView(id: 5, atMs: 0)]), [
        'm0',
        's1',
        's2',
        's3',
      ]);
    });

    test('input order does not matter; every marker appears once', () {
      final items = interleaveMarkers(segments.reversed.toList(), const [
        TranscriptMarkerView(id: 2, atMs: 10000),
        TranscriptMarkerView(id: 1, atMs: 1000),
      ]);
      expect(items.map((i) => i.atMs).toList(), [0, 1000, 5000, 10000, 12000]);
      // Positions are monotonic on the recording timeline.
      for (var i = 1; i < items.length; i++) {
        expect(items[i].atMs, greaterThanOrEqualTo(items[i - 1].atMs));
      }
    });
  });

  group('current-segment highlight', () {
    final segments = [
      _seg(1, 1000, 4000, 'a'),
      _seg(2, 5000, 9000, 'b'),
      _seg(3, 9000, 15000, 'c'),
    ];
    test('maps playback position to the segment index', () {
      expect(activeSegmentIndex(segments, 0), -1);
      expect(activeSegmentIndex(segments, 1000), 0);
      expect(activeSegmentIndex(segments, 4500), 0); // gap keeps previous
      expect(activeSegmentIndex(segments, 5000), 1);
      expect(activeSegmentIndex(segments, 8999), 1);
      expect(activeSegmentIndex(segments, 9000), 2);
      expect(activeSegmentIndex(segments, 99000), 2);
      expect(activeSegmentIndex(const [], 10), -1);
    });
  });

  group('low-confidence highlighting from tokens_json', () {
    test('parses tokens_json and tolerates bad JSON', () {
      expect(
        parseTokensJson('[{"text":" Hi","p":0.9,"t0_ms":0,"t1_ms":10}]')
            .single
            .p,
        0.9,
      );
      expect(parseTokensJson(null), isEmpty);
      expect(parseTokensJson('{oops'), isEmpty);
      expect(parseTokensJson('{"a":1}'), isEmpty);
      expect(parseTokensJson('[{"text":1}]'), isEmpty);
    });

    test('marks tokens with p < 0.5 and merges adjacent ones', () {
      const text = 'Priya said the Andriod build';
      final tokens = [
        const SegmentToken(text: '[_BEG_]', p: 0.1),
        const SegmentToken(text: ' Pri', p: 0.3),
        const SegmentToken(text: 'ya', p: 0.4),
        const SegmentToken(text: ' said', p: 0.95),
        const SegmentToken(text: ' the', p: 0.99),
        const SegmentToken(text: ' And', p: 0.2),
        const SegmentToken(text: 'riod', p: 0.7),
        const SegmentToken(text: ' build', p: 0.5),
      ];
      final r = lowConfidenceRanges(text, tokens);
      expect(
        [for (final x in r) text.substring(x.start, x.end)],
        ['Priya', 'And'],
      );
    });

    test('edited segments show no stale confidence', () {
      final tokens = [const SegmentToken(text: ' word', p: 0.1)];
      expect(_seg(1, 0, 1, 'word', tokens: tokens).lowConfidence, hasLength(1));
      final edited = _seg(1, 0, 1, 'fixed', original: 'word', tokens: tokens);
      expect(edited.edited, isTrue);
      expect(edited.lowConfidence, isEmpty);
    });
  });

  group('find & replace', () {
    final segments = [
      _seg(1, 0, 1, 'Ask Jon about the Jon Doe ticket'),
      _seg(2, 1, 2, 'jon agreed'),
      _seg(3, 2, 3, 'nothing here'),
    ];

    test('finds case-insensitively by default', () {
      expect(findInTranscript(segments, 'jon'), hasLength(3));
      expect(findInTranscript(segments, 'Jon', caseSensitive: true), [
        (segmentId: 1, start: 4, end: 7),
        (segmentId: 1, start: 18, end: 21),
      ]);
      expect(findInTranscript(segments, ''), isEmpty);
    });

    test('replace-all edits only matching segments, literally', () {
      expect(replaceInTranscript(segments, 'jon', r'John $1'), {
        1: r'Ask John $1 about the John $1 Doe ticket',
        2: r'John $1 agreed',
      });
      expect(
        replaceInTranscript(segments, 'Jon', 'John', caseSensitive: true),
        {1: 'Ask John about the John Doe ticket'},
      );
      expect(replaceInTranscript(segments, 'a.b', 'x'), isEmpty);
      expect(replaceInTranscript(segments, '', 'x'), isEmpty);
    });
  });
}
