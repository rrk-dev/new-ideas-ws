import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/extraction/domain/output_schema_validator.dart';
import 'package:vaultvoice/features/profiles/domain/post_processors.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';

import '../templates/template_fixtures.dart';
import 'builtin_profile_acceptance_test.dart'
    show casesOf, expectLintClean, frontMatter, processed, renderCase;

/// TPL-01: the built-in English Lecture profile on its 30-case eval set
/// (`tools/bench/eval/lecture/`, simulated transcripts). Model quality
/// numbers come from `make eval PROFILE=lecture` (see the task file).
void main() {
  final p = profile('lecture');
  const validator = OutputSchemaValidator();

  group('[TPL-01/AC2] profile definition', () {
    test('schema keys, single speaker, English, consent required', () {
      expect(p.schema.properties.keys, [
        'title',
        'summary',
        'key_concepts',
        'outline',
        'assignments',
        'questions',
        'references',
      ]);
      expect(p.stt.diarization, isFalse);
      expect(p.stt.numSpeakers, 1);
      expect(p.consentConfirmation, ConsentConfirmation.required);
      expect(p.templateId, 'lecture-default');
    });

    test('uses only existing post-processors and ships no examples', () {
      expect(
        p.postProcess,
        containsAll([
          PostProcessor.resolveRelativeDates,
          PostProcessor.groundToTranscript,
        ]),
      );
      expect(p.examples, isEmpty);
    });

    test('tier is a marked product decision (LIC-05)', () {
      expect(
        File('assets/profiles/lecture.yaml').readAsStringSync(),
        contains('PRODUCT-DECISION'),
      );
    });

    test('references stay out of English-only prompts (no cloud fields)', () {
      final yaml = File('assets/profiles/lecture.yaml').readAsStringSync();
      expect(yaml, isNot(contains('http')));
    });
  });

  group('[TPL-01/AC3] eval set renders lint-clean notes', () {
    test('≥ 30 cases whose references fit the schema', () {
      final cases = casesOf('lecture');
      expect(cases.length, greaterThanOrEqualTo(30));
      for (final c in cases) {
        expect(
          validator.validate(c.expected, p.schema.toJson()),
          isEmpty,
          reason: c.id,
        );
        final meta = jsonDecode(
          File('../tools/bench/eval/lecture/${c.id}/meta.json')
              .readAsStringSync(),
        ) as Map<String, Object?>;
        expect(meta['diarization'], isFalse, reason: c.id);
        expect(
          (meta['asr']! as Map<String, Object?>)['simulated'],
          isTrue,
          reason: '${c.id}: honest provenance',
        );
      }
    });

    test('every case renders lint-clean with front-matter', () {
      for (final c in casesOf('lecture')) {
        final md = renderCase(p, c);
        expectLintClean(md, c.id);
        final fm = frontMatter(md);
        expect(fm['source'], isNotNull, reason: c.id);
        expect('${c.expected['title']}'.isNotEmpty, isTrue);
      }
    });

    test('assignments in the processed output keep task text', () {
      var withDue = 0;
      for (final c in casesOf('lecture')) {
        final out = processed(p, c);
        for (final a
            in (out['assignments']! as List).cast<Map<String, Object?>>()) {
          expect('${a['task']}'.trim(), isNotEmpty, reason: c.id);
          if (a['due_iso'] != null) withDue++;
        }
      }
      expect(withDue, greaterThan(3));
    });
  });

  group('[TPL-01/AC4] eval targets are fixed before the baseline', () {
    test('scoring.json mirrors the task file targets', () {
      final cfg = jsonDecode(
        File('../tools/bench/eval/lecture/scoring.json').readAsStringSync(),
      ) as Map<String, Object?>;
      final t = cfg['targets']! as Map<String, Object?>;
      expect(t['schema_valid'], 0.9);
      expect(t['lists.key_concepts.recall'], 0.5);
      expect(t['lists.assignments.recall'], 0.6);
      expect(t['lists.assignments.precision'], 0.6);
      final task = File('../tasks/14-product-phase2/TPL-01-lecture-profile.md')
          .readAsStringSync();
      expect(task, contains('written before the first baseline run'));
    });
  });

  group('TPL-01 scope: STT vocabulary stays user-configurable', () {
    test('the generic per-profile setting key covers lecture', () {
      expect(SettingKeys.vocabularyFor('lecture'), 'vocabulary.lecture');
    });
  });

  group('[TPL-01/AC6] no new network host, permission or content logging', () {
    test('egress and recording-policy checks pass', () {
      for (final script in ['check_egress.sh', 'check_recording_policy.sh']) {
        final r = Process.runSync('bash', [
          'tools/ci/$script',
        ], workingDirectory: '..');
        expect(r.exitCode, 0, reason: '$script: ${r.stdout}${r.stderr}');
      }
    });

    test('the profile and templates carry no URLs or logging', () {
      final files = [
        'assets/profiles/lecture.yaml',
        for (final f in ['default', 'logseq', 'plain'])
          'assets/templates/lecture-$f.mustache',
      ];
      for (final f in files) {
        final text = File(f).readAsStringSync();
        expect(text, isNot(contains('http')), reason: f);
        expect(text, isNot(contains('print(')), reason: f);
      }
    });
  });
}
