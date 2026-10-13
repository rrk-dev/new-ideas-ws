import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/features/profiles/domain/render_context.dart';
import 'package:vaultvoice/features/profiles/domain/template_variables.dart';
import 'package:vaultvoice/features/templates/domain/markdown_sanitizer.dart';
import 'package:vaultvoice/features/templates/domain/note_context.dart';
import 'package:vaultvoice/features/templates/domain/template_engine.dart';
import 'package:vaultvoice/features/templates/domain/template_lambdas.dart';
import 'package:yaml/yaml.dart';

import 'template_fixtures.dart';

CompiledTemplate compile(String source) =>
    engine.compile(source, name: 't').valueOrNull!;

String render(
  String source, [
  Map<String, Object?>? context,
  LambdaOptions options = const LambdaOptions(),
]) {
  final note = engine.render(
    compile(source),
    context ?? contextFor('meeting', meetingFull()),
    options: options,
  );
  expect(note.warnings, isEmpty);
  return note.markdown;
}

void main() {
  group('syntax errors carry line and column', () {
    test('unclosed section', () {
      final r = engine.compile('# T\n\n{{#data.attendees}}\n- {{.}}\n');
      final f = r.failureOrNull! as TemplateSyntaxFailure;
      expect((f.line, f.column), (3, 1));
      expect(f.message, startsWith('template template:3:1:'));
    });

    test('mismatched close and invalid tag names', () {
      final f1 =
          engine.compile('a\n  {{#x}}b{{/y}}').failureOrNull!
              as TemplateSyntaxFailure;
      expect(f1.line, 2);
      final f2 =
          engine.compile('ok\nfine {{ bad name! }}').failureOrNull!
              as TemplateSyntaxFailure;
      expect((f2.line, f2.column), (2, 6));
    });

    test('validate reports syntax first, then variables, with positions', () {
      final shape = rootShapeFor(profile('meeting'));
      expect(
        engine.validate('x\n{{#data.topics}}', shape).single.toString(),
        startsWith('template:2:1:'),
      );
      expect(
        engine.validate('{{data.titl}}', shape).single.toString(),
        contains('did you mean data.title'),
      );
      expect(
        engine.validate(templateSource('meeting-default'), shape),
        isEmpty,
      );
    });
  });

  test('path-argument lambdas are checked: lists, md_table columns, '
      'date/duration paths', () {
    final shape = rootShapeFor(profile('engineering'));
    List<String> check(String s) => [
      for (final i in engine.validate(s, shape)) i.toString(),
    ];
    expect(
      check(
        '{{#md_table}}data.tradeoffs|option,pros{{/md_table}}'
        '{{#bullets}}data.concepts{{/bullets}}'
        '{{#data.todos}}{{#date}}t|HH{{/date}}{{/data.todos}}'
        '{{#duration}}meta.duration_ms|minutes{{/duration}}',
      ),
      isEmpty,
    );
    expect(
      check('{{#md_table}}data.tradeoffs|option,nope{{/md_table}}').single,
      contains('md_table column "nope"'),
    );
    expect(
      check('{{#bullets}}data.title{{/bullets}}').single,
      contains('must be a list'),
    );
    expect(
      check('{{#date}}data.concepts|YYYY{{/date}}').single,
      contains('must be a scalar'),
    );
    expect(
      check('{{#date}}data.nope|YYYY{{/date}}').single,
      contains('not a variable path'),
    );
  });

  group('missing variables at export render empty with a warning', () {
    test('strict failure falls back to lenient and logs position + name', () {
      final note = engine.render(
        compile('# {{data.title}}\nA {{data.nope}} B\n'),
        contextFor('meeting', meetingFull()),
      );
      expect(note.markdown, '# Q4 Planning Sync\nA  B\n');
      expect(note.warnings.single, startsWith('t:2:3:'));
      expect(note.warnings.single, contains('data.nope'));
      // Content-free: the warning never contains rendered values.
      expect(note.warnings.single, isNot(contains('Q4')));
    });

    test('a section on a string throws in strict mode and still renders', () {
      final note = engine.render(
        compile(
          '{{#data.title}}x{{/data.title}}{{^data.title}}y{{/data.title}}',
        ),
        contextFor('meeting', meetingFull()),
      );
      expect(note.hasWarnings, isTrue);
      expect(note.warnings.first, contains('inverse section'));
    });

    test('invalid meta.date is blanked, never emitted unquoted', () {
      final meta = metaFull()..['date'] = '2026\n---';
      final note = engine.render(
        compile('---\ndate: {{meta.date}}\n---\n'),
        contextFor('meeting', meetingFull(), meta: meta),
      );
      expect(note.markdown, '---\ndate:\n---\n');
      expect(note.warnings.single, contains('meta.date'));
    });
  });

  group('lambdas', () {
    test('the lambda set equals the template check list', () {
      expect(buildLambdas().keys.toSet(), kTemplateLambdas);
    });

    test('yaml quotes the raw value; yaml_list emits [] for non-lists', () {
      final ctx = contextFor('meeting', {
        ...meetingFull(),
        'title': 'a "b" \\ c\n# d {{e}} [[f]]',
      });
      final out = render(
        't: {{#yaml}}{{data.title}}{{/yaml}}\n'
        'l: {{#yaml_list}}data.attendees{{/yaml_list}}\n'
        'n: {{#yaml_list}}data.title{{/yaml_list}}\n'
        'm: {{#yaml_list}}meta.nope{{/yaml_list}}\n',
        ctx,
      );
      final y = loadYaml(out) as YamlMap;
      expect(y['t'], 'a "b" \\ c\n# d {{e}} [[f]]');
      expect(y['l'], ['Priya', 'Sam', 'Lena']);
      expect(y['n'], isEmpty);
      expect(y['m'], isEmpty);
    });

    test('wikilink, slug, upper, lower, trim', () {
      final ctx = contextFor('meeting', {
        ...meetingFull(),
        'title': ' Q4 [Plan] | #1 ^x Ünïcödé 🎉 ',
      });
      expect(
        render('{{#wikilink}}{{data.title}}{{/wikilink}}', ctx),
        '[[Q4 Plan 1 x Ünïcödé 🎉]]\n',
      );
      expect(
        render('{{#slug}}{{data.title}}{{/slug}}', ctx),
        'q4-plan-1-x-ünïcödé\n',
      );
      expect(render('{{#upper}}ab{{meta.time}}{{/upper}}'), 'AB14:05\n');
      expect(render('{{#lower}}AB{{/lower}}'), 'ab\n');
      expect(render('[{{#trim}}  x  {{/trim}}]'), '[x]\n');
      expect(render('{{#wikilink}} {{/wikilink}}x'), 'x\n');
    });

    test('date formats meta.date/time or a path', () {
      expect(
        render('{{#date}}DD.MM.YYYY HH:mm{{/date}}'),
        '13.10.2026 14:05\n',
      );
      expect(render('{{#date}}{{/date}}'), '2026-10-13\n');
      expect(render('{{#date}}D/M/YY H{{/date}}'), '13/10/26 14\n');
      expect(
        render(
          '{{#data.action_items}}{{#date}}due_iso|DD.MM.{{/date}} '
          '{{/data.action_items}}',
        ),
        '16.10. 31.10.\n',
      );
      final ctx = contextFor('meeting', meetingFull());
      (ctx['meta']! as Map<String, Object?>)['time'] = 'x';
      expect(render('{{#date}}HH{{/date}}|', ctx), '00|\n');
    });

    test('duration formats meta.duration_ms', () {
      expect(render('{{#duration}}{{/duration}}'), '1h 02m\n');
      expect(render('{{#duration}}hh:mm:ss{{/duration}}'), '01:02:03\n');
      expect(render('{{#duration}}h:mm:ss{{/duration}}'), '1:02:03\n');
      expect(render('{{#duration}}mm:ss{{/duration}}'), '62:03\n');
      expect(render('{{#duration}}minutes{{/duration}}'), '62\n');
      expect(formatDuration(754000), '12m 34s');
      expect(formatDuration(5000), '5s');
      expect(formatDuration(-1), '0s');
    });

    test('checkbox, bullets and md_table', () {
      expect(
        render(
          '{{#data.action_items}}{{#checkbox}}{{task}}{{/checkbox}}\n'
          '{{/data.action_items}}',
        ),
        '- [ ] Update the client SDK\n- [ ] Draft the migration guide\n',
      );
      expect(
        render('{{#checkbox}}x{{/checkbox}}', {
          ...contextFor('meeting', {}),
          'done': true,
        }),
        '- [x] x\n',
      );
      expect(
        render('{{#bullets}}data.topics{{/bullets}}'),
        '- API versioning\n- Roadmap\n',
      );
      expect(render('{{#bullets}}data.nope{{/bullets}}x'), 'x\n');
      final ctx = contextFor('engineering', {
        ...engineeringFull(),
        'tradeoffs': [
          {
            'option': 'A | B',
            'pros': ['p1', 'p|2'],
            'cons': <String>[],
          },
        ],
      });
      expect(
        render(
          '{{#md_table}}data.tradeoffs|option,pros,cons{{/md_table}}',
          ctx,
        ),
        '| Option | Pros | Cons |\n| --- | --- | --- |\n'
        r'| A \| B | p1; p\|2 |  |'
        '\n',
      );
      expect(
        render('{{#md_table}}data.tradeoffs{{/md_table}}', ctx),
        startsWith('| Option | Pros | Cons |'),
      );
    });

    test('transcript_block, audio_link and code_block', () {
      expect(
        render('{{transcript_block}}'),
        "> [!note]- Transcript\n> [00:00:05] Priya: Let's lock the API "
        "version.\n> [00:00:12] Sam: I'll update the SDK by Friday.\n"
        '> [00:01:05] Background noise.\n',
      );
      expect(
        render(
          '{{transcript_block}}x',
          contextFor('meeting', {}, transcript: {}),
        ),
        'x\n',
      );
      expect(render('{{audio_link}}x'), 'x\n');
      expect(
        render(
          '{{audio_link}}',
          null,
          const LambdaOptions(audioAttachment: '../rec]].m4a'),
        ),
        '![[attachments/..rec.m4a]]\n',
      );
      final ctx = contextFor('meeting', {
        ...meetingFull(),
        'summary': 'a ```` b\n\n```\nc',
      });
      expect(
        render('{{#code_block}}{{data.summary}}{{/code_block}}', ctx),
        '`````\na ```` b\n\n```\nc\n`````\n',
      );
    });
  });

  group('sanitizer', () {
    test('inline values cannot start blocks or create syntax', () {
      expect(sanitizeInline('# Head'), 'Head');
      expect(sanitizeInline('### Head'), 'Head');
      expect(sanitizeInline('#tag stays'), '#tag stays');
      expect(sanitizeInline('> - * x'), 'x');
      expect(sanitizeInline('---'), '');
      expect(sanitizeInline('=== x'), 'x');
      expect(sanitizeInline('a\n---\nb\r\nc\u2028d'), 'a --- b c d');
      expect(sanitizeInline('[[x]] {{y}}'), r'\[\[x\]\] {\{y}}');
      expect(sanitizeInline('<!-- c --> `x`'), r'\<!-- c --> \`x\`');
      expect(sanitizeInline('a\u0000b\u202Ec\u202Bd'), 'abc\u202Bd');
      expect(sanitizeInline('-5 degrees'), '-5 degrees');
    });

    test('yamlQuote escapes everything YAML could misread', () {
      for (final s in [...adversarialStrings, tenK, 'a\u0085b\u2028c\uFEFF']) {
        final q = yamlQuote(s);
        expect(q.contains('\n'), isFalse);
        expect((loadYaml('k: $q') as YamlMap)['k'], s);
      }
      expect(yamlQuote('x\uD800y'), '"x�y"');
      expect(fixSurrogates('🎉\uDC00'), '🎉�');
    });

    test('slugify keeps scripts, drops emoji, caps length', () {
      expect(slugify('Hello, World! 🎉'), 'hello-world');
      expect(slugify('שלום עולם'), 'שלום-עולם');
      expect(slugify('---'), '');
      expect(slugify('a' * 100), 'a' * 60);
      expect(slugify('${'a' * 59} b'), 'a' * 59);
    });

    test('InlineText prints sanitized, raw inside renderRaw', () {
      final t = InlineText('# x {{y}}');
      expect('$t', r'x {\{y}}');
      expect(renderRaw(() => '$t'), '# x {{y}}');
    });
  });

  test('summary-only context normalizes any data', () {
    final ctx = normalizeContext(
      kSummaryOnlyRootShape,
      data: {'title': 5, 'summary': ''},
      meta: metaEmpty(),
      transcript: const {},
    );
    expect(ctx['has_title'], isFalse);
    expect(ctx['has_summary'], isFalse);
    expect(
      isoWithOffset(DateTime.utc(2026, 1, 2, 3, 4, 5)),
      '2026-01-02T03:04:05+00:00',
    );
    expect(timestamp(3723000), '01:02:03');
  });
}
