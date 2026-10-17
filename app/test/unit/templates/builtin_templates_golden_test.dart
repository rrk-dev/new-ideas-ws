import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/templates/domain/builtin_templates.dart';
import 'package:vaultvoice/features/templates/domain/note_context.dart';
import 'package:vaultvoice/features/templates/domain/template_lambdas.dart';
import 'package:yaml/yaml.dart';

import 'template_fixtures.dart';

/// Markdown goldens of every built-in template × {full, empty, adversarial}
/// live in `test/fixtures/markdown/golden/`; regenerate with
/// `fvm flutter test --update-goldens test/unit/templates/` (text files —
/// identical on every host) and lint them with `tools/ci/markdownlint.sh`.
const String goldenDir = 'test/fixtures/markdown/golden';

enum Case { full, empty, adversarial }

Map<String, Object?> fullData(String profileId) => switch (profileId) {
  'warranty' => warrantyFull(),
  'engineering' => engineeringFull(),
  'lecture' => lectureFull(),
  'sales_call' => salesCallFull(),
  _ => meetingFull(),
};

String profileOf(BuiltinTemplateInfo t) => t.profileId ?? 'meeting';

Map<String, Object?> adversarialMeta(String profileId) => buildNoteMeta(
  recordingId: 'rec-"adv"\n---',
  title: adversarialStrings[1],
  createdAt: DateTime(2026, 10, 13, 14, 5),
  durationMs: 3723000,
  profileId: profileId,
  profileName: profile(profileId).name,
  appVersion: '1.0.0',
  speakers: [(label: 'S1', name: adversarialStrings[3])],
  tags: adversarialStrings.take(6).toList(),
  sttModel: '{{x}}',
  llmModel: '<!--',
  device: tenK,
  consentAt: DateTime.utc(2026, 10, 13, 12, 4, 30),
);

Map<String, Object?> adversarialTranscript() => buildNoteTranscript([
  for (final (i, s) in adversarialStrings.indexed)
    (startMs: i * 1000, speaker: i.isEven ? s : null, text: s),
  (startMs: 99000, speaker: 'S1', text: tenK),
]);

typedef Inputs = ({
  Map<String, Object?> data,
  Map<String, Object?> meta,
  Map<String, Object?> transcript,
});

Inputs inputsFor(BuiltinTemplateInfo t, Case c) {
  final pid = profileOf(t);
  final data = fullData(pid);
  // summary-only renders any profile's data; give it a summary to show.
  if (t.profileId == null) data['summary'] = 'Free-text summary.';
  return switch (c) {
    Case.full => (
      data: data,
      meta: metaFull(profileId: pid),
      transcript: transcriptFull(),
    ),
    Case.empty => (
      data: const {},
      meta: metaEmpty(profileId: pid),
      transcript: const {},
    ),
    Case.adversarial => (
      data: adversarial(data)! as Map<String, Object?>,
      meta: adversarialMeta(pid),
      transcript: adversarialTranscript(),
    ),
  };
}

/// Same shape as [value] with every string replaced by a harmless word.
Object? benign(Object? value) => switch (value) {
  String() => 'value',
  final Map<String, Object?> m => {
    for (final e in m.entries) e.key: benign(e.value),
  },
  final List<Object?> l => [for (final e in l) benign(e)],
  _ => value,
};

/// [inputs] with every LLM/transcript/user string made harmless (dates,
/// times and app-computed meta stay).
Inputs benignTwin(Inputs inputs) => (
  data: benign(inputs.data)! as Map<String, Object?>,
  meta: {
    ...inputs.meta,
    for (final k in ['recording_id', 'title', 'speakers', 'tags', 'device'])
      k: benign(inputs.meta[k]),
    'model_ids': benign(inputs.meta['model_ids']),
  },
  transcript: benign(inputs.transcript)! as Map<String, Object?>,
);

Map<String, Object?> contextOf(BuiltinTemplateInfo t, Inputs i) =>
    t.profileId == null
    ? normalizeContext(
        kSummaryOnlyRootShape,
        data: i.data,
        meta: i.meta,
        transcript: i.transcript,
      )
    : contextFor(profileOf(t), i.data, meta: i.meta, transcript: i.transcript);

Map<String, Object?> contextForCase(BuiltinTemplateInfo t, Case c) =>
    contextOf(t, inputsFor(t, c));

const LambdaOptions audio = LambdaOptions(audioAttachment: 'rec-1.m4a');

String render(BuiltinTemplateInfo t, Case c) => renderBuiltin(
  t.id,
  contextForCase(t, c),
  options: c == Case.empty ? const LambdaOptions() : audio,
);

