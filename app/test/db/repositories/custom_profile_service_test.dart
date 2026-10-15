import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/pipeline/data/steps/render_write_steps.dart';
import 'package:vaultvoice/features/profiles/data/custom_profile_service.dart';
import 'package:vaultvoice/features/profiles/data/profile_registry.dart';
import 'package:vaultvoice/features/profiles/domain/builtin_profiles.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/domain/profile_draft.dart';
import 'package:vaultvoice/features/profiles/domain/prompt_builder.dart';
import 'package:vaultvoice/features/templates/data/template_note_renderer.dart';
import 'package:vaultvoice/features/templates/domain/builtin_templates.dart';

import '../../fakes/fake_clock.dart';
import '../../fakes/fake_llm_engine.dart';
import '../../fakes/fake_schema_grammar_converter.dart';
import '../db_test_utils.dart';
import '../fixtures/v2_fixture_database.dart' show V2FixtureDatabase;
import '../migrations/vaultvoice/generated/schema.dart';

/// A "Sprint planning" profile built field by field — no JSON anywhere.
ProfileDraft sprintDraft() => const ProfileDraft(
  id: '',
  name: 'Sprint Planning',
  description: 'Sprint goals, stories and risks',
  instructions: '- stories: one row per story mentioned.',
  fields: [
    FieldSpec(name: 'sprint_goal', kind: FieldKind.text, description: 'Goal'),
    FieldSpec(name: 'start_date', kind: FieldKind.date),
    FieldSpec(name: 'risks', kind: FieldKind.textList),
    FieldSpec(name: 'tasks', kind: FieldKind.checkboxList),
    FieldSpec(
      name: 'stories',
      kind: FieldKind.table,
      columns: [
        ColumnSpec(name: 'story'),
        ColumnSpec(name: 'points', kind: ColumnKind.number),
      ],
    ),
  ],
);

const Map<String, Object?> _data = {
  'sprint_goal': 'Ship offline mode',
  'start_date': 'next Monday',
  'risks': ['Vendor API keys are late'],
  'tasks': [
    {'task': 'Book the demo room', 'done': true},
    {'task': 'Write the release notes', 'done': false},
  ],
  'stories': [
    {'story': 'Offline sync', 'points': 8},
    {'story': 'Conflict banner', 'points': 3},
  ],
};

BuiltinProfiles _builtins({Map<String, String> replace = const {}}) =>
    BuiltinProfiles.parse({
      for (final a in kBuiltinProfileAssets)
        a: replace[a] ?? File(a).readAsStringSync(),
    });

BuiltinTemplates _templates() => BuiltinTemplates.parse({
  for (final t in kBuiltinTemplates)
    t.assetPath: File(t.assetPath).readAsStringSync(),
});

Future<String> _export(
  VaultVoiceDatabase db,
  ProfileRegistry registry,
  String profileId,
  Map<String, Object?> data,
) async {
  final profile = expectOk(await registry.get(profileId));
  final template = expectOk(
    await db.profilesRepository.getTemplate(profile.templateId),
  );
  final renderer = TemplateNoteRenderer(
    profiles: registry.builtins,
    templates: _templates(),
    appVersion: '1.0.0',
    userProfiles: {profile.id: profile},
    userTemplates: {template.id: template.body},
  );
  return renderer(
    NoteInput(
      recording: RecordingRow(
        id: 'rec-1',
        title: '',
        createdAt: DateTime(2026, 3, 2, 10),
        durationMs: 600000,
        status: RecordingStatus.values.first,
        source: RecordingSource.values.first,
        tags: const [],
        recovered: false,
      ),
      extraction: ExtractionRow(
        id: 'x1',
        recordingId: 'rec-1',
        profileId: profile.id,
        profileVersion: profile.version,
        modelId: 'llm',
        json: data,
        valid: true,
        createdAt: DateTime(2026, 3, 2, 10, 5),
      ),
      segments: const [],
    ),
  );
}

