import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/templates/domain/builtin_templates.dart';

import 'builtin_templates_golden_test.dart' show Case, render;

/// Problems of [md] as a Logseq page (EXP-08 / vv-markdown-vault-export →
/// Logseq conventions): the first block holds only `key:: value` page
/// properties (lower-case keys, no YAML front-matter), followed by one
/// blank line; every other line is an outline bullet `- ` with 2-space
/// nesting that deepens at most one level at a time.
List<String> logseqProblems(String md) {
  final problems = <String>[];
  final lines = md.split('\n');
  if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
  if (md.startsWith('---')) problems.add('YAML front-matter');
  var i = 0;
  final property = RegExp(r'^[a-z][a-z0-9-]*:: \S');
  for (; i < lines.length && lines[i].isNotEmpty; i++) {
    if (!property.hasMatch(lines[i])) problems.add('line ${i + 1}: property');
  }
  if (i == 0) problems.add('no page properties');
  final bullet = RegExp(r'^((?:  )*)- \S');
  var depth = -1;
  for (i++; i < lines.length; i++) {
    final m = bullet.firstMatch(lines[i]);
    if (m == null) {
      problems.add('line ${i + 1}: not a bullet');
      continue;
    }
    final d = m.group(1)!.length ~/ 2;
    if (d > depth + 1) problems.add('line ${i + 1}: skips a level');
    depth = d;
  }
  return problems;
}

void main() {
  test('every built-in profile has an Obsidian, a Logseq and a plain '
      'variant', () {
    for (final profileId in ['meeting', 'warranty', 'engineering']) {
      for (final f in TemplateFlavor.values) {
        expect(
          builtinVariant(profileId, f),
          isNotNull,
          reason: '$profileId $f',
        );
        expect(builtinVariant(profileId, f)!.flavor, f);
      }
    }
    expect(builtinVariant('custom', TemplateFlavor.logseq), isNull);
  });

  for (final t in kBuiltinTemplates.where(
    (t) => t.flavor == TemplateFlavor.logseq,
  )) {
    for (final c in Case.values) {
      test('[EXP-08/AC1] ${t.id} × ${c.name} is a valid Logseq page '
          '(properties block + outline bullets, TODO tasks)', () {
        final md = render(t, c);
        expect(logseqProblems(md), isEmpty);
        expect(md, contains('date:: [['));
        expect(md, isNot(contains('- [ ]')), reason: 'Logseq uses TODO');
      });
    }
  }

  test('[EXP-08/AC1] the validator rejects front-matter and broken '
      'outlines', () {
    expect(logseqProblems('---\ntitle: x\n---\n'), isNotEmpty);
    expect(logseqProblems('title:: x\n\n- a\n      - too deep\n'), [
      'line 4: skips a level',
    ]);
    expect(logseqProblems('title:: x\n\nparagraph\n'), [
      'line 3: not a bullet',
    ]);
    expect(logseqProblems('title:: x\n\n- a\n  - b\n- c\n'), isEmpty);
  });

  for (final t in kBuiltinTemplates.where(
    (t) => t.flavor == TemplateFlavor.plain,
  )) {
    test('${t.id}: plain variant has no front-matter, wikilinks, callouts '
        'or plugin syntax', () {
      final md = render(t, Case.full);
      expect(md, isNot(startsWith('---')));
      expect(md, startsWith('# '));
      expect(md, isNot(contains('[[')));
      expect(md, isNot(contains('> [!')));
      expect(md, isNot(contains('📅')));
      expect(md, isNot(contains('::')));
    });
  }
}
