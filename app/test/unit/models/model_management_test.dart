import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart' as db;
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/features/licensing/domain/feature_access.dart';
import 'package:vaultvoice/features/models/data/download_providers.dart';
import 'package:vaultvoice/features/models/data/model_installer.dart';
import 'package:vaultvoice/features/models/data/model_management_providers.dart';
import 'package:vaultvoice/features/models/domain/installed_model.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';
import 'package:vaultvoice/features/models/domain/model_management.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

import '../../fakes/fake_model_downloader.dart';
import '../../fakes/fake_settings_store.dart';
import '../../helpers/model_download_server.dart';
import '../../helpers/model_fixtures.dart';

InstalledModel _installed(CatalogModel m, {String? version}) => InstalledModel(
  id: m.id,
  version: version ?? m.version,
  size: m.size,
  relativePath: 'models/${m.id}/${m.file}',
  installedAt: DateTime.utc(2026),
);

final CatalogModel _tiny = catalogModel('whisper-tiny', size: 78 * 1000 * 1000);
final CatalogModel _base = catalogModel(
  'whisper-base',
  size: 148 * 1000 * 1000,
);
final CatalogModel _proStt = catalogModel(
  'whisper-small',
  size: 488 * 1000 * 1000,
  tier: ModelTier.pro,
);
final CatalogModel _llm = seedLlm;
final CatalogModel _bigLlm = catalogModel(
  'llama-3b',
  type: ModelType.llm,
  size: 2000 * 1000 * 1000,
  minRamMb: 6144,
);

List<ModelEntry> _entries({
  required List<InstalledModel> installed,
  Map<ModelType, String?> chosen = const {},
  int? ramMb = 4096,
  AccessLevel Function(ModelTier, {required bool installed})? access,
}) => buildModelEntries(
  catalog: catalogOf([_tiny, _base, _proStt, _llm, _bigLlm]),
  installed: installed,
  access: access ?? (_, {required installed}) => AccessLevel.full,
  deviceRamMb: ramMb,
  recommendedIds: {_tiny.id, _llm.id},
  chosen: chosen,
);

ModelEntry _entry(List<ModelEntry> all, CatalogModel m) =>
    all.firstWhere((e) => e.model.id == m.id);