/// Splits a rendered note into (front-matter text or null, body).
(String?, String) splitFrontMatter(String md) {
  if (!md.startsWith('---\n')) return (null, md);
  final end = md.indexOf('\n---\n', 3);
  expect(end, greaterThan(0), reason: 'front-matter is closed');
  return (md.substring(4, end), md.substring(end + 5));
}

/// The structure of a note with every value removed: one token per line
/// (heading level, list/task marker and nesting, table row, callout, fence,
/// thematic break, property / front-matter key, paragraph, blank).
List<String> skeleton(String md) {
  final (fm, body) = splitFrontMatter(md);
  return [
    if (fm != null)
      for (final line in fm.split('\n'))
        'fm:${RegExp('^([a-z_]+):').firstMatch(line)?.group(1) ?? '!!'}',
    for (final line in body.split('\n')) _lineKind(line),
  ];
}

String _lineKind(String line) {
  final rules = <String, RegExp>{
    'blank': RegExp(r'^$'),
    'h': RegExp('^(#{1,6}) '),
    'hr': RegExp(r'^(---|\*\*\*|___)$'),
    'fence': RegExp('^(```|~~~)'),
    'task': RegExp(r'^(\s*)- \[[ x]\] '),
    'todo': RegExp(r'^(\s*)- TODO '),
    'li': RegExp(r'^(\s*)- '),
    'callout': RegExp(r'^> \[!'),
    'quote': RegExp('^> '),
    'row': RegExp(r'^\| '),
    'prop': RegExp('^([a-z][a-z-]*):: '),
  };
  for (final e in rules.entries) {
    final m = e.value.firstMatch(line);
    if (m != null) {
      return m.groupCount > 0 ? '${e.key}${m.group(1)}' : e.key;
    }
  }
  return 'p';
}

