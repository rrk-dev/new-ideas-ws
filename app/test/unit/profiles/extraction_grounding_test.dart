import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/profiles/domain/extraction_prompts.dart';
import 'package:vaultvoice/features/profiles/domain/post_processing.dart';
import 'package:vaultvoice/features/profiles/domain/prompt_builder.dart';
import 'package:vaultvoice/features/profiles/domain/transcript_grounding.dart';
import 'package:vv_native/vv_native.dart';

import 'profile_fixtures.dart';

/// Regression for "notes are not at all accurate" (Llama-3.2-1B copied the
/// few-shot example — "Sync strategy", change log, GET /changes, Omar, Lena —
/// into notes about unrelated recordings, then repeated one item until
/// `maxItems`). Real transcripts in these tests are synthetic.
const _transcript = '''
[00:00:00] Tenancy commitment for review.
[00:00:07] It answers the ask, commit to a tenancy model who trusts whom.
[00:00:44] Keep the sketch with three corrections and add the commitment below.
[00:00:50] The control plane cluster and the hub are the same thing.
[00:00:59] The hub is the tenant first, then team.
[00:01:08] Namespace, service account, role binding will be created.''';

PostProcessContext _context([String lines = _transcript]) =>
    PostProcessContext.fromTranscriptLines(lines, recordedAt: DateTime(2026));

/// Words of the old few-shot examples and of instruction examples that a
/// small model copied; none may appear in a built-in prompt outside the
/// transcript block.
const _leakWords = [
  'sync strategy',
  'change log',
  'cursor',
  'polling',
  'websocket',
  '/changes',
  'omar',
  'lena',
  'priya',
  'contoso',
  'northwind',
  'purifier',
  'x74b29',
  'api version decision',
  'migration guide',
  'client sdk',
  'users/{id}',
  'dishwasher',
  'next friday',
  'last tuesday',
];

String _outsideTranscript(String prompt) =>
    prompt.replaceAll(RegExp('<transcript>.*?</transcript>', dotAll: true), '');

String _lines(ExtractionPrompts p) => p.transcriptLines(const [
  PromptSegment(start: Duration.zero, speaker: 'S1', text: 'Plain words.'),
]);

