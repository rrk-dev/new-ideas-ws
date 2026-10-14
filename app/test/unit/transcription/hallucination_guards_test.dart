import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/platform/stt_engine.dart';
import 'package:vaultvoice/features/transcription/domain/hallucination_guards.dart';

TranscriptSegment _s(String text, {double? noSpeech, double? logprob}) =>
    TranscriptSegment(
      start: Duration.zero,
      end: const Duration(seconds: 2),
      text: text,
      noSpeechProb: noSpeech,
      avgLogprob: logprob,
    );

void main() {
  group('hallucination / repetition guards (STT-04)', () {
    test('no-speech guard needs BOTH high no_speech_prob and low logprob', () {
      expect(
        guardSegment(_s('Okay so', noSpeech: 0.9, logprob: -1.5)),
        GuardReason.noSpeech,
      );
      expect(guardSegment(_s('Okay so', noSpeech: 0.9, logprob: -0.5)), isNull);
      expect(guardSegment(_s('Okay so', noSpeech: 0.3, logprob: -1.5)), isNull);
      expect(
        guardSegment(_s('Okay so', noSpeech: 0.6, logprob: -1.01)),
        isNull,
      );
      expect(guardSegment(_s('Okay so')), isNull);
    });

    test('known hallucination phrases (whole segment only)', () {
      for (final t in [
        'Thank you for watching!',
        'Thanks for watching.',
        ' you',
        'Subtitles by the Amara.org community',
        '[BLANK_AUDIO]',
        'Please subscribe.',
      ]) {
        expect(guardSegment(_s(t)), GuardReason.knownPhrase, reason: t);
      }
      // Real speech containing the words is kept.
      expect(
        guardSegment(_s('Thank you for watching the demo, Priya.')),
        isNull,
      );
      expect(guardSegment(_s('Thank you.')), isNull);
      expect(guardSegment(_s('Did you send it?')), isNull);
    });

    test('repetition loop: the same 3-gram 4 times', () {
      const loop = 'we will we will we will we will we will';
      expect(hasRepetitionLoop(loop), isTrue);
      expect(guardSegment(_s(loop)), GuardReason.repetitionLoop);
      expect(
        hasRepetitionLoop('and then and then and then we left'), // 3×
        isFalse,
      );
      expect(
        hasRepetitionLoop(
          'I think so. I think so. I think so. I think so, really.',
        ),
        isTrue,
      );
    });

    test('duplicate of the previous segment', () {
      expect(
        guardSegment(
          _s('The budget is approved.'),
          previous: 'The budget is approved',
        ),
        GuardReason.duplicate,
      );
      expect(
        guardSegment(_s('The budget is approved.'), previous: 'Next topic'),
        isNull,
      );
    });

    test('zlib compression ratio > 2.4', () {
      final degenerate = 'la ' * 40; // compresses far better than speech
      expect(compressionRatio(degenerate), greaterThan(2.4));
      final normal =
          'Marcus will own the Android crash fix and report back on Thursday.';
      expect(compressionRatio(normal), lessThan(2.4));
      // Words repeated without a repeated 3-gram run: only the ratio catches it.
      final ratioOnly = List.generate(
        30,
        (i) => 'na${i % 2 == 0 ? '' : 'h'}',
      ).join(' ');
      expect(hasRepetitionLoop(ratioOnly), isTrue); // 3-gram also repeats
      expect(guardSegment(_s(degenerate)), isNotNull);
      expect(
        guardSegment(_s('${'abcdefghij' * 12} plus unique tail words here')),
        GuardReason.compressionRatio,
      );
    });

    test(
      'applyGuards keeps order, counts drops, duplicates across windows',
      () {
        final r = applyGuards([
          _s('Hello team.'),
          _s('Hello team.'),
          _s('Thanks for watching!'),
          _s('   '),
          _s('Next item is the budget.'),
        ], previous: 'Hello team');
        expect(r.kept.map((s) => s.text), ['Next item is the budget.']);
        expect(r.dropped, {
          GuardReason.duplicate: 2,
          GuardReason.knownPhrase: 1,
        });
      },
    );

    test('carryPrompt: vocabulary + ~200-char tail cut at a word', () {
      expect(carryPrompt(), isNull);
      expect(carryPrompt(vocabulary: 'VaultVoice, Priya'), 'VaultVoice, Priya');
      final long = List.generate(80, (i) => 'word$i').join(' ');
      final p = carryPrompt(vocabulary: 'Acme', previousText: long)!;
      expect(p, startsWith('Acme word'));
      expect(p.length, lessThanOrEqualTo(4 + 1 + 200));
      expect(p, endsWith('word79'));
      expect(carryPrompt(previousText: 'short'), 'short');
    });
  });
}
