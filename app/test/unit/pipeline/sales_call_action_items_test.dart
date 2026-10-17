import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_engines.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_orchestrator.dart';
import 'package:vaultvoice/features/pipeline/data/steps/render_write_steps.dart';
import 'package:vaultvoice/features/profiles/domain/builtin_profiles.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';

import '../../db/db_test_utils.dart';
import '../../fakes/fake_vault_writer.dart';
import 'pipeline_test_utils.dart';

final BuiltinProfiles _builtins = BuiltinProfiles.parse({
  for (final a in kBuiltinProfileAssets) a: File(a).readAsStringSync(),
});

/// Wiring test: the scripted answer is not grounded in the fake `chunk_0`
/// transcript, so `ground_to_transcript` is removed (as in
/// `production_steps_test.dart`).
Profile? _ungrounded(String id) {
  final p = _builtins[id];
  if (p == null) return null;
  final json = p.toJson();
  (json['post_process']! as List).remove('ground_to_transcript');
  return Profile.fromJson(json);
}

const Map<String, Object?> _sales = {
  'title': 'Northwind pilot',
  'summary': 'Pilot discussion.',
  'participants': ['Ana', 'Ben'],
  'needs': <String>[],
  'objections': <Object?>[],
  'commitments': [
    {'who': 'Ana', 'what': 'Share a migration plan', 't': '00:00:00'},
  ],
  'next_steps': [
    {
      'task': 'Send the pilot proposal',
      'owner': 'Ana',
      'due': '2026-03-13',
      't': '00:00:00',
    },
    {'task': 'Book a finance review', 'owner': null, 'due': null, 't': null},
  ],
  'competitors_mentioned': <String>[],
  'open_questions': <String>[],
};

const Map<String, Object?> _meeting = {
  'title': 'Release sync',
  'summary': 'We agreed on the date.',
  'attendees': ['Ana'],
  'decisions': ['Ship Friday'],
  'action_items': [
    {'task': 'Send notes', 'owner': 'Ana', 'due': null, 't': '00:00:00'},
  ],
  'open_questions': <String>[],
  'topics': ['release'],
};

void main() {
  late VaultVoiceDatabase db;
  late StoragePaths paths;

  setUp(() async {
    db = memoryDb();
    paths = tempPaths();
    await seedRecordingWithChunks(db, 'r1', chunks: 1);
    await seedVaultTarget(db);
  });

  Future<void> run(Map<String, Object?> output, {String? profileId}) async {
    final o = PipelineOrchestrator.withEngines(
      db: db,
      paths: paths,
      engines: PipelineEngines(
        stt: ScriptedStt(),
        llm: ScriptedLlm(output: jsonEncode(output)),
        vault: FakeVaultWriter(),
        profiles: (id) async => _ungrounded(id),
        grammars: (p) async => 'root ::= "${p.id}"',
      ),
    );
    addTearDown(o.dispose);
    await o.start();
    await o.enqueue('r1', profileId: profileId);
    await o.whenIdle();
  }

  group('[TPL-02/AC1] sales next steps become action items', () {
    test('rows carry task, owner, resolved due date and time', () async {
      await run(_sales, profileId: 'sales_call');
      final items = await db.select(db.actionItems).get()
        ..sort((a, b) => a.body.compareTo(b.body));
      expect(items.map((i) => i.body), [
        'Book a finance review',
        'Send the pilot proposal',
      ]);
      expect(items.first.owner, isNull);
      expect(items.first.dueIso, isNull);
      expect(items.first.tMs, isNull);
      expect(items.last.owner, 'Ana');
      expect(items.last.dueIso, '2026-03-13');
      expect(items.last.tMs, 0);
    });

    test('commitments are not action items', () {
      expect(
        actionItemsOf(_sales, profileId: 'sales_call').map((i) => i.text),
        ['Send the pilot proposal', 'Book a finance review'],
      );
    });

    test(
      'actionItemsOf maps per profile; other profiles ignore next_steps',
      () {
        expect(actionItemsOf(_sales, profileId: 'meeting'), isEmpty);
        expect(actionItemsOf(_sales), isEmpty);
      },
    );
  });

  group('[TPL-02/AC6] meeting and lecture mappings are unchanged', () {
    test('meeting action items keep task, owner and time', () async {
      await run(_meeting, profileId: 'meeting');
      final items = await db.select(db.actionItems).get();
      expect(items, hasLength(1));
      expect(items.single.body, 'Send notes');
      expect(items.single.owner, 'Ana');
      expect(items.single.tMs, 0);
    });

    test('the source-field map only adds lecture and sales_call', () {
      expect(kActionItemSourceFields, {
        'lecture': 'assignments',
        'sales_call': 'next_steps',
      });
      expect(actionItemsOf(_meeting, profileId: 'meeting').single.owner, 'Ana');
    });
  });
}