void main() {
  const ids = ['meeting', 'warranty', 'engineering'];

  group('[PRF-02/AC1] built-in prompts carry no copyable example content', () {
    for (final id in ids) {
      test('$id: no few-shot examples, no example-domain words', () {
        final profile = builtinProfile(id);
        expect(profile.examples, isEmpty);
        final p = ExtractionPrompts(
          profile,
          metadata: PromptMetadata(
            recordedAt: DateTime(2026, 3, 2),
            duration: const Duration(minutes: 1),
            speakers: const [PromptSpeaker(label: 'S1')],
          ),
        );
        final prompt = '${p.systemPrompt}\n${p.singleUser(_lines(p))}';
        final outside = _outsideTranscript(prompt).toLowerCase();
        for (final w in _leakWords) {
          expect(outside, isNot(contains(w)), reason: '$id leaks "$w"');
        }
        expect(outside, isNot(contains('example')));
      });

      test('$id: tells the model to use only the transcript', () {
        final system = ExtractionPrompts(builtinProfile(id)).systemPrompt;
        expect(system, contains('Use only information that is stated'));
        expect(system, contains('if something is not stated, use [] or null'));
        expect(system, contains('List each item once'));
      });
    }

    test('the system prompt and the user turn carry the same rules', () {
      final user = ExtractionPrompts(builtinProfile('engineering'))
          .singleUser('[00:00:01] x');
      expect(user, contains('using only the transcript above'));
    });
  });

  test('[LLM-05/AC1] extraction sampler: low temperature, mild repeat '
      'penalty', () {
    const p = LlmGenParams.extraction(grammar: 'root ::= "x"');
    expect(p.temperature, 0.2);
    expect(p.repeatPenalty, 1.05);
    expect(p.repeatLastN, 64);
    expect(p.nPredict, 1024);
  });

  group('[PRF-05/AC1] caps bound what a looping model can emit', () {
    test('every built-in list has a small maxItems', () {
      for (final id in ids) {
        final json = builtinProfile(id).schema.toJson();
        final caps = <int>[];
        void walk(Object? n) {
          if (n is Map) {
            if (n['type'] == 'array') caps.add(n['maxItems']! as int);
            n.values.forEach(walk);
          } else if (n is List) {
            n.forEach(walk);
          }
        }

        walk(json);
        expect(caps, isNotEmpty);
        expect(
          caps.reduce((a, b) => a > b ? a : b),
          lessThanOrEqualTo(15),
          reason:
              '$id: an array cap over 15 lets a looping 1B model emit '
              'dozens of copies',
        );
      }
    });
  });

  group('[PRF-03/AC1] repetition loops are collapsed even if unlisted', () {
    test('20 copies of one question become one (profile does not list it)', () {
      final profile = builtinProfile('warranty');
      expect(
        profile.postProcess.map((p) => p.wireName),
        isNot(contains('dedupe_lists')),
      );
      final stats = GroundingStats();
      final out = applyPostProcessors(
        profile,
        {
          'notes': null,
          'support_contacts': [
            for (var i = 0; i < 20; i++) 'What is the commit?',
          ],
        },
        _context(),
        stats: stats,
      );
      expect(out['support_contacts'], ['What is the commit?']);
      expect(stats.duplicatesDropped, 19);
    });
  });

  group('[PRF-05/AC1] ground_to_transcript', () {
    final profile = builtinProfile('engineering');
    final engineeringStats = GroundingStats();

    Map<String, Object?> run(
      Map<String, Object?> extraction, [
      GroundingStats? s,
    ]) => applyPostProcessors(
      profile,
      extraction,
      _context(),
      stats: s ?? engineeringStats,
    );

    Map<String, Object?> base() => {
      'title': 'Tenancy commitment review',
      'context': 'Choosing the tenancy model for the clusters.',
      'concepts': <Object?>[],
      'api_designs': <Object?>[],
      'tradeoffs': <Object?>[],
      'decisions': <Object?>[],
      'todos': <Object?>[],
      'open_questions': <Object?>[],
    };

    test('copied example content is dropped, grounded content survives', () {
      final stats = GroundingStats();
      final out = run({
        ...base(),
        'title': 'Sync strategy',
        'context': 'Choosing how clients receive changes from the server.',
        'concepts': ['change log', 'cursor-based sync', 'namespace', 'hub'],
        'api_designs': [
          {
            'name': 'Changes feed',
            'description': 'Returns changes after a cursor.',
            'endpoints_or_signatures': ['GET /changes?since=cursor'],
          },
        ],
        'tradeoffs': [
          {
            'option': 'Polling',
            'pros': ['simple'],
            'cons': ['wastes battery'],
          },
          {
            'option': 'Hub',
            'pros': ['tenant first'],
            'cons': <Object?>[],
          },
        ],
        'decisions': ['Start with polling', 'The hub is the tenant first.'],
        'todos': [
          {
            'task': 'Sketch the GET /changes endpoint',
            'owner': 'Omar',
            't': '00:00:19',
          },
          {'task': 'Add the commitment', 'owner': 'Omar', 't': '00:00:44'},
        ],
        'open_questions': ['How long is the change log kept?'],
      }, stats);
      expect(out['concepts'], ['namespace', 'hub']);
      expect(out['api_designs'], isEmpty);
      expect(out['tradeoffs'], [
        {
          'option': 'Hub',
          'pros': ['tenant first'],
          'cons': <Object?>[],
        },
      ]);
      expect(out['decisions'], ['The hub is the tenant first.']);
      expect(out['open_questions'], isEmpty);
      final todos = out['todos']! as List;
      expect(todos, hasLength(1));
      expect((todos.single as Map)['task'], 'Add the commitment');
      expect(
        (todos.single as Map)['owner'],
        isNull,
        reason: 'nobody named Omar',
      );
      expect(stats.itemsDropped, greaterThanOrEqualTo(7));
      expect(stats.ownersCleared, greaterThanOrEqualTo(1));
    });

    test('a title/context not derived from the transcript is replaced', () {
      final stats = GroundingStats();
      final out = run({
        ...base(),
        'title': 'Sync strategy',
        'context': 'Choosing how clients receive changes from the server.',
      }, stats);
      expect(out['title'], 'Tenancy commitment for review');
      expect(out['context'], isNull, reason: 'nullable prose is dropped');
      expect(stats.proseReplaced, 2);
    });

    test('a title taken from the transcript is kept', () {
      final out = run({...base(), 'title': 'Tenancy commitment review'});
      expect(out['title'], 'Tenancy commitment review');
    });

    test('required prose falls back to the transcript start', () {
      final out = applyPostProcessors(builtinProfile('meeting'), {
        'title': 'Sprint demo',
        'summary': 'Quarterly revenue grew and the team shipped dashboards.',
        'attendees': ['Omar Haddad'],
        'decisions': <Object?>[],
        'action_items': <Object?>[],
        'open_questions': <Object?>[],
        'topics': ['revenue growth'],
      }, _context());
      expect(out['title'], 'Tenancy commitment for review');
      expect(
        out['summary'],
        startsWith('Tenancy commitment for review. It answers the ask'),
      );
      expect((out['summary']! as String).length, lessThanOrEqualTo(600));
      expect(out['attendees'], isEmpty);
      expect(out['topics'], isEmpty);
    });

    test('speaker names count as grounded owners and attendees', () {
      final out = applyPostProcessors(
        builtinProfile('meeting'),
        {
          'title': 'Tenancy commitment review',
          'summary': 'The hub is the tenant first, then team.',
          'attendees': ['Priya'],
          'decisions': <Object?>[],
          'action_items': [
            {
              'task': 'Add the commitment',
              'owner': 'Priya',
              'due': null,
              't': '00:00:44',
            },
          ],
          'open_questions': <Object?>[],
          'topics': <Object?>[],
        },
        PostProcessContext.fromTranscriptLines(
          '[00:00:44] Priya: Add the commitment below.',
          recordedAt: DateTime(2026),
        ),
      );
      expect(out['attendees'], ['Priya']);
      expect(((out['action_items']! as List).single as Map)['owner'], 'Priya');
    });

    test('no transcript text → nothing is dropped', () {
      final out = applyPostProcessors(profile, {
        ...base(),
        'concepts': ['anything'],
      }, PostProcessContext(recordedAt: DateTime(2026)));
      expect(out['concepts'], ['anything']);
    });
  });

  group('[PRF-05/AC1] TranscriptGrounding', () {
    final g = TranscriptGrounding(
      'Tenants and teams get a namespace. The policy controller runs.',
    );

    test('stems match plurals and derivations', () {
      expect(g.supports('tenancy namespaces'), isTrue);
      expect(g.supports('policies'), isTrue);
      expect(g.supports('cursor based polling'), isFalse);
    });

    test('text without key terms is not judged', () {
      expect(g.share('it is a'), 1);
    });

    test('[PRF-05/AC1] unspaced scripts are never judged or dropped', () {
      final cjk = TranscriptGrounding('我们今天讨论了预算和发布计划。下周开始实施。');
      expect(cjk.isUnspaced, isTrue);
      expect(cjk.keepsItem('预算审批流程 完全不同的内容'), isTrue);
      expect(cjk.supports('任何内容'), isTrue);
      expect(g.isUnspaced, isFalse);
    });

    test('[PRF-05/AC1] items with fewer than 2 key terms are kept', () {
      expect(g.keepsItem('zeppelin'), isTrue);
      expect(g.keepsItem('zeppelin hangar'), isFalse);
      expect(g.keepsItem('namespace policy'), isTrue);
    });

    test('[PRF-05/AC1] spoken numbers and digits do not cause drops', () {
      final n = TranscriptGrounding('We agreed on twelve seats for the pilot.');
      expect(n.keepsItem('12 seats pilot'), isTrue);
      final d = TranscriptGrounding('Budget is 12 seats for the pilot.');
      expect(d.keepsItem('twelve seats pilot'), isTrue);
      final none = TranscriptGrounding('We agreed on seats for the pilot.');
      expect(none.keepsItem('12 widgets launch'), isFalse);
    });

    test('[PRF-05/AC1] leadingText strips speaker labels, splits lines and '
        'always clips', () {
      final t = TranscriptGrounding(
        'Alice: We should ship the beta on Friday\nBob: Agreed. Then we test.',
      );
      expect(t.leadingText(), 'We should ship the beta on Friday');
      expect(t.leadingText(maxSentences: 2), contains('Agreed'));
      expect(t.leadingText(maxSentences: 2), isNot(contains('Bob:')));
      final long = TranscriptGrounding('word ' * 500);
      expect(long.leadingText().length, lessThanOrEqualTo(200));
      expect(long.leadingText(maxLength: 40).length, lessThanOrEqualTo(40));
    });

    test('stats serialise as counts only', () {
      final s = GroundingStats()..itemsDropped = 2;
      expect(s.toJson().keys, isNotEmpty);
      expect(s.toJson()['ungrounded_items'], 2);
      expect(s.isEmpty, isFalse);
    });
  });
}
