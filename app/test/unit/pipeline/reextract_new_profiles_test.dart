import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_engines.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_orchestrator.dart';
import 'package:vaultvoice/features/pipeline/data/steps/step_support.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/profiles/domain/builtin_profiles.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';

import '../../db/db_test_utils.dart';
import '../../fakes/fake_vault_writer.dart';
import 'pipeline_test_utils.dart';

final BuiltinProfiles _builtins = BuiltinProfiles.parse({
  for (final a in kBuiltinProfileAssets) a: File(a).readAsStringSync(),
});

/// The scripted answers are not grounded in the fake `chunk_0` transcript, so
/// the transcript-dependent guards are removed (wiring test, as in
/// `interview_action_items_test.dart`).
Profile? _ungrounded(String id) {
  final p = _builtins[id];
  if (p == null) return null;
  final json = p.toJson();
  (json['post_process']! as List)
    ..remove('ground_to_transcript')
    ..remove('verbatim_quotes');
  return Profile.fromJson(json);
}

const Map<String, Map<String, Object?>> _outputs = {
  'meeting': {
    'title': 'Release sync',
    'summary': 'We agreed on the date.',
    'attendees': ['Ana'],
    'decisions': ['Ship Friday'],
    'action_items': <Object?>[],
    'open_questions': <String>[],
    'topics': ['release'],
  },
  'lecture': {
    'title': 'Thermodynamics, week 3',
    'summary': 'Entropy and the second law.',
    'key_concepts': [
      {'term': 'Entropy', 'explanation': 'A measure of disorder.'},
    ],
    'outline': [
      {
        'heading': 'Second law',
        'points': ['Entropy never decreases'],
      },
    ],
    'assignments': [
      {'task': 'Problem set 4', 'due': null, 't': null},
    ],
    'questions': ['Does entropy apply to open systems?'],
    'references': ['Chapter 5'],
  },
  'sales_call': {
    'title': 'Renewal call',
    'summary': 'Pricing and rollout were discussed.',
    'participants': ['Mia', 'Omar'],
    'needs': ['Single sign-on'],
    'objections': [
      {'objection': 'The price is high', 'response': null},
    ],
    'commitments': [
      {'who': 'Mia', 'what': 'Send a quote', 't': null},
    ],
    'next_steps': [
      {'task': 'Schedule a demo', 'owner': 'Mia', 'due': null, 't': null},
    ],
    'competitors_mentioned': ['Tailspin'],
    'open_questions': <String>[],
  },
  'interview': {
    'title': 'Sensor drift interview',
    'summary': 'Research interview.',
    'participants': [
      {'name': 'Dana', 'role': 'interviewer'},
    ],
    'topics': ['drift'],
    'qa_highlights': <Object?>[],
    'quotes': <Object?>[],
    'follow_ups': [
      {'task': 'Email the questions', 'owner': 'Dana', 'due': null, 't': null},
    ],
    'open_questions': <String>[],
  },
};

void main() {
  late VaultVoiceDatabase db;
  late StoragePaths paths;
  late ScriptedLlm llm;
  late FakeVaultWriter vault;
  late PipelineOrchestrator orchestrator;

  setUp(() async {
    db = memoryDb();
    paths = tempPaths();
    llm = ScriptedLlm(output: jsonEncode(_outputs['meeting']));
    vault = FakeVaultWriter();
    await seedRecordingWithChunks(db, 'r1', chunks: 1);
    await seedVaultTarget(db);
    orchestrator = PipelineOrchestrator.withEngines(
      db: db,
      paths: paths,
      engines: PipelineEngines(
        stt: ScriptedStt(),
        llm: llm,
        vault: vault,
        profiles: (id) async => _ungrounded(id),
        grammars: (p) async => 'root ::= "${p.id}"',
      ),
    );
    addTearDown(orchestrator.dispose);
    await orchestrator.start();
  });

  group('[TPL-04/AC4] re-extract and export with each new profile', () {
    for (final id in ['lecture', 'sales_call', 'interview']) {
      test('$id: the change-profile path re-extracts and re-exports', () async {
        final jobId = expectOk(await orchestrator.enqueue('r1'));
        await orchestrator.whenIdle();
        expect((await loadJob(db, jobId)).state, JobState.done);
        final notesBefore = vault.notes.length;

        llm.output = jsonEncode(_outputs[id]);
        expectOk(
          await orchestrator.rerun(
            jobId,
            PipelineStepId.extract,
            profileId: id,
          ),
        );
        await orchestrator.whenIdle();

        expect((await loadJob(db, jobId)).state, JobState.done);
        expect(llm.requests.last.grammar, 'root ::= "$id"');
        final ext = expectOk(
          await db.extractionsRepository.get(extractionIdFor(jobId)),
        );
        expect(ext.valid, isTrue);
        expect(ext.json['title'], _outputs[id]!['title']);
        expect(ext.profileVersion, _builtins[id]!.version);
        expect(vault.notes.length, greaterThanOrEqualTo(notesBefore));
        expect(
          vault.notes.values.any(
            (n) => n.contains(_outputs[id]!['title']! as String),
          ),
          isTrue,
          reason: 'the exported note carries the new profile output',
        );
      });
    }
  });
}
