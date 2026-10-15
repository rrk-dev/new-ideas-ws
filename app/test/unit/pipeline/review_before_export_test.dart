import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_engines.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_orchestrator.dart';
import 'package:vaultvoice/features/pipeline/data/steps/review_gate.dart';
import 'package:vaultvoice/features/pipeline/data/steps/step_support.dart';
import 'package:vaultvoice/features/pipeline/domain/heavy_model_gate.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/review/data/review_providers.dart';
import 'package:vaultvoice/features/review/domain/review_policy.dart';
import 'package:vaultvoice/features/settings/data/drift_settings_store.dart';
import 'package:vaultvoice/features/templates/data/template_note_renderer.dart';

import '../../db/db_test_utils.dart';
import '../../fakes/fake_clock.dart';
import '../../fakes/fake_vault_writer.dart';
import '../templates/template_fixtures.dart';
import 'pipeline_test_utils.dart';

/// A meeting result as the (small, mistaken) model produced it.
const Map<String, Object?> _modelOutput = {
  'title': 'API sync',
  'summary': 'The team discussed the API.',
  'attendees': ['Prya'],
  'decisions': <Object?>[],
  'action_items': [
    {'task': 'Update SDK', 'owner': null, 'due': null, 't': '00:00:12'},
  ],
  'open_questions': <Object?>[],
  'topics': <Object?>[],
};

void main() {
  late VaultVoiceDatabase db;
  late StoragePaths paths;
  late FakeVaultWriter vault;
  late ScriptedLlm llm;
  late PipelineOrchestrator o;
  late ReviewService review;

  setUp(() async {
    db = memoryDb();
    paths = tempPaths();
    vault = FakeVaultWriter();
    llm = ScriptedLlm(output: jsonEncode(_modelOutput));
    await seedRecordingWithChunks(db, 'r1', chunks: 1);
    await seedVaultTarget(db);
    o = PipelineOrchestrator.withEngines(
      db: db,
      paths: paths,
      engines: PipelineEngines(
        stt: ScriptedStt(),
        llm: llm,
        vault: vault,
        clock: FakeClock(t0),
        gate: HeavyModelGate(release: (_) async {}),
        renderer: TemplateNoteRenderer(
          profiles: builtinProfiles,
          templates: builtinTemplates,
          appVersion: '1.0.0',
        ).call,
      ),
      newId: sequentialIds(),
    );
    addTearDown(o.dispose);
    await o.start();
    review = ReviewService(
      db: db,
      settings: DriftSettingsStore(db.settingsRepository),
      pipeline: () async => o,
    );
  });

  Map<String, Object?> edit(Map<String, Object?> data) => {
    ...data,
    'attendees': ['Priya', 'Sam'],
    'action_items': [
      {
        'task': 'Update the client SDK to API v2',
        'owner': 'Sam',
        'due': 'Friday',
        't': '00:00:12',
      },
    ],
  };

  test('[APP-05/AC1] review-first profile: the job waits(review); edits are '
      'reflected in the exported Markdown', () async {
    expectOk(await review.setMode('meeting', review: true));
    final id = expectOk(await o.enqueue('r1'));
    await o.whenIdle();

    var job = await loadJob(db, id);
    expect(job.state, JobState.waiting);
    expect(job.waitingReason, WaitingReason.review);
    expect(job.step, PipelineStepId.render);
    expect(vault.notes, isEmpty, reason: 'nothing exported before review');
    expect(File(paths.renderedFile('r1')).existsSync(), isFalse);

    final ext = expectOk(
      await db.extractionsRepository.get(extractionIdFor(id)),
    );
    expectOk(
      await review.approveAndExport(
        extractionId: ext.id,
        edited: edit(ext.json),
        valid: true,
        job: job,
      ),
    );
    await o.whenIdle();
    job = await loadJob(db, id);
    expect(job.state, JobState.done);
    final note = vault.notes.values.single;
    expect(note, contains('Update the client SDK to API v2'));
    expect(note, contains('Sam'));
    expect(note, contains('Priya'));
    expect(note, isNot(contains('Prya')));
    expect(note, isNot(contains('Update SDK\n')));
    final stored = expectOk(await db.extractionsRepository.get(ext.id));
    expect(stored.json['attendees'], ['Priya', 'Sam']);
  });

  test('[APP-05/AC1] editing a finished note re-renders and re-exports it; '
      'a re-extraction must be reviewed again', () async {
    final id = expectOk(await o.enqueue('r1'));
    await o.whenIdle();
    expect((await loadJob(db, id)).state, JobState.done, reason: 'auto mode');
    expect(vault.notes.values.single, contains('Prya'));

    final ext = expectOk(
      await db.extractionsRepository.get(extractionIdFor(id)),
    );
    expectOk(
      await review.approveAndExport(
        extractionId: ext.id,
        edited: edit(ext.json),
        valid: true,
        job: await loadJob(db, id),
      ),
    );
    await o.whenIdle();
    expect((await loadJob(db, id)).state, JobState.done);
    expect(
      vault.notes.values.single,
      contains('Update the client SDK to API v2'),
    );

    // Now review-first: a fresh model output (new content, same extraction
    // id) is not covered by the old approval.
    expectOk(await review.setMode('meeting', review: true));
    llm.output = jsonEncode({..._modelOutput, 'summary': 'Another take.'});
    expectOk(await o.rerun(id, PipelineStepId.extract));
    await o.whenIdle();
    final job = await loadJob(db, id);
    expect(job.state, JobState.waiting);
    expect(job.waitingReason, WaitingReason.review);
  });

  test('[APP-05] the gate: setting › user profile default › built-in '
      'default (off); approval is bound to the content', () async {
    final gate = ReviewGate(db);
    ExtractionRow row(String profileId, Map<String, Object?> json) =>
        ExtractionRow(
          id: 'e1',
          recordingId: 'r1',
          profileId: profileId,
          profileVersion: 1,
          modelId: 'm',
          json: json,
          valid: true,
          createdAt: t0,
        );
    expect(await gate.mustWait(row('meeting', {'a': 1})), isFalse);

    await db.profilesRepository.upsertProfile(
      ProfilesCompanion.insert(
        id: 'mine',
        version: 1,
        source: ProfileSource.user,
        definition: const {'review_before_export': true},
        updatedAt: t0,
      ),
    );
    expect(await gate.mustWait(row('mine', {'a': 1})), isTrue);
    await db.settingsRepository.set(ReviewKeys.mode('mine'), false);
    expect(await gate.mustWait(row('mine', {'a': 1})), isFalse);

    await db.settingsRepository.set(ReviewKeys.mode('meeting'), true);
    await db.settingsRepository.set(
      ReviewKeys.approved('e1'),
      extractionHash({'b': 2, 'a': 1}),
    );
    expect(await gate.mustWait(row('meeting', {'a': 1, 'b': 2})), isFalse);
    expect(await gate.mustWait(row('meeting', {'a': 1, 'b': 3})), isTrue);
  });
}
