import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/extraction/domain/output_schema_validator.dart';
import 'package:vaultvoice/features/profiles/domain/post_processing.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/domain/profile_schema.dart';
import 'package:vaultvoice/features/templates/domain/note_context.dart';
import 'package:yaml/yaml.dart';

import '../templates/template_fixtures.dart';

/// Acceptance checks of the built-in profiles on the PRF-09 synthetic eval
/// sets (`tools/bench/eval/<profile>/`): the reference answers
/// (`expected.json`) go through the same Dart post-processors, render
/// context and default template as a real extraction. Model quality numbers
/// (recall/precision/accuracy) come from `make eval` and are recorded in the
/// task Completion Notes, not here.
const String evalRoot = '../tools/bench/eval';

typedef EvalCase = ({
  String id,
  Map<String, Object?> expected,
  String transcript,
  DateTime recordedAt,
});

List<EvalCase> casesOf(String profileId) {
  final dirs =
      Directory('$evalRoot/$profileId')
          .listSync()
          .whereType<Directory>()
          .where((d) => File('${d.path}/expected.json').existsSync())
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  return [
    for (final d in dirs)
      (
        id: d.uri.pathSegments.where((s) => s.isNotEmpty).last,
        expected: jsonDecode(
          File('${d.path}/expected.json').readAsStringSync(),
        ) as Map<String, Object?>,
        transcript: File('${d.path}/transcript.txt').readAsStringSync(),
        recordedAt: DateTime.parse(
          (jsonDecode(File('${d.path}/meta.json').readAsStringSync())
                  as Map<String, Object?>)['date']!
              as String,
        ),
      ),
  ];
}

Map<String, Object?> scoringTargets(String profileId) =>
    ((jsonDecode(File('$evalRoot/$profileId/scoring.json').readAsStringSync())
                as Map<String, Object?>)['targets']!
            as Map<String, Object?>)
        .cast<String, Object?>();

Map<String, Object?> processed(Profile p, EvalCase c) => applyPostProcessors(
  p,
  c.expected,
  PostProcessContext.fromTranscriptLines(
    c.transcript,
    recordedAt: c.recordedAt,
  ),
);

/// Renders [c] with the profile's default template.
String renderCase(Profile p, EvalCase c) {
  final meta = buildNoteMeta(
    recordingId: c.id,
    createdAt: c.recordedAt,
    durationMs: 600000,
    profileId: p.id,
    profileName: p.name,
    appVersion: '1.0.0',
  );
  return renderBuiltin(
    p.templateId,
    contextFor(p.id, processed(p, c), meta: meta),
  );
}

/// YAML front-matter of a rendered note.
Map<Object?, Object?> frontMatter(String md) {
  expect(md, startsWith('---\n'));
  final end = md.indexOf('\n---\n', 3);
  expect(end, greaterThan(0));
  return loadYaml(md.substring(4, end)) as YamlMap;
}

/// The markdownlint rules the repo config enforces that are cheap to check
/// (full run: `tools/ci/markdownlint.sh` on the goldens in CI).
void expectLintClean(String md, String id) {
  expect(
    md.endsWith('\n') && !md.endsWith('\n\n'),
    isTrue,
    reason: '$id MD047',
  );
  expect(md, isNot(contains('\n\n\n')), reason: '$id MD012');
  expect(RegExp(r'[ \t]+\n').hasMatch(md), isFalse, reason: '$id MD009');
  final lines = md.split('\n');
  var fences = 0;
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
    if (l.startsWith('```')) fences++;
    if (fences.isEven && RegExp('^#{1,6} ').hasMatch(l)) {
      if (i > 0 && lines[i - 1].trim().isNotEmpty && lines[i - 1] != '---') {
        fail('$id MD022: heading without blank line above: $l');
      }
      if (i + 1 < lines.length && lines[i + 1].trim().isNotEmpty) {
        fail('$id MD022: heading without blank line below: $l');
      }
    }
  }
  expect(fences.isEven, isTrue, reason: '$id fences are balanced');
}

