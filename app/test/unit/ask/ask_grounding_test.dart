import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/ask/domain/ask_models.dart';
import 'package:vaultvoice/features/ask/domain/ask_prompt.dart';

AskPassage _p(String rec, int tMs, String text, {String? speaker}) =>
    AskPassage(
      recordingId: rec,
      tMs: tMs,
      text: text,
      kind: AskPassageKind.transcript,
      recordedAt: DateTime(2026, 3, 2),
      speaker: speaker,
    );

ParsedAskAnswer _answer(String text, List<(String, int)> cites) =>
    ParsedAskAnswer(
      answer: text,
      citations: [for (final (r, t) in cites) Citation(recordingId: r, tMs: t)],
    );

void main() {
  final passages = [
    _p('w1', 0, 'Recording the receipt for my new headphones.'),
    _p('w1', 3000, 'Bought at Adventure Audio on Monday.'),
    _p('w1', 9000, 'Headphones come with two cables.'),
  ];

  test('[ASK-03/AC2] a citation the answer cannot be traced to is replaced '
      'by the passage that supports it', () {
    final out = groundAskAnswer(
      'Which store sold me the headphones?',
      _answer('Adventure Audio', [('w1', 0)]),
      passages,
    );
    expect(out.citations.map((c) => c.tMs), [3000]);
    expect(out.found, isTrue);
  });

  test('[ASK-03/AC2] unsupported extra citations are dropped and at most '
      'three are kept', () {
    final out = groundAskAnswer(
      'Which store sold me the headphones?',
      _answer('Adventure Audio', [('w1', 3000), ('w1', 0), ('w1', 9000)]),
      passages,
    );
    expect(out.citations.map((c) => c.tMs), [3000]);
  });

  test('[ASK-03/AC2] a name in the question is checked against passage '
      'text, titles and speaker labels, not only "Name:" prefixes', () {
    final withSpeaker = [
      _p('r', 0, 'The beta ships on the ninth.', speaker: 'Priya'),
    ];
    final answer = _answer('The ninth', [('r', 0)]);
    expect(
      groundAskAnswer(
        'What did Priya say about the beta?',
        answer,
        withSpeaker,
      ).found,
      isTrue,
    );
    final noSpeaker = [_p('r', 0, 'The beta ships on the ninth.')];
    expect(
      groundAskAnswer(
        'What did Priya say about the beta?',
        answer,
        noSpeaker,
      ).found,
      isFalse,
    );
  });

  test('[ASK-03/AC2] a citation from a recording that never mentions the '
      'name in the question is dropped', () {
    final two = [
      _p(
        'a',
        0,
        'We built a mobile version nobody asked for.',
        speaker: 'Chloe',
      ),
      _p(
        'b',
        0,
        'We built a mobile version nobody asked for.',
        speaker: 'Gita',
      ),
    ];
    final out = groundAskAnswer(
      'What did Chloe say about the mobile version?',
      _answer('A mobile version nobody asked for', [('a', 0), ('b', 0)]),
      two,
    );
    expect(out.citations.map((c) => c.recordingId), ['a']);
  });
}
