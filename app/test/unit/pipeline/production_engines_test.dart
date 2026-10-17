import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/diagnostics/diagnostics_providers.dart';
import 'package:vaultvoice/core/platform/app_paths.dart';
import 'package:vaultvoice/features/export/data/app_local_vault_writer.dart';
import 'package:vaultvoice/features/export/data/bookmark_vault_writer.dart';
import 'package:vaultvoice/features/export/data/saf_vault_writer.dart';
import 'package:vaultvoice/features/extraction/data/native_schema_grammar_converter.dart';
import 'package:vaultvoice/features/licensing/data/licensing_providers.dart';
import 'package:vaultvoice/features/pipeline/data/active_engines.dart';
import 'package:vaultvoice/features/pipeline/data/active_models_publisher.dart';
import 'package:vaultvoice/features/pipeline/data/engine_providers.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_engines.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_orchestrator.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_providers.dart';
import 'package:vaultvoice/features/pipeline/data/production_engines.dart';
import 'package:vaultvoice/features/pipeline/data/steps/render_write_steps.dart';
import 'package:vaultvoice/features/pipeline/domain/active_models.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_step.dart';
import 'package:vaultvoice/features/profiles/data/profile_providers.dart';
import 'package:vaultvoice/features/profiles/domain/builtin_profiles.dart';
import 'package:vaultvoice/features/templates/domain/builtin_templates.dart';

import '../../db/db_test_utils.dart';
import '../../fakes/fake_vault_writer.dart';
import '../../helpers/test_container.dart';
import 'pipeline_test_utils.dart';

/// Reads assets from `app/assets/` (cwd = `app/`), like `rootBundle`.
Future<String> _diskAsset(String key) => File(key).readAsString();

VaultTargetRow _target(VaultPlatform platform) => VaultTargetRow(
  id: 't-${platform.name}',
  platform: platform,
  displayName: 'T',
  handle: 'handle',
  createdAt: t0,
);

/// Installs a dummy model file + `models_installed` row.
Future<void> _install(
  VaultVoiceDatabase db,
  StoragePaths paths,
  String id,
  ModelType type,
) async {
  final file = File(p.join(paths.modelsDir, id, '$id.bin'));
  await file.parent.create(recursive: true);
  await file.writeAsString('model');
  expectOk(
    await db.modelsRepository.upsert(
      ModelsInstalledCompanion.insert(
        id: id,
        type: type,
        version: '1',
        path: paths.relativize(file.path),
        sha256: '0' * 64,
        size: 5,
        installedAt: t0,
      ),
    ),
  );
}