void main() {
  test('[MDL-03] active-model keys match what the engine factory reads '
      '(FND-11)', () {
    expect(ActiveModelKeys.stt, 'models.active_stt');
    expect(ActiveModelKeys.llm, 'models.active_llm');
    expect(ActiveModelKeys.forType(ModelType.vad), isNull);
  });

  group('[MDL-03] shared selector and sideloads', () {
    test('activeIds from the pipeline selector decide the active flag', () {
      final all = buildModelEntries(
        catalog: catalogOf([_tiny, _base, _llm]),
        installed: [_installed(_tiny), _installed(_base)],
        access: (_, {required installed}) => AccessLevel.full,
        deviceRamMb: 4096,
        recommendedIds: {_tiny.id},
        chosen: const {},
        activeIds: {_base.id},
      );
      expect(_entry(all, _base).active, isTrue);
      expect(_entry(all, _tiny).active, isFalse);
    });

    test('installed models the catalog does not list are managed too', () {
      final side = InstalledModel(
        id: 'my-sideload',
        version: '1',
        size: 42,
        relativePath: 'models/my-sideload/m.gguf',
        installedAt: DateTime.utc(2026),
        type: ModelType.llm,
      );
      final all = _entries(installed: [side]);
      final e = all.firstWhere((e) => e.model.id == 'my-sideload');
      expect(e.isInstalled, isTrue);
      expect(e.model.type, ModelType.llm);
      expect(e.updateAvailable, isFalse);
      expect(e.usable, isTrue);
    });
  });

  group('active model resolution', () {
    test('the user choice wins while usable; otherwise recommended, then '
        'first usable; nothing installed → none', () {
      final all = _entries(
        installed: [_installed(_tiny), _installed(_base), _installed(_llm)],
        chosen: {ModelType.stt: _base.id},
      );
      expect(_entry(all, _base).active, isTrue);
      expect(_entry(all, _tiny).active, isFalse);
      expect(_entry(all, _llm).active, isTrue);

      final fallback = _entries(
        installed: [_installed(_tiny), _installed(_base)],
        chosen: {ModelType.stt: 'deleted-model'},
      );
      expect(_entry(fallback, _tiny).active, isTrue, reason: 'recommended');
      expect(
        resolveActiveModel(
          type: ModelType.llm,
          chosen: null,
          entries: fallback,
        ),
        isNull,
      );
    });

    test('incompatible or plan-locked models are never active', () {
      final all = _entries(
        installed: [_installed(_bigLlm), _installed(_proStt)],
        chosen: {ModelType.llm: _bigLlm.id, ModelType.stt: _proStt.id},
        access: (tier, {required installed}) =>
            tier == ModelTier.free ? AccessLevel.full : AccessLevel.readOnly,
      );
      expect(_entry(all, _bigLlm).compatible, isFalse);
      expect(_entry(all, _bigLlm).active, isFalse);
      expect(_entry(all, _proStt).usable, isFalse);
      expect(_entry(all, _proStt).active, isFalse);
    });

    test('newer catalog version → update available', () {
      expect(isNewerVersion('2', '1'), isTrue);
      expect(isNewerVersion('1.10', '1.9'), isTrue);
      expect(isNewerVersion('1', '1'), isFalse);
      expect(isNewerVersion('1', '2'), isFalse);
      expect(isNewerVersion('2026-10', '2026-09'), isTrue);
      final all = _entries(installed: [_installed(_tiny, version: '0')]);
      expect(_entry(all, _tiny).updateAvailable, isTrue);
      expect(_entry(all, _base).updateAvailable, isFalse);
    });
  });

  group('[MDL-03/AC1] deleting never leaves the pipeline without a model', () {
    test('plans: not active → free; active → replacement; only → blocked', () {
      final all = _entries(
        installed: [_installed(_tiny), _installed(_base), _installed(_llm)],
      );
      expect(planDeletion(_entry(all, _base), all), isA<DeleteFreely>());
      final active = planDeletion(_entry(all, _tiny), all);
      expect(active, isA<DeleteWithReplacement>());
      expect(
        (active as DeleteWithReplacement).replacements.map((e) => e.model.id),
        [_base.id],
      );
      expect(planDeletion(_entry(all, _llm), all), isA<DeleteBlocked>());
    });

    test('a plan-locked or incompatible model is not a replacement', () {
      final all = _entries(
        installed: [_installed(_tiny), _installed(_proStt)],
        access: (tier, {required installed}) =>
            tier == ModelTier.free ? AccessLevel.full : AccessLevel.readOnly,
      );
      expect(planDeletion(_entry(all, _tiny), all), isA<DeleteBlocked>());
    });

    late Directory tmp;
    late VaultVoiceDatabase database;
    late StoragePaths paths;
    late FakeSettingsStore store;
    late ProviderContainer container;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('vv-mdl03-');
      paths = StoragePaths(tmp.path);
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      database = VaultVoiceDatabase(NativeDatabase.memory());
      store = FakeSettingsStore();
      container = ProviderContainer(
        overrides: [
          settingsStoreProvider.overrideWithValue(store),
          modelDownloaderProvider.overrideWith(
            (ref) async => FakeModelDownloader(),
          ),
          modelInstallerProvider.overrideWith(
            (ref) async => ModelInstaller(
              paths: paths,
              models: database.modelsRepository,
              device: FakeDownloadDevice(),
            ),
          ),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await database.close();
      await tmp.delete(recursive: true);
    });

    Future<InstalledModel> install(CatalogModel m) async {
      final file = File(p.join(paths.modelsDir, m.id, m.file));
      await file.create(recursive: true);
      await file.writeAsBytes([1, 2, 3]);
      await database.modelsRepository.upsert(
        ModelsInstalledCompanion.insert(
          id: m.id,
          type: ModelInstaller.dbType(m.type),
          version: m.version,
          path: paths.relativize(file.path),
          sha256: m.sha256,
          size: m.size,
          installedAt: DateTime.utc(2026),
        ),
      );
      return _installed(m);
    }

    Future<List<String>> installedIds() async => [
      for (final r in await database.modelsRepository.watchAll().first) r.id,
    ];

    test('active model: refused without a replacement, switched with one; '
        'the last usable model cannot be deleted', () async {
      final installed = [
        await install(_tiny),
        await install(_base),
        await install(_llm),
      ];
      await store.set(ActiveModelKeys.stt, _tiny.id);
      final all = _entries(
        installed: installed,
        chosen: {ModelType.stt: _tiny.id},
      );
      final manager = container.read(modelManagerProvider);

      final refused = await manager.delete(_entry(all, _tiny), all);
      expect(refused.failureOrNull, kModelInUse);
      expect(await installedIds(), contains(_tiny.id));
      expect(
        File(p.join(paths.modelsDir, _tiny.id, _tiny.file)).existsSync(),
        isTrue,
      );

      final ok = await manager.delete(
        _entry(all, _tiny),
        all,
        replacement: _entry(all, _base),
      );
      expect(ok.isOk, isTrue);
      expect(store.values[ActiveModelKeys.stt], _base.id);
      expect(await installedIds(), isNot(contains(_tiny.id)));
      expect(Directory(p.join(paths.modelsDir, _tiny.id)).existsSync(), false);

      // After the delete the pipeline still resolves a usable STT model.
      final after = _entries(
        installed: [installed[1], installed[2]],
        chosen: {ModelType.stt: _base.id},
      );
      expect(
        resolveActiveModel(
          type: ModelType.stt,
          chosen: _base.id,
          entries: after,
        ),
        _base.id,
      );

      // The only LLM: refused, still installed.
      final llm = await manager.delete(_entry(after, _llm), after);
      expect(llm.failureOrNull, kModelInUse);
      expect(await installedIds(), contains(_llm.id));
    });

    test('a non-active model is deleted directly (row + files)', () async {
      final installed = [await install(_tiny), await install(_base)];
      final all = _entries(installed: installed);
      final r = await container
          .read(modelManagerProvider)
          .delete(_entry(all, _base), all);
      expect(r.isOk, isTrue);
      expect(await installedIds(), [_tiny.id]);
      expect(Directory(p.join(paths.modelsDir, _base.id)).existsSync(), false);
    });

    test('storage totals sum models, audio and transcript text', () async {
      await install(_tiny);
      await database
          .into(database.recordings)
          .insert(
            RecordingsCompanion.insert(
              id: 'r1',
              createdAt: DateTime.utc(2026),
              status: db.RecordingStatus.recorded,
              source: db.RecordingSource.mic,
            ),
          );
      await database.recordingsRepository.upsertChunk(
        AudioChunksCompanion.insert(
          recordingId: 'r1',
          seq: 0,
          path: 'audio/r1/chunk_0000.wav',
          sampleRate: 16000,
          startMs: 0,
          endMs: 1000,
          bytes: 32044,
        ),
      );
      await database
          .into(database.transcripts)
          .insert(
            TranscriptsCompanion.insert(
              id: 't1',
              recordingId: 'r1',
              modelId: _tiny.id,
              language: 'en',
              createdAt: DateTime.utc(2026),
            ),
          );
      await database
          .into(database.transcriptSegments)
          .insert(
            TranscriptSegmentsCompanion.insert(
              transcriptId: 't1',
              seq: 0,
              startMs: 0,
              endMs: 1000,
              body: 'héllo', // 6 UTF-8 bytes
            ),
          );
      final usage = await watchStorageUsage(database).first;
      expect(usage.modelBytes, _tiny.size);
      expect(usage.audioBytes, 32044);
      expect(usage.transcriptBytes, 6);
    });
  });

  test('uninstall of a model that is not recorded is not an error', () async {
    final tmp = await Directory.systemTemp.createTemp('vv-mdl03-');
    addTearDown(() => tmp.delete(recursive: true));
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final database = VaultVoiceDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final installer = ModelInstaller(
      paths: StoragePaths(tmp.path),
      models: database.modelsRepository,
      device: FakeDownloadDevice(),
    );
    expect((await installer.uninstall('nothing')).isOk, isTrue);
  });
}
