import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/features/profiles/domain/profile_issue.dart';
import 'package:vaultvoice/features/profiles/domain/render_context.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';
import 'package:vaultvoice/features/templates/data/template_editor_providers.dart';
import 'package:vaultvoice/features/templates/data/template_store.dart';
import 'package:vaultvoice/features/templates/domain/template_editing.dart';

import '../../db/db_test_utils.dart';
import '../../fakes/fake_clock.dart';
import 'template_fixtures.dart';

void main() {
  group('completions', () {
    final all = templateCompletions(rootShapeFor(profile('meeting')));
    final paths = [for (final c in all) c.path];

    test(
      'data from the profile schema, meta, transcript, helpers, lambdas',
      () {
        expect(paths, containsAll(['data.title', 'data.action_items']));
        expect(
          paths,
          containsAll(['data.has_action_items', 'has_action_items']),
        );
        expect(
          paths,
          containsAll(['meta.date', 'meta.title', 'meta.has_title']),
        );
        expect(paths, contains('transcript.segments'));
        // List item fields are offered bare (in scope inside the section).
        expect(paths, containsAll(['owner', 'has_owner', 'due']));
        expect(paths, containsAll(['yaml', 'checkbox', 'transcript_block']));
        expect(paths.toSet().length, paths.length, reason: 'no duplicates');
        final warranty = [
          for (final c in templateCompletions(
            rootShapeFor(profile('warranty')),
          ))
            c.path,
        ];
        expect(warranty, isNot(contains('data.action_items')));
      },
    );

    test('input detection inside an open tag only', () {
      expect(mustacheInput('# {{data.ti'), 'data.ti');
      expect(mustacheInput('{{#data.act'), 'data.act');
      expect(mustacheInput('{{^has_'), 'has_');
      expect(mustacheInput('{{/data'), 'data');
      expect(mustacheInput('{{ '), '');
      expect(mustacheInput('{{data.title}} more'), isNull);
      expect(mustacheInput('plain text'), isNull);
      expect(mustacheInput('{{data.title}} {{me'), 'me');
    });

    test('matching: prefix first, then segment, limited', () {
      final m = matchCompletions(all, 'data.ti');
      expect(m.first.path, 'data.title');
      final seg = matchCompletions(all, 'title');
      expect([for (final c in seg) c.path], contains('data.title'));
      expect(
        matchCompletions(all, 'data.title').map((c) => c.path),
        isNot(contains('data.title')),
      );
      expect(matchCompletions(all, '', limit: 5), hasLength(5));
    });
  });

  group('preview', () {
    test('[EXP-07/AC1] syntax errors carry line and column for inline '
        'highlighting', () {
      final p = previewTemplate(
        '# {{data.title}}\n\n{{#data.action_items}}\n- {{text}}\n',
        profile: profile('meeting'),
        data: const {},
        name: 'mine',
      );
      expect(p.markdown, isNull);
      expect(p.isValid, isFalse);
      final pos = issuePosition(p.issues.first);
      expect(pos, isNotNull);
      expect(pos!.line, greaterThanOrEqualTo(3));
    });

    test('[EXP-07/AC1] unknown variables are flagged at their position', () {
      final p = previewTemplate(
        'ok\n  {{data.titel}}\n',
        profile: profile('meeting'),
        data: const {},
        name: 'mine',
      );
      expect(p.markdown, isNotNull, reason: 'parses; renders leniently');
      expect(issuePosition(p.issues.single), (line: 2, column: 3));
    });

    test('[EXP-07/AC1] the built-in meeting template renders with sample data '
        'well inside the 200 ms preview budget', () {
      final source = templateSource('meeting-default');
      previewTemplate(source, profile: profile('meeting'), data: const {});
      final sw = Stopwatch()..start();
      late TemplatePreview p;
      for (var i = 0; i < 10; i++) {
        p = previewTemplate(
          source,
          profile: profile('meeting'),
          data: sampleDataFor(profile('meeting')),
        );
      }
      sw.stop();
      expect(p.isValid, isTrue);
      expect(p.markdown, startsWith('---\n'));
      expect(p.markdown, contains('12m 34s'));
      // Average render ≪ 200 ms − 150 ms debounce.
      expect(sw.elapsedMilliseconds / 10, lessThan(50));
    });

    test('sample data is the profile example; positions parse', () {
      final sample = sampleDataFor(profile('meeting'));
      expect(sample.keys, profile('meeting').schema.properties.keys);
      expect(sample['action_items'], hasLength(1));
      expect(issuePosition(const ProfileIssue('x', 'm')), isNull);
    });
  });

  group('store', () {
    test(
      'built-in profiles are never written to templates.profile_id',
      () async {
        final db = memoryDb();
        final store = DriftTemplateStore(
          templates: db.profilesRepository,
          settings: db.settingsRepository,
          builtinProfileIds: kBuiltinProfileIds,
          clock: FakeClock(t0),
        );
        expectOk(
          await store.save(
            const CustomTemplate(
              id: 'mine',
              body: '# {{data.title}}',
              filenamePattern: '{{slug}}.md',
              profileId: 'meeting',
              baseId: 'meeting-default',
            ),
          ),
        );
        final row = (await db.select(db.templates).get()).single;
        expect(row.profileId, isNull);
        final listed = (await store.watch().first).single;
        expect(listed.profileId, 'meeting');
        expect(listed.baseId, 'meeting-default');

        // A user profile row can be referenced.
        expectOk(
          await db.profilesRepository.upsertProfile(
            ProfilesCompanion.insert(
              id: 'site',
              version: 1,
              source: ProfileSource.user,
              definition: const {'id': 'site'},
              updatedAt: t0,
            ),
          ),
        );
        expectOk(
          await store.save(
            const CustomTemplate(
              id: 'site-t',
              body: 'x',
              filenamePattern: '{{slug}}.md',
              profileId: 'site',
            ),
          ),
        );
        expect(
          expectOk(await db.profilesRepository.getTemplate('site-t')).profileId,
          'site',
        );

        expectOk(await store.bind('meeting', 'mine'));
        expect(await store.watchBindings().first, {'meeting': 'mine'});
        expectOk(await store.delete('mine'));
        expect(await store.watchBindings().first, isEmpty);
        expect(
          (await db.settingsRepository.get(SettingKeys.templatesBindings))
              .valueOrNull,
          isEmpty,
        );
      },
    );

    test('template ids are unique slugs', () {
      expect(templateIdFrom('My Meeting!', {}), 'my-meeting');
      expect(templateIdFrom('My Meeting', {'my-meeting'}), 'my-meeting-2');
      expect(templateIdFrom('!!!', {}), 'template');
    });
  });
}