void main() {
  late StoragePaths paths;
  late Directory root;

  setUp(() {
    paths = tempPaths();
    root = Directory(paths.root)..createSync(recursive: true);
  });

  List<Override> appOverrides() => [
    storagePathsProvider.overrideWith((ref) async => paths),
    appPathsProvider.overrideWithValue(
      AppPaths(root: root, temp: Directory(p.join(root.path, 'tmp'))),
    ),
    profileAssetLoaderProvider.overrideWithValue(_diskAsset),
    deviceProfileProvider.overrideWithValue(null),
  ];

  test('[FND-11/AC1] app bootstrap creates real engines: the default engines '
      'factory builds the production STT/LLM engines, renderer, vault '
      'writers and residency gate; the grammar converter is native', () async {
    final container = createContainer(overrides: appOverrides());
    expect(
      container.read(schemaGrammarConverterProvider),
      isA<NativeSchemaGrammarConverter>(),
    );
    final spec = await container.read(productionEngineSpecProvider.future);
    expect(spec.profileSources.keys, hasLength(kBuiltinProfileAssets.length));
    // Every built-in template (EXP-08 added the Logseq/plain variants).
    expect(spec.templateSources.keys, hasLength(kBuiltinTemplates.length));
    expect(spec.appLocalVaultRoot, p.join(paths.root, 'vault'));
    expect(spec.metricsFile, endsWith('metrics.jsonl'));
    expect(spec.foreground, isFalse, reason: 'no UI ⇒ never GPU');

    final factory = await container.read(pipelineEnginesFactoryProvider.future);
    final db = memoryDb();
    final engines = factory(PipelineWorkerContext(db: db, paths: paths));

    // Real engines over the active installed models (not fakes).
    expect(engines.stt, isA<ActiveSttEngine>());
    expect(engines.llm, isA<ActiveLlmEngine>());
    expect(engines.activeModel, isNotNull);
    expect(await engines.activeModel!(HeavyModel.stt), isNull);
    expect(engines.metrics, isA<PipelineJobMetrics>());
    expect(engines.onForeground, isNotNull);
    expect(engines.onMemoryPressure, isNotNull);

    // Vault writer per configured target; app-local is the default.
    expect(engines.vault, isA<AppLocalVaultWriter>());
    expect(engines.vaultFor!(_target(VaultPlatform.appLocal)), engines.vault);
    expect(
      engines.vaultFor!(_target(VaultPlatform.androidSaf)),
      isA<SafVaultWriter>(),
    );
    expect(
      engines.vaultFor!(_target(VaultPlatform.iosBookmark)),
      isA<BookmarkVaultWriter>(),
    );

    // Every built-in profile resolves.
    for (final id in [
      'meeting',
      'warranty',
      'engineering',
      'lecture',
      'sales_call',
      'interview',
    ]) {
      expect((await engines.profiles!(id))?.id, id);
    }
    expect(await engines.profiles!('nope'), isNull);

    // Renderer: built-in templates + a DB snapshot taken per job.
    await seedRecording(db, 'r1');
    expectOk(
      await db.extractionsRepository.upsert(
        ExtractionsCompanion.insert(
          id: 'e1',
          recordingId: 'r1',
          profileId: 'meeting',
          profileVersion: 1,
          modelId: 'm',
          json: {'title': 'Weekly sync', 'summary': 'Short.'},
          valid: false,
          createdAt: t0,
        ),
      ),
    );
    final input = NoteInput(
      recording: expectOk(await db.recordingsRepository.get('r1')),
      extraction: expectOk(await db.extractionsRepository.get('e1')),
      segments: const [],
    );
    final builtin = (await engines.rendererLoader!())(input);
    expect(builtin, startsWith('---\n'));
    expect(builtin, contains('source: vaultvoice'));
    expect(builtin, contains('extraction: failed'), reason: 'summary-only');

    // A user template stored for the profile's template id wins from the
    // next job on (the snapshot is taken at job start).
    expectOk(
      await db.profilesRepository.upsertTemplate(
        TemplatesCompanion.insert(
          id: 'meeting-default',
          body: 'USER TEMPLATE {{meta.recording_id}}\n',
          filenamePattern: '{{id}}.md',
          updatedAt: t0,
        ),
      ),
    );
    final valid = NoteInput(
      recording: input.recording,
      extraction: ExtractionRow(
        id: 'e1',
        recordingId: 'r1',
        profileId: 'meeting',
        profileVersion: 1,
        modelId: 'm',
        json: const {'title': 'Weekly sync', 'summary': 'Short.'},
        valid: true,
        createdAt: t0,
      ),
      segments: const [],
    );
    expect((await engines.rendererLoader!())(valid), 'USER TEMPLATE r1\n');

    // One residency gate: STT and LLM are released through the engines.
    await engines.gate.use(HeavyModel.stt);
    await engines.gate.use(HeavyModel.llm);
    expect(engines.gate.loaded, HeavyModel.llm);
    await engines.gate.releaseAll();
    expect(engines.gate.loaded, isNull);
    engines.onForeground!(foreground: true);
    engines.onMemoryPressure!();
    await engines.dispose!();
  });

  test('[FND-11/AC3] with no models installed a job waits for a model with '
      'the production engines and no engine is created', () async {
    final container = createContainer(overrides: appOverrides());
    final factory = await container.read(pipelineEnginesFactoryProvider.future);
    final db = memoryDb();
    await seedRecordingWithChunks(db, 'r1', chunks: 1);
    await seedVaultTarget(db);
    final engines = factory(PipelineWorkerContext(db: db, paths: paths));
    final o = PipelineOrchestrator.withEngines(
      db: db,
      paths: paths,
      engines: engines,
    );
    addTearDown(o.dispose);
    await o.start();
    final id = expectOk(await o.enqueue('r1'));
    await o.whenIdle();

    final job = await loadJob(db, id);
    expect(job.state, JobState.waiting);
    expect(job.waitingReason, WaitingReason.modelMissing);
    expect(job.failureKind, isNull);
    expect((engines.stt as ActiveSttEngine).modelId, isNull);
    expect((engines.llm as ActiveLlmEngine).service, isNull);
    expect(await db.select(db.transcripts).get(), isEmpty);
  });

  test('[FND-11/AC3] publishing a newly installed model resumes the waiting '
      'job to done (fake engines over the production model lookup)', () async {
    final db = memoryDb();
    await seedRecordingWithChunks(db, 'r1', chunks: 2);
    await seedVaultTarget(db);
    final stt = ScriptedStt();
    final llm = ScriptedLlm();
    final resolver = InstalledModelResolver(db: db, paths: paths);
    final o = PipelineOrchestrator.withEngines(
      db: db,
      paths: paths,
      engines: PipelineEngines(
        stt: stt,
        llm: llm,
        vault: FakeVaultWriter(),
        activeModel: resolver.activeId,
      ),
    );
    addTearDown(o.dispose);
    // The plan snapshot comes from LIC-01's entitlement service.
    final container = createContainer(overrides: appOverrides());
    final realPublisher = ActiveModelsPublisher(
      settings: db.settingsRepository,
      models: db.modelsRepository,
      access: () => container.read(featureAccessStateProvider),
    );

    await realPublisher.publish();
    await o.start();
    final id = expectOk(await o.enqueue('r1'));
    await o.whenIdle();
    expect((await loadJob(db, id)).waitingReason, WaitingReason.modelMissing);
    expect(stt.calls, isEmpty);
    expect(llm.requests, isEmpty);

    final resumed = Completer<void>();
    final sub = realPublisher.watch(
      onAvailable: (s) async {
        await resumeModelWaits(db.jobsRepository, o);
        if (s.stt != null && s.llm != null && !resumed.isCompleted) {
          resumed.complete();
        }
      },
    );
    addTearDown(sub.cancel);
    await _install(db, paths, 'whisper-tiny', ModelType.stt);
    await _install(db, paths, 'llm-small', ModelType.llm);
    await resumed.future.timeout(const Duration(seconds: 10));
    await until(() => stt.calls.length == 2 && llm.requests.isNotEmpty);
    await o.whenIdle();
    final job = await loadJob(db, id);
    expect(job.state, JobState.done);
    final transcript = (await db.select(db.transcripts).get()).single;
    expect(transcript.modelId, 'whisper-tiny');
    final extraction = (await db.select(db.extractions).get()).single;
    expect(extraction.modelId, 'llm-small');
    final published = expectOk(
      await db.settingsRepository.get(kActiveModelsKey),
    );
    expect(ActiveModelSelection.fromJson(published).stt, 'whisper-tiny');
  });
}
