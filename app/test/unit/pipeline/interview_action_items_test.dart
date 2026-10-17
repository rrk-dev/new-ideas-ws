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
/// transcript, so the transcript-dependent guards are removed (as in
/// `production_steps_test.dart`).
Profile? _ungrounded(String id) {
  final p = _builtins[id];
  if (p == null) return null;
  final json = p.toJson();
  (json['post_process']! as List)
    ..remove('ground_to_transcript')
    ..remove('verbatim_quotes');
  return Profile.fromJson(json);
}

const Map<String, Object?> _interview = {
  'title': 'Sensor drift interview',
  'summary': 'Research interview.',
  'participants': [
    {'name': 'Dana', 'role': 'interviewer'},
    {'name': 'Ravi', 'role': 'interviewee'},
  ],
  'topics': ['drift'],
  'qa_highlights': <Object?>[],
  'quotes': <Object?>[],
  'follow_ups': [
    {
      'task': 'Email the written questions',
      'owner': 'Dana',
      'due': '2026-03-13',
      't': '00:00:00',
    },
    {
      'task': 'Share the calibration notes',
      'owner': null,
      'due': null,
      't': null,
    },
  ],
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

  group('[TPL-03/AC1] interview follow-ups become action items', () {
    test('rows carry task, owner, resolved due date and time', () async {
      await run(_interview, profileId: 'interview');
      final items = await db.select(db.actionItems).get()
        ..sort((a, b) => a.body.compareTo(b.body));
      expect(items.map((i) => i.body), [
        'Email the written questions',
        'Share the calibration notes',
      ]);
      expect(items.first.owner, 'Dana');
      expect(items.first.dueIso, '2026-03-13');
      expect(items.first.tMs, 0);
      expect(items.last.owner, isNull);
      expect(items.last.dueIso, isNull);
      expect(items.last.tMs, isNull);
    });

    test('due_iso only when resolvable; quotes are not action items', () {
      final items = actionItemsOf(_interview, profileId: 'interview');
      expect(items.map((i) => i.text), [
        'Email the written questions',
        'Share the calibration notes',
      ]);
      expect(items.last.dueIso, isNull);
    });

    test(
      'actionItemsOf maps per profile; other profiles ignore follow_ups',
      () {
        expect(actionItemsOf(_interview, profileId: 'meeting'), isEmpty);
        expect(actionItemsOf(_interview), isEmpty);
      },
    );
  });

  group('[TPL-03/AC1] meeting mapping is unchanged', () {
    test('meeting action items keep task, owner and time', () async {
      await run(_meeting, profileId: 'meeting');
      final items = await db.select(db.actionItems).get();
      expect(items, hasLength(1));
      expect(items.single.body, 'Send notes');
      expect(items.single.owner, 'Ana');
      expect(items.single.tMs, 0);
    });
  });
}
