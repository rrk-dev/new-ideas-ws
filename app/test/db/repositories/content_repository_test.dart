import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';

import '../db_test_utils.dart';

ProfilesCompanion profile(String id, {int version = 1}) =>
    ProfilesCompanion.insert(
      id: id,
      version: version,
      source: ProfileSource.builtin,
      definition: {'name': id, 'fields': <Object?>[]},
      updatedAt: t0,
    );

TemplatesCompanion template(String id, {String? profileId, String body = ''}) =>
    TemplatesCompanion.insert(
      id: id,
      profileId: Value(profileId),
      body: body,
      filenamePattern: '{{date}}-{{title}}.md',
      updatedAt: t0,
    );

ExtractionsCompanion extraction(String id, {Duration age = Duration.zero}) =>
    ExtractionsCompanion.insert(
      id: id,
      recordingId: 'r1',
      profileId: 'meeting',
      profileVersion: 1,
      modelId: 'qwen',
      json: {'summary': 's'},
      valid: true,
      createdAt: t0.add(age),
    );

ActionItemsCompanion item(String extractionId, String text) =>
    ActionItemsCompanion.insert(
      recordingId: 'r1',
      extractionId: extractionId,
      body: text,
    );

void main() {
  late VaultVoiceDatabase db;
  setUp(() async {
    db = memoryDb();
    await seedRecording(db, 'r1');
  });

  group('ProfilesRepository', () {
    test('[FND-04/AC2] profiles CRUD + stream', () async {
      final repo = db.profilesRepository;
      final probe = StreamProbe(
        repo.watchProfiles().map(
          (r) => [for (final p in r) '${p.id}@${p.version}'],
        ),
      );
      expect(await probe.settled, isEmpty);

      expectOk(await repo.upsertProfile(profile('meeting')));
      expectOk(await repo.upsertProfile(profile('engineering')));
      expect(await probe.settled, ['engineering@1', 'meeting@1']);
      expectOk(await repo.upsertProfile(profile('meeting', version: 2)));
      expect(await probe.settled, ['engineering@1', 'meeting@2']);
      final p = expectOk(await repo.getProfile('meeting'));
      expect(p.definition, {'name': 'meeting', 'fields': <Object?>[]});
      expect(p.source, ProfileSource.builtin);

      expectOk(await repo.deleteProfile('engineering'));
      expect(await probe.settled, ['meeting@2']);
      expectErr(await repo.getProfile('engineering'), 'not found');
      expectErr(await repo.deleteProfile('engineering'), 'not found');
    });

    test(
      '[FND-04/AC2] templates CRUD + stream, survive profile deletion',
      () async {
        final repo = db.profilesRepository;
        expectOk(await repo.upsertProfile(profile('meeting')));
        final all = StreamProbe(
          repo.watchTemplates().map((r) => [for (final t in r) t.id]),
        );
        final forMeeting = StreamProbe(
          repo
              .watchTemplates(profileId: 'meeting')
              .map((r) => [for (final t in r) t.id]),
        );
        expect(await all.settled, isEmpty);

        expectOk(await repo.upsertTemplate(template('default')));
        expectOk(
          await repo.upsertTemplate(template('meet', profileId: 'meeting')),
        );
        expect(await all.settled, ['default', 'meet']);
        expect(await forMeeting.settled, ['meet']);
        expectOk(
          await repo.upsertTemplate(
            template('meet', profileId: 'meeting', body: '# {{title}}'),
          ),
        );
        expect(expectOk(await repo.getTemplate('meet')).body, '# {{title}}');
        expectErr(
          await repo.upsertTemplate(template('bad', profileId: 'unknown')),
        );

        expectOk(await repo.deleteProfile('meeting'));
        expect(await forMeeting.settled, isEmpty);
        expect(expectOk(await repo.getTemplate('meet')).profileId, isNull);

        expectOk(await repo.deleteTemplate('meet'));
        expect(await all.settled, ['default']);
        expectErr(await repo.getTemplate('meet'), 'not found');
        expectErr(await repo.deleteTemplate('meet'), 'not found');
      },
    );
  });

  group('ExtractionsRepository', () {
    test('[FND-04/AC2] extractions CRUD + stream (newest first)', () async {
      final repo = db.extractionsRepository;
      final probe = StreamProbe(
        repo.watchForRecording('r1').map((r) => [for (final e in r) e.id]),
      );
      expect(await probe.settled, isEmpty);
      expectOk(await repo.upsert(extraction('e1')));
      expectOk(
        await repo.upsert(extraction('e2', age: const Duration(minutes: 1))),
      );
      expect(await probe.settled, ['e2', 'e1']);
      expect(expectOk(await repo.get('e1')).json, {'summary': 's'});

      expectOk(await repo.deleteById('e2'));
      expect(await probe.settled, ['e1']);
      expectErr(await repo.get('e2'), 'not found');
      expectErr(await repo.deleteById('e2'), 'not found');
    });

    test(
      '[FND-04/AC2] action items replace atomically, stream and toggle',
      () async {
        final repo = db.extractionsRepository;
        expectOk(await repo.upsert(extraction('e1')));
        final open = StreamProbe(
          repo
              .watchActionItems(openOnly: true)
              .map((r) => [for (final a in r) a.body]),
        );
        final forRec = StreamProbe(
          repo.watchActionItems(recordingId: 'r1').map((r) => r.length),
        );
        expect(await open.settled, isEmpty);

        expectOk(
          await repo.replaceActionItems('e1', [
            item('e1', 'Send notes'),
            item('e1', 'Book room'),
          ]),
        );
        expect(await open.settled, ['Send notes', 'Book room']);
        // Re-render replaces, never duplicates.
        expectOk(
          await repo.replaceActionItems('e1', [
            item('e1', 'Send notes'),
            item('e1', 'Book room'),
          ]),
        );
        expect(await forRec.settled, 2);

        final first = (await db.select(db.actionItems).get()).first;
        expectOk(await repo.setActionItemDone(first.id, done: true, at: t0));
        expect(await open.settled, ['Book room']);
        final done = (await db.select(db.actionItems).get()).first;
        expect(done.doneAt, t0);
        expectOk(await repo.setActionItemDone(first.id, done: false));
        expect(await open.settled, hasLength(2));
        expect((await db.select(db.actionItems).get()).first.doneAt, isNull);
        expectErr(await repo.setActionItemDone(9999, done: true), 'not found');

        expectOk(await repo.deleteById('e1'));
        expect(await forRec.settled, 0);
      },
    );
  });

  group('VaultRepository', () {
    VaultTargetsCompanion target(String id, {Duration age = Duration.zero}) =>
        VaultTargetsCompanion.insert(
          id: id,
          platform: VaultPlatform.androidSaf,
          displayName: 'Vault $id',
          handle: 'content://tree/$id',
          createdAt: t0.add(age),
        );

    ExportsCompanion export(String id, {ExportStatus? status}) =>
        ExportsCompanion.insert(
          id: id,
          recordingId: 'r1',
          targetId: 'v1',
          relPath: 'Meetings/note.md',
          contentHash: 'h1',
          status: status ?? ExportStatus.pending,
          updatedAt: t0,
        );

    test('[FND-04/AC2] vault targets CRUD + stream', () async {
      final repo = db.vaultRepository;
      final probe = StreamProbe(
        repo.watchTargets().map((r) => [for (final t in r) t.displayName]),
      );
      expect(await probe.settled, isEmpty);
      expectOk(await repo.upsertTarget(target('v1')));
      expectOk(
        await repo.upsertTarget(target('v2', age: const Duration(seconds: 1))),
      );
      expect(await probe.settled, ['Vault v1', 'Vault v2']);
      expect(
        expectOk(await repo.getTarget('v1')).platform,
        VaultPlatform.androidSaf,
      );
      expectOk(await repo.deleteTarget('v2'));
      expect(await probe.settled, ['Vault v1']);
      expectErr(await repo.getTarget('v2'), 'not found');
      expectErr(await repo.deleteTarget('v2'), 'not found');
    });

    test(
      '[FND-04/AC2] routing rules CRUD + stream in priority order',
      () async {
        final repo = db.vaultRepository;
        expectOk(await repo.upsertTarget(target('v1')));
        final probe = StreamProbe(
          repo.watchRules().map((r) => [for (final x in r) x.id]),
        );
        expect(await probe.settled, isEmpty);
        RoutingRulesCompanion rule(String id, int priority) =>
            RoutingRulesCompanion.insert(
              id: id,
              priority: priority,
              match: {'profile': 'meeting'},
              targetId: 'v1',
            );
        expectOk(await repo.upsertRule(rule('late', 20)));
        expectOk(await repo.upsertRule(rule('early', 10)));
        expect(await probe.settled, ['early', 'late']);
        expectOk(await repo.upsertRule(rule('late', 5)));
        expect(await probe.settled, ['late', 'early']);
        expectOk(await repo.deleteRule('late'));
        expect(await probe.settled, ['early']);
        expectErr(await repo.deleteRule('late'), 'not found');
        // Deleting a target removes its rules.
        expectOk(await repo.deleteTarget('v1'));
        expect(await probe.settled, isEmpty);
      },
    );

    test('[FND-04/AC2] exports upsert per (recording, target), stream and '
        'filter by status', () async {
      final repo = db.vaultRepository;
      expectOk(await repo.upsertTarget(target('v1')));
      final pending = StreamProbe(
        repo
            .watchExports(statuses: {ExportStatus.pending})
            .map((r) => [for (final e in r) e.id]),
      );
      final forRec = StreamProbe(
        repo
            .watchExports(recordingId: 'r1')
            .map((r) => [for (final e in r) '${e.id}:${e.status.name}']),
      );
      expect(await pending.settled, isEmpty);

      expectOk(await repo.upsertExport(export('x1')));
      expect(await pending.settled, ['x1']);
      // Same (recording, target): the row is updated, not duplicated.
      expectOk(await repo.upsertExport(export('x1')));
      expect(await forRec.settled, ['x1:pending']);

      expectOk(
        await repo.updateExport(
          'x1',
          const ExportsCompanion(
            status: Value(ExportStatus.written),
            attempts: Value(1),
          ),
        ),
      );
      expect(await pending.settled, isEmpty);
      expect(await forRec.settled, ['x1:written']);
      expect(expectOk(await repo.getExport('x1')).attempts, 1);

      expectOk(await repo.deleteExport('x1'));
      expect(await forRec.settled, isEmpty);
      expectErr(await repo.getExport('x1'), 'not found');
      expectErr(
        await repo.updateExport(
          'x1',
          const ExportsCompanion(attempts: Value(2)),
        ),
        'not found',
      );
      expectErr(await repo.deleteExport('x1'), 'not found');
    });
  });

  group('ModelsRepository', () {
    test('[FND-04/AC2] installed models CRUD + stream by type', () async {
      final repo = db.modelsRepository;
      ModelsInstalledCompanion model(String id, ModelType type, String v) =>
          ModelsInstalledCompanion.insert(
            id: id,
            type: type,
            version: v,
            path: 'models/$id/model.bin',
            sha256: 'ab' * 32,
            size: 1024,
            installedAt: t0,
          );
      final all = StreamProbe(
        repo.watchAll().map((r) => [for (final m in r) '${m.id}@${m.version}']),
      );
      final llm = StreamProbe(
        repo
            .watchAll(type: ModelType.llm)
            .map((r) => [for (final m in r) m.id]),
      );
      expect(await all.settled, isEmpty);

      expectOk(await repo.upsert(model('whisper-base', ModelType.stt, '1')));
      expectOk(await repo.upsert(model('qwen', ModelType.llm, '1')));
      expect(await all.settled, ['qwen@1', 'whisper-base@1']);
      expect(await llm.settled, ['qwen']);
      expectOk(await repo.upsert(model('qwen', ModelType.llm, '2')));
      expect(await all.settled, ['qwen@2', 'whisper-base@1']);
      expect(expectOk(await repo.get('qwen')).path, 'models/qwen/model.bin');

      expectOk(await repo.deleteById('qwen'));
      expect(await llm.settled, isEmpty);
      expectErr(await repo.get('qwen'), 'not found');
      expectErr(await repo.deleteById('qwen'), 'not found');
    });
  });

  group('SettingsRepository', () {
    test('[FND-04/AC2] settings CRUD + streams with JSON values', () async {
      final repo = db.settingsRepository;
      final one = StreamProbe(repo.watch('auto_process'));
      final all = StreamProbe(repo.watchAll());
      expect(await one.settled, isNull);
      expect(await all.settled, isEmpty);

      expectOk(await repo.set('auto_process', true));
      expectOk(await repo.set('stt_rtf', {'avg': 0.31, 'n': 4}));
      expect(await one.settled, isTrue);
      expect(await all.settled, {
        'auto_process': true,
        'stt_rtf': {'avg': 0.31, 'n': 4},
      });
      expectOk(await repo.set('auto_process', false));
      expect(await one.settled, isFalse);
      expect(expectOk(await repo.get('stt_rtf')), {'avg': 0.31, 'n': 4});
      expect(expectOk(await repo.get('unset')), isNull);

      expectOk(await repo.remove('auto_process'));
      expectOk(await repo.remove('auto_process')); // idempotent
      expect(await one.settled, isNull);
      expect(await all.settled, hasLength(1));
      expectErr(await repo.set('bad', Object()));
    });
  });
}