void main() {
  group('[EXP-01/AC1][TPL-01/AC3][TPL-02/AC3] golden files for each built-in template', () {
    for (final t in kBuiltinTemplates) {
      for (final c in Case.values) {
        test('${t.id} × ${c.name}', () {
          final md = render(t, c);
          final file = File('$goldenDir/${t.id}.${c.name}.md');
          if (autoUpdateGoldenFiles) {
            file
              ..createSync(recursive: true)
              ..writeAsStringSync(md);
          }
          expect(
            file.existsSync(),
            isTrue,
            reason: 'missing golden ${file.path} — run with --update-goldens',
          );
          expect(md, file.readAsStringSync());
        });
      }
    }

    test('golden folder holds exactly the expected files', () {
      final expected = {
        for (final t in kBuiltinTemplates)
          for (final c in Case.values) '${t.id}.${c.name}.md',
      };
      final actual = {
        for (final f in Directory(goldenDir).listSync().whereType<File>())
          f.uri.pathSegments.last,
      };
      expect(actual, expected);
    });

    test('every built-in template passes the strict variable check', () {
      for (final t in kBuiltinTemplates) {
        expect(
          engine.validate(templateSource(t.id), shapeForTemplate(t)),
          isEmpty,
          reason: t.id,
        );
      }
    });

    test('built-in template list equals the asset folder', () {
      final files = {
        for (final f in Directory('assets/templates').listSync())
          f.uri.pathSegments.last,
      };
      expect(files, {for (final t in kBuiltinTemplates) '${t.id}.mustache'});
    });

    test('a missing or broken built-in asset is a build error', () {
      final sources = {
        for (final t in kBuiltinTemplates) t.assetPath: templateSource(t.id),
      };
      expect(
        () => BuiltinTemplates.parse(
          {...sources}..remove(kBuiltinTemplates.first.assetPath),
        ),
        throwsA(isA<BuiltinTemplateException>()),
      );
      expect(
        () => BuiltinTemplates.parse({
          ...sources,
          kBuiltinTemplates.first.assetPath: '{{#x}}',
        }),
        throwsA(
          isA<BuiltinTemplateException>().having(
            (e) => e.toString(),
            'message',
            contains('meeting-default:1:1'),
          ),
        ),
      );
      expect(builtinTemplates.ids, hasLength(kBuiltinTemplates.length));
    });

    test('every built-in profile has its default template', () {
      for (final p in builtinProfiles.all) {
        expect(builtinTemplates[p.templateId], isNotNull, reason: p.id);
      }
    });

    test('notes are lint-clean basics: one trailing newline, no double '
        'blank lines, no trailing spaces, no leftover tags', () {
      for (final t in kBuiltinTemplates) {
        for (final c in Case.values) {
          final md = render(t, c);
          expect(md, endsWith('\n'));
          expect(md, isNot(endsWith('\n\n')));
          expect(md, isNot(contains('\n\n\n')));
          expect(md, isNot(matches(RegExp(r'[ \t]$', multiLine: true))));
          if (c != Case.adversarial) expect(md, isNot(contains('{{')));
        }
      }
    });
  });

  group('[EXP-01/AC2] malicious input cannot break front-matter or '
      'template structure', () {
    for (final t in kBuiltinTemplates) {
      test('${t.id}: adversarial values keep the exact structure', () {
        final twin = renderBuiltin(
          t.id,
          contextOf(t, benignTwin(inputsFor(t, Case.adversarial))),
          options: audio,
        );
        expect(skeleton(render(t, Case.adversarial)), skeleton(twin));
      });
    }

    for (final t in kBuiltinTemplates.where(
      (t) => t.flavor == TemplateFlavor.obsidian,
    )) {
      test('${t.id}: front-matter round-trips through a YAML parser', () {
        for (final c in Case.values) {
          final ctx = contextForCase(t, c);
          final md = render(t, c);
          final (fm, _) = splitFrontMatter(md);
          final yaml = loadYaml(fm!) as YamlMap;
          final meta = ctx['meta']! as Map<String, Object?>;
          final data = ctx['data']! as Map<String, Object?>;
          expect(yaml['source'], 'vaultvoice');
          expect(yaml['recording_id'], meta['recording_id']);
          // `date` is unquoted for Obsidian; compare as a date.
          expect(
            DateTime.parse('${yaml['date']}'),
            DateTime.parse(meta['date']! as String),
          );
          expect(yaml['type'], meta['profile_id']);
          expect(List<Object?>.from(yaml['tags'] as YamlList), meta['tags']);
          if (yaml.containsKey('time')) expect(yaml['time'], meta['time']);
          if (yaml.containsKey('duration')) {
            expect(yaml['duration'], meta['duration_human']);
          }
          if (!templateSource(t.id).contains('consent_at:')) {
            expect(yaml.containsKey('consent_at'), isFalse);
          } else if (meta['consent_at'] != null) {
            expect(yaml['consent_at'], meta['consent_at']);
          } else {
            expect(yaml.containsKey('consent_at'), isFalse);
          }
          if (yaml.containsKey('attendees')) {
            expect(
              List<Object?>.from(yaml['attendees'] as YamlList),
              data['attendees'],
            );
          }
          final titleKey = t.profileId == 'warranty' ? 'product' : 'title';
          final expectedTitle =
              data[titleKey] ??
              meta['title'] ??
              '${meta['profile_name']} ${meta['date']}';
          expect(yaml['title'], expectedTitle, reason: '${t.id} ${c.name}');
          for (final k in ['brand', 'model', 'serial_number']) {
            if (data.containsKey(k) && data[k] != null) {
              expect(yaml[k], data[k]);
            }
          }
          if (t.id == kSummaryOnlyTemplateId) {
            expect(yaml['extraction'], 'failed');
          }
        }
      });
    }

    test('values are never re-parsed as templates', () {
      final md = renderBuiltin(
        'meeting-default',
        contextFor('meeting', {
          'title': '{{meta.recording_id}}',
          'summary': '{{#data.attendees}}x{{/data.attendees}} {{{data.title}}}',
          'attendees': ['{{> partial}}', '{{=<% %>=}}'],
        }),
      );
      expect(md, contains('title: "{{meta.recording_id}}"'));
      expect(md, isNot(contains('0f8d2c1e-7a5b-4c3d-9e1f-2a3b4c5d6e7f\n#')));
      expect(md, contains(r'# {\{meta.recording_id}}'));
      expect(md, contains(r'{\{#data.attendees}}x{\{/data.attendees}}'));
      expect(md, contains(r'- {\{> partial}}'));
    });

    test('a transcript line cannot close the callout or open a block', () {
      final md = renderBuiltin(
        kSummaryOnlyTemplateId,
        normalizeContext(
          kSummaryOnlyRootShape,
          data: const {},
          meta: metaFull(),
          transcript: buildNoteTranscript(const [
            (startMs: 0, speaker: 'A', text: 'line one\n\n# Heading\n---'),
            (startMs: 1000, speaker: null, text: '```\nfence'),
          ]),
        ),
      );
      final callout = md.substring(md.indexOf('> [!note]-'));
      final lines = callout.trimRight().split('\n');
      expect(lines, hasLength(3));
      expect(lines.every((l) => l.startsWith('> ')), isTrue);
      expect(lines[1], '> [00:00:00] A: line one # Heading ---');
      expect(lines[2], '> [00:00:01] fence');
    });
  });
}
