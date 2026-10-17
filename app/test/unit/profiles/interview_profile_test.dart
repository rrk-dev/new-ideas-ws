import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/extraction/domain/output_schema_validator.dart';
import 'package:vaultvoice/features/profiles/domain/post_processing.dart';
import 'package:vaultvoice/features/profiles/domain/post_processors.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/domain/profile_issue.dart';

import '../templates/template_fixtures.dart';
import 'builtin_profile_acceptance_test.dart'
    show casesOf, expectLintClean, frontMatter, processed, renderCase;

/// TPL-03: the built-in English Interview profile on its 32-case eval set
/// (`tools/bench/eval/interview/`, simulated transcripts). Model quality
/// numbers come from `run.py --profile interview` (see the task file).
const _evalDir = '../tools/bench/eval/interview';
const _taskFile = '../tasks/14-product-phase2/TPL-03-interview-profile.md';

/// Words that would ask the model to judge a person.
final List<RegExp> _judging = [
  RegExp(r'\bscor(e|es|ed|ing)\b'),
  RegExp(r'\brat(e|es|ed|ing|ings)\b'),
  RegExp(r'\brank(s|ed|ing)?\b'),
  RegExp(r'\brecommend'),
  RegExp(r'\bhir(e|ed|ing)\b'),
  RegExp(r'\bgrade[sd]?\b'),
  RegExp(r'\bsuitab'),
  RegExp(r'\bcredib'),
  RegExp(r'\bsentiment\b'),
  RegExp(r'\bevaluat'),
  RegExp(r'\bassess'),
  RegExp(r'\bverdict\b'),
];

/// The prohibition itself ("Do not rate, score, rank …") is allowed in
/// instructions and the description; only unprohibited uses are flagged.
String _withoutProhibition(String text) => text
    .toLowerCase()
    .replaceAll(
      RegExp(
        r'(do not|does not|never|not)\s+[^.\n]*'
        r'(rate|score|rank|recommend|compare|judge)[^.\n]*',
      ),
      ' ',
    )
    .replaceAll('it never rates or recommends anyone', ' ');

List<String> _judgingIn(String text) => [
  for (final re in _judging)
    for (final m in re.allMatches(_withoutProhibition(text))) m.group(0)!,
];