void main() {
  late VaultVoiceDatabase db;
  late ProfileRegistry registry;
  late bool pro;
  late CustomProfileService service;

  ProfileRegistry registryFor(VaultVoiceDatabase d, {BuiltinProfiles? b}) =>
      ProfileRegistry(
        dao: d.profilesRepository,
        builtins: b ?? _builtins(),
        grammarConverter: FakeSchemaGrammarConverter(),
        clock: FakeClock(t0),
      );

  setUp(() {
    db = memoryDb();
    registry = registryFor(db);
    pro = true;
    service = CustomProfileService(
      registry: registry,
      dao: db.profilesRepository,
      canEdit: () => pro,
      clock: FakeClock(t0),
    );
  });

  test('[PRF-07/AC1] a 5-field profile built without JSON saves, binds a '
      'generated template and exports correct Markdown', () async {
    final saved = expectOk(await service.save(sprintDraft()));
    expect(saved.id, 'sprint-planning');
    expect(saved.source, ProfileSource.user);
    expect(saved.tier, ProfileTier.pro);
    expect(saved.schema.properties.keys, [
      'sprint_goal',
      'start_date',
      'risks',
      'tasks',
      'stories',
    ]);
    expect(saved.templateId, 'sprint-planning-default');
    final md = await _export(db, registry, saved.id, _data);
    expect(md, contains('title: '));
    expect(md, contains('- **Sprint goal:** Ship offline mode'));
    expect(md, contains('- **Start date:** next Monday'));
    expect(md, contains('- Vendor API keys are late'));
    expect(md, contains('- [x] Book the demo room'));
    expect(md, contains('- [ ] Write the release notes'));
    expect(md, contains('| Offline sync | 8 |'));
    expect(md, isNot(contains('{{')));
  });

  test('[PRF-07/AC1] the "test on a recording" preview returns JSON and the '
      'rendered note for a draft', () async {
    final engine = FakeLlmEngine(
      tokens: const [
        '{"sprint_goal":"Ship offline mode","start_date":null,"risks":[],',
        '"tasks":[{"task":"Book the demo room","done":false}],"stories":[]}',
      ],
    );
    final preview = ProfilePreview(
      llm: engine,
      grammarFor: (_) async => const Ok('root ::= "{}"'),
    );
    final result = expectOk(
      await preview.run(
        sprintDraft(),
        input: (p) => PromptInput(
          profile: p,
          metadata: PromptMetadata(
            recordedAt: DateTime(2026, 3, 2),
            duration: const Duration(minutes: 3),
          ),
          segments: const [
            PromptSegment(
              start: Duration(seconds: 2),
              speaker: 'S1',
              text: 'Our goal is to ship offline mode.',
            ),
          ],
        ),
      ),
    );
    expect(result.valid, isTrue);
    expect(result.json, contains('"sprint_goal": "Ship offline mode"'));
    expect(result.markdown, contains('- [ ] Book the demo room'));
    final req = engine.requests.single;
    expect(req.grammar, 'root ::= "{}"');
    expect(req.prompt, contains('[00:00:02] S1: Our goal'));
    expect(req.systemPrompt, contains('- sprint_goal (text, max 200 chars'));
  });

  test('[PRF-07/AC1] duplicating a built-in yields an editable copy with '
      'the same fields', () async {
    final draft = expectOk(
      await service.duplicateAsDraft('warranty', copyName: 'My receipts'),
    );
    expect(draft.id, 'warranty-copy-1');
    expect(draft.fields.map((f) => f.name), contains('serial_number'));
    final saved = expectOk(await service.save(draft));
    expect(saved.source, ProfileSource.user);
    expect(saved.name, 'My receipts');
    expect(
      saved.schema.properties.keys,
      _builtins()['warranty']!.schema.properties.keys,
    );
  });

  test('Free tier: creation is refused; an existing custom profile stays '
      'readable (read-only, not deleted)', () async {
    expectOk(await service.save(sprintDraft()));
    pro = false;
    final refused = await service.save(sprintDraft().copyWith(name: 'Other'));
    expect((refused as Err).failure, isA<ProfileReadOnlyFailure>());
    expect(await service.delete('sprint-planning'), isA<Err<void>>());
    expect(
      expectOk(await registry.get('sprint-planning')).name,
      'Sprint Planning',
    );
  });

  test('[PRF-07/AC2] custom profiles survive an app update that ships a '
      'new built-in version', () async {
    final saved = expectOk(await service.save(sprintDraft()));
    final v2 = File('assets/profiles/meeting.yaml')
        .readAsStringSync()
        .replaceFirst('version: 1', 'version: 2');
    final updated = registryFor(
      db,
      b: _builtins(replace: {'assets/profiles/meeting.yaml': v2}),
    );
    expect(updated.builtins['meeting']!.version, 2);
    final again = expectOk(await updated.get(saved.id));
    expect(again.toJson(), saved.toJson());
    final md = await _export(db, updated, saved.id, _data);
    expect(md, contains('- **Sprint goal:** Ship offline mode'));
  });

  group('[PRF-07/AC2] custom profiles survive DB migrations', () {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    late SchemaVerifier verifier;
    setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

    test('[PRF-07/AC2] rows written by the current app open after the '
        'v1 → current migration path and still export', () async {
      final saved = expectOk(await service.save(sprintDraft()));
      final row = expectOk(await db.profilesRepository.getProfile(saved.id));
      final tpl = expectOk(
        await db.profilesRepository.getTemplate(saved.templateId),
      );
      final schema = await verifier.schemaAt(1);
      final raw = schema.rawDatabase
        ..execute(
          'INSERT INTO profiles (id, version, source, definition, '
          'updated_at) VALUES (?, ?, ?, ?, ?)',
          [
            row.id,
            row.version,
            row.source.name,
            jsonEncode(row.definition),
            t0.millisecondsSinceEpoch,
          ],
        )
        ..execute(
          'INSERT INTO templates (id, profile_id, body, filename_pattern, '
          'updated_at) VALUES (?, ?, ?, ?, ?)',
          [tpl.id, tpl.profileId, tpl.body, tpl.filenamePattern, 0],
        );
      expect(raw, isNotNull);

      // Current app (schema = v1 today) on the old file.
      final current = VaultVoiceDatabase(schema.newConnection());
      addTearDown(current.close);
      final reg = registryFor(current);
      final loaded = expectOk(await reg.get(saved.id));
      expect(loaded.toJson(), saved.toJson());
      expect(
        await _export(current, reg, saved.id, _data),
        contains('| Conflict banner | 3 |'),
      );

      // A future v2 migration (production strategy + fixture step) keeps
      // the rows intact.
      final schema2 = await verifier.schemaAt(1);
      schema2.rawDatabase
        ..execute(
          'INSERT INTO profiles (id, version, source, definition, '
          'updated_at) VALUES (?, ?, ?, ?, ?)',
          [row.id, row.version, row.source.name, jsonEncode(row.definition), 0],
        )
        ..execute(
          'INSERT INTO templates (id, profile_id, body, filename_pattern, '
          'updated_at) VALUES (?, ?, ?, ?, ?)',
          [tpl.id, tpl.profileId, tpl.body, tpl.filenamePattern, 0],
        );
      final v2 = V2FixtureDatabase(schema2.newConnection());
      addTearDown(v2.close);
      await v2.validateDatabaseSchema();
      final p2 = await v2.select(v2.profiles).getSingle();
      expect(p2.definition, row.definition);
      final t2 = await v2.select(v2.templates).getSingle();
      expect(t2.body, tpl.body);
    });
  });
}