void main() {
  const validator = OutputSchemaValidator();

  for (final id in ['meeting', 'warranty', 'engineering']) {
    test('$id eval set has ≥ 30 cases whose references fit the schema', () {
      final p = profile(id);
      final cases = casesOf(id);
      expect(cases.length, greaterThanOrEqualTo(30));
      for (final c in cases) {
        expect(
          validator.validate(c.expected, p.schema.toJson()),
          isEmpty,
          reason: c.id,
        );
      }
    });
  }

  group('[PRF-03/AC1] meeting', () {
    final p = profile('meeting');

    test('free tier, diarization on, speaker-aware owners', () {
      expect(p.tier, ProfileTier.free);
      expect(p.stt.diarization, isTrue);
      expect(
        p.postProcess.map((e) => e.wireName),
        contains('map_owner_to_speaker'),
      );
    });

    test('eval targets: action items P/R ≥ 80 %, owner ≥ 70 %', () {
      final t = scoringTargets('meeting');
      expect(t['lists.action_items.recall'], 0.8);
      expect(t['lists.action_items.precision'], 0.8);
      expect(t['lists.action_items.owner_accuracy'], 0.7);
    });

    test('schema has the scoped fields', () {
      expect(
        p.schema.properties.keys,
        containsAll([
          'title',
          'summary',
          'attendees',
          'decisions',
          'action_items',
          'open_questions',
          'topics',
        ]),
      );
      final item =
          (p.schema.properties['action_items']! as ArraySchema).items
              as ObjectSchema;
      expect(item.properties.keys, ['task', 'owner', 'due', 't']);
    });
  });

  group('[PRF-03/AC2] meeting note opens cleanly in Obsidian', () {
    final p = profile('meeting');
    final cases = casesOf('meeting');

    test('front-matter is valid YAML with date/tags; tasks use the Obsidian '
        'Tasks format', () {
      for (final c in cases) {
        final md = renderCase(p, c);
        final fm = frontMatter(md);
        expect(fm['type'], 'meeting', reason: c.id);
        expect(fm['date'], isNotNull, reason: c.id);
        expect(fm['tags'], isA<YamlList>(), reason: c.id);
        final items = (processed(p, c)['action_items']! as List).length;
        final tasks = RegExp(r'^- \[ \] ', multiLine: true).allMatches(md);
        expect(tasks.length, items, reason: '${c.id} task lines');
        if (items == 0) expect(md, contains('_No action items._'));
        expectLintClean(md, c.id);
      }
    });

    test('an assigned task carries owner and an absolute due date', () {
      final c = cases.firstWhere(
        (c) => (c.expected['action_items']! as List).any(
          (i) => (i as Map)['owner'] != null && i['due'] != null,
        ),
      );
      final md = renderCase(p, c);
      expect(
        md,
        matches(RegExp(r'- \[ \] .+\(@\w+.*\).*(📅 \d{4}-\d\d-\d\d|due:)')),
      );
    });
  });

  group('[PRF-04/AC1] warranty', () {
    final p = profile('warranty');

    test('diarization off; expiry is not a model field', () {
      expect(p.stt.diarization, isFalse);
      expect(p.schema.properties.containsKey('warranty_expiry'), isFalse);
      expect(p.postProcess.map((e) => e.wireName), [
        'normalize_serial',
        'resolve_relative_dates',
        'compute_warranty_expiry',
      ]);
      expect(p.instructions, contains('Do not compute the warranty expiry'));
    });

    test('eval targets: field accuracy ≥ 90 %, serial exact ≥ 85 %', () {
      final t = scoringTargets('warranty');
      expect(t['scalars.accuracy'], 0.9);
      expect(t['scalars.serial_number.exact'], 0.85);
    });

    test('reference serials survive normalization unchanged', () {
      for (final c in casesOf('warranty')) {
        final s = c.expected['serial_number'];
        if (s is String) expect(normalizeSerial(s), s, reason: c.id);
      }
    });
  });

  group('[PRF-04/AC2] warranty expiry and Dataview front-matter', () {
    final p = profile('warranty');

    test('expiry = purchase date + period for every eval case, ISO in the '
        'front-matter', () {
      var withExpiry = 0;
      for (final c in casesOf('warranty')) {
        final out = processed(p, c);
        final period = c.expected['warranty_period'];
        final purchase = out['purchase_date_iso'];
        final md = renderCase(p, c);
        final fm = frontMatter(md);
        if (period is Map && purchase is String) {
          final expected = computeWarrantyExpiry(
            DateTime.parse(purchase),
            (period['value']! as num).toInt(),
            period['unit']! as String,
          )!;
          final iso = expected.toIso8601String().substring(0, 10);
          expect(out['warranty_expiry'], iso, reason: c.id);
          expect('${fm['warranty_expiry']}', iso, reason: c.id);
          withExpiry++;
        } else {
          expect(fm.containsKey('warranty_expiry'), isFalse, reason: c.id);
        }
        expectLintClean(md, c.id);
      }
      expect(withExpiry, greaterThan(5));
    });
  });

  group('[PRF-05/AC1] engineering', () {
    final p = profile('engineering');

    test('eval targets: TODO recall ≥ 80 %, trade-offs ≥ 70 %', () {
      final t = scoringTargets('engineering');
      expect(t['lists.todos.recall'], 0.8);
      expect(t['lists.tradeoffs.recall'], 0.7);
    });

    test('schema pairs every trade-off option with its own pros and cons', () {
      final item =
          (p.schema.properties['tradeoffs']! as ArraySchema).items
              as ObjectSchema;
      expect(item.properties.keys, ['option', 'pros', 'cons']);
      final api =
          (p.schema.properties['api_designs']! as ArraySchema).items
              as ObjectSchema;
      expect(api.properties.keys, [
        'name',
        'description',
        'endpoints_or_signatures',
      ]);
    });

    test('technical vocabulary hints ship with the profile', () {
      expect(p.stt.vocabulary, containsAll(['API', 'REST', 'gRPC']));
    });
  });

  group('[PRF-05/AC2] engineering note renders and lints clean', () {
    final p = profile('engineering');

    test('trade-offs as tables, API designs as fenced code', () {
      var tables = 0;
      var fenced = 0;
      for (final c in casesOf('engineering')) {
        final md = renderCase(p, c);
        expectLintClean(md, c.id);
        final out = processed(p, c);
        final hasTradeoffs = (out['tradeoffs']! as List).isNotEmpty;
        if (hasTradeoffs) {
          expect(md, contains('| Option |'), reason: c.id);
          tables++;
        }
        if ((out['api_designs']! as List).any(
          (a) => ((a as Map)['endpoints_or_signatures'] as List).isNotEmpty,
        )) {
          expect(md, contains('```'), reason: c.id);
          fenced++;
        }
        frontMatter(md);
      }
      expect(tables, greaterThan(5));
      expect(fenced, greaterThan(3));
    });
  });
}