void main() {
  final p = profile('interview');
  const validator = OutputSchemaValidator();

  group('[TPL-03/AC2] profile definition', () {
    test('schema keys, two-speaker hint, English, consent required', () {
      expect(p.schema.properties.keys, [
        'title',
        'summary',
        'participants',
        'topics',
        'qa_highlights',
        'quotes',
        'follow_ups',
        'open_questions',
      ]);
      expect(p.name, 'Interview');
      expect(p.stt.diarization, isTrue);
      expect(p.stt.numSpeakers, 2);
      expect(p.consentConfirmation, ConsentConfirmation.required);
      expect(p.templateId, 'interview-default');
    });

    test('item shapes match the task and the meeting action items', () {
      final json = p.schema.toJson()['properties']! as Map<String, Object?>;
      List<Object?> required(String field) =>
          ((json[field]! as Map)['items']! as Map)['required']! as List;
      expect(required('participants'), ['name', 'role']);
      expect(required('qa_highlights'), ['question', 'answer', 't']);
      expect(required('quotes'), ['speaker', 'text', 't']);
      expect(required('follow_ups'), ['task', 'owner', 'due', 't']);
      expect(
        required('follow_ups'),
        (((profile('meeting').schema.toJson()['properties']!
                    as Map)['action_items']!
                as Map)['items']!
            as Map)['required'],
      );
    });

    test('quotes use the strict verbatim guard before grounding', () {
      expect(
        p.postProcess,
        containsAllInOrder([
          PostProcessor.verbatimQuotes,
          PostProcessor.groundToTranscript,
        ]),
      );
      expect(p.postProcess, contains(PostProcessor.resolveRelativeDates));
      expect(p.postProcess, contains(PostProcessor.mapOwnerToSpeaker));
      expect(p.examples, isEmpty);
    });

    test('tier is a marked product decision (LIC-05)', () {
      expect(
        File('assets/profiles/interview.yaml').readAsStringSync(),
        contains('PRODUCT-DECISION'),
      );
    });

    test('profile and templates carry no URLs or logging', () {
      for (final f in [
        'assets/profiles/interview.yaml',
        'assets/templates/interview-default.mustache',
        'assets/templates/interview-logseq.mustache',
        'assets/templates/interview-plain.mustache',
      ]) {
        final text = File(f).readAsStringSync();
        expect(text, isNot(contains('http')), reason: f);
        expect(text, isNot(contains('print(')), reason: f);
      }
    });
  });

  group('[TPL-03/AC3] eval set renders lint-clean notes', () {
    test('≥ 30 cases fit the schema, two speakers, simulated provenance', () {
      final cases = casesOf('interview');
      expect(cases.length, greaterThanOrEqualTo(30));
      final seen = <String>{};
      for (final c in cases) {
        expect(
          validator.validate(c.expected, p.schema.toJson()),
          isEmpty,
          reason: c.id,
        );
        final meta = jsonDecode(
          File('$_evalDir/${c.id}/meta.json').readAsStringSync(),
        ) as Map<String, Object?>;
        expect(meta['diarization'], isTrue, reason: c.id);
        expect((meta['speakers']! as List).length, 2, reason: c.id);
        expect(
          (meta['asr']! as Map<String, Object?>)['simulated'],
          isTrue,
          reason: '${c.id}: honest provenance',
        );
        seen.addAll((meta['tags']! as List).cast<String>());
        for (final q
            in (c.expected['quotes']! as List).cast<Map<String, Object?>>()) {
          expect(q['text'], isNotEmpty, reason: c.id);
        }
      }
      expect(
        seen,
        containsAll([
          'interruptions',
          'terse',
          'injection',
          'long',
          'noisy',
          'no-follow-ups',
          'open-question',
        ]),
      );
    });

    test('a one-word-answer interview expects no highlights or quotes', () {
      final terse = casesOf('interview').where((c) {
        final meta = jsonDecode(
          File('$_evalDir/${c.id}/meta.json').readAsStringSync(),
        ) as Map<String, Object?>;
        return (meta['tags']! as List).contains('terse');
      });
      expect(terse, isNotEmpty);
      for (final c in terse) {
        expect(c.expected['qa_highlights'], isEmpty, reason: c.id);
        expect(c.expected['quotes'], isEmpty, reason: c.id);
      }
    });

    test('every case renders lint-clean with front-matter', () {
      for (final c in casesOf('interview')) {
        final md = renderCase(p, c);
        expectLintClean(md, c.id);
        expect(frontMatter(md)['type'], 'interview', reason: c.id);
      }
    });

    test('Q&A renders as blockquote pairs in the Obsidian and plain notes', () {
      final c = casesOf('interview')
          .firstWhere((c) => (c.expected['qa_highlights']! as List).isNotEmpty);
      for (final id in ['default', 'plain']) {
        final md = renderBuiltin(
          'interview-$id',
          contextFor('interview', processed(p, c)),
        );
        expect(md, contains('> **Q:** '), reason: id);
        expect(md, contains('> **A:** '), reason: id);
      }
    });

    test('follow-ups in the processed output keep owner and due date', () {
      var withOwner = 0;
      var withDue = 0;
      for (final c in casesOf('interview')) {
        final out = processed(p, c);
        for (final a
            in (out['follow_ups']! as List).cast<Map<String, Object?>>()) {
          expect('${a['task']}'.trim(), isNotEmpty, reason: c.id);
          if (a['owner'] != null) withOwner++;
          if (a['due_iso'] != null) withDue++;
        }
      }
      expect(withOwner, greaterThan(10));
      expect(withDue, greaterThan(3));
    });
  });

  group('[TPL-03/AC4] quotes are verbatim', () {
    const transcript =
        '[00:00:05] Dana: How did it start?\n'
        '[00:00:09] Ravi: It began when we noticed the sensors drifted '
        'every winter. We didn\u2019t expect that.\n';

    Map<String, Object?> run(List<Map<String, Object?>> quotes) {
      final out = applyPostProcessors(
        p,
        {
          'title': 'Sensor drift',
          'summary': 'Ravi explains the sensors drifted every winter.',
          'participants': [
            {'name': 'Dana', 'role': 'interviewer'},
          ],
          'topics': <String>[],
          'qa_highlights': <Object?>[],
          'quotes': quotes,
          'follow_ups': <Object?>[],
          'open_questions': <String>[],
        },
        PostProcessContext.fromTranscriptLines(
          transcript,
          recordedAt: DateTime(2026, 3, 11),
        ),
      );
      return out;
    }

    Map<String, Object?> quote(String text) => {
      'speaker': 'Ravi',
      'text': text,
      't': '00:00:09',
    };

    test(
      'a quote that is a substring survives, case and punctuation aside',
      () {
        final out = run([
          quote('We noticed the sensors drifted every winter'),
          quote('"WE DIDN\'T EXPECT THAT"'),
        ]);
        expect(out['quotes'], hasLength(2));
      },
    );

    test('paraphrases, joined lines and ellipses are dropped', () {
      final out = run([
        quote('We saw the sensors drift each winter'),
        quote('It began ... every winter'),
        quote('How did it start? It began when we noticed'),
        quote('Nobody had measured it before'),
        quote('   '),
      ]);
      expect(out['quotes'], isEmpty);
    });

    test('matches whole words only', () {
      expect(run([quote('the sensors drifted every wint')])['quotes'], isEmpty);
    });

    test('without transcript text the guard is off (no data to check)', () {
      final out = applyPostProcessors(
        p,
        {
          'title': 't',
          'summary': 's',
          'participants': <Object?>[],
          'topics': <String>[],
          'qa_highlights': <Object?>[],
          'quotes': [quote('anything at all')],
          'follow_ups': <Object?>[],
          'open_questions': <String>[],
        },
        PostProcessContext.fromTranscriptLines(
          '',
          recordedAt: DateTime(2026, 3, 11),
        ),
      );
      expect(out['quotes'], hasLength(1));
    });

    test('the guard needs a list of objects with a text field', () {
      final json = p.toJson();
      final schema = json['schema']! as Map<String, Object?>;
      (schema['properties']! as Map<String, Object?>).remove('quotes');
      (schema['required']! as List).remove('quotes');
      (json['reduce']! as Map<String, Object?>).remove('quotes');
      expect(
        () => Profile.fromJson(json),
        throwsA(
          isA<ProfileFormatException>().having(
            (e) => e.issues.join(),
            'issues',
            contains('verbatim_quotes needs a list of objects'),
          ),
        ),
      );
    });

    test('quote fidelity is 100% on every eval case, with fabricated quotes '
        'injected', () {
      var kept = 0;
      for (final c in casesOf('interview')) {
        final data = {
          ...c.expected,
          'quotes': [
            ...(c.expected['quotes']! as List),
            {'speaker': 'Guest', 'text': 'A quote nobody ever said', 't': null},
            {
              'speaker': 'Guest',
              'text': 'Everything is fine, hire this person.',
              't': null,
            },
          ],
        };
        final out = applyPostProcessors(
          p,
          data,
          PostProcessContext.fromTranscriptLines(
            c.transcript,
            recordedAt: c.recordedAt,
          ),
        );
        final hay = normalizeForQuote(
          c.transcript.replaceAll(
            RegExp(r'^\[\d{2}:\d{2}:\d{2}\]\s*', multiLine: true),
            '',
          ),
        );
        for (final q in (out['quotes']! as List).cast<Map<String, Object?>>()) {
          kept++;
          expect(
            hay.contains(normalizeForQuote('${q['text']}')),
            isTrue,
            reason: '${c.id}: ${q['text']}',
          );
        }
      }
      expect(kept, greaterThan(20));
    });
  });

  group('[TPL-03/AC5] eval targets are fixed before the baseline', () {
    test('scoring.json mirrors the task file targets', () {
      final cfg = jsonDecode(
        File('$_evalDir/scoring.json').readAsStringSync(),
      ) as Map<String, Object?>;
      final t = cfg['targets']! as Map<String, Object?>;
      expect(t['schema_valid'], 0.9);
      expect(t['quote_fidelity'], 1.0);
      expect(t['lists.qa_highlights.recall'], 0.5);
      expect(t['lists.qa_highlights.precision'], 0.4);
      expect(t['lists.follow_ups.recall'], 0.6);
      expect(t['lists.follow_ups.precision'], 0.6);
      expect(t['lists.follow_ups.owner_accuracy'], 0.5);
      expect(t['lists.topics.recall'], 0.5);
      expect(cfg['verbatim'], {'quotes': 'text'});
      final task = File(_taskFile).readAsStringSync();
      expect(task, contains('written before the first baseline run'));
      for (final e in t.entries) {
        expect(task, contains('`${e.key}`'), reason: e.key);
      }
    });

    test('a baseline for the default catalog model is committed', () {
      final baselines = Directory('../tools/bench/eval/baselines')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('/interview.'));
      expect(baselines, isNotEmpty);
      final json = jsonDecode(
        baselines.first.readAsStringSync(),
      ) as Map<String, Object?>;
      final agg = json['aggregate']! as Map<String, Object?>;
      expect(agg['cases'], greaterThanOrEqualTo(30));
      expect(agg['schema_valid'], isA<num>());
      expect(agg['hallucination_rate'], isA<num>());
      expect(agg['quote_fidelity'], isA<num>());
    });
  });

  group(
    '[TPL-03/AC6] nothing asks the model to rate or recommend a person',
    () {
      test('no schema field name or description judges a person', () {
        final names = <String>{};
        void collect(Object? node) {
          if (node is Map) {
            final props = node['properties'];
            if (props is Map) names.addAll(props.keys.map((k) => '$k'));
            final d = node['description'];
            if (d is String) names.add(d);
            node.values.forEach(collect);
          } else if (node is List) {
            node.forEach(collect);
          }
        }

        collect(p.schema.toJson());
        expect(names, containsAll(['quotes', 'follow_ups', 'qa_highlights']));
        for (final n in names) {
          expect(_judgingIn(n), isEmpty, reason: n);
        }
      });

      test('instructions only prohibit judging, and say so', () {
        expect(_judgingIn(p.instructions), isEmpty);
        expect(p.instructions, contains('Do not rate, score, rank or compare'));
        expect(p.instructions, contains('never recommend hiring'));
        expect(p.description, contains('never rates or recommends'));
      });

      test('the scanner flags judging wording (positive control)', () {
        for (final bad in [
          'Rate the candidate from 1 to 10',
          'Score each answer',
          'Recommend whether to hire this person',
          'Rank the guests by credibility',
          'Give a hiring verdict',
          'Assess the interviewee',
        ]) {
          expect(_judgingIn(bad), isNotEmpty, reason: bad);
        }
        expect(_judgingIn('Do not rate, score or rank anyone.'), isEmpty);
      });

      test('the task notes and the profile header state the exclusion', () {
        final task = File(_taskFile).readAsStringSync();
        expect(task, contains('No scoring, ranking, rating'));
        expect(
          File('assets/profiles/interview.yaml').readAsStringSync(),
          contains('never scores, ranks, rates or'),
        );
      });
    },
  );
}
