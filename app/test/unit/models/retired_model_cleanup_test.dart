import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/db/enums.dart' as db;
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/features/models/data/model_state_providers.dart';
import 'package:vaultvoice/features/models/data/retired_model_cleanup.dart';
import 'package:vaultvoice/features/models/domain/model_management.dart';

const _qwen = 'qwen2.5-0.5b-instruct-q4_k_m';
const _custom = 'custom-0123456789abcdef';
const _llama = 'llama-3.2-1b-instruct-q4_k_m';

void main() {
  late Directory tmp;
  late StoragePaths paths;
  late VaultVoiceDatabase database;

  Future<void> install(String id, db.ModelType type) async {
    final dir = Directory(p.join(paths.modelsDir, id))
      ..createSync(recursive: true);
    File(p.join(dir.path, 'm.gguf')).writeAsStringSync('x');
    await database.modelsRepository.upsert(
      ModelsInstalledCompanion.insert(
        id: id,
        type: type,
        version: '1',
        path: 'models/$id/m.gguf',
        sha256: '0' * 64,
        size: 1,
        installedAt: DateTime.utc(2026),
      ),
    );
  }

  Future<List<String>> purge() => purgeRetiredModels(
    models: database.modelsRepository,
    settings: database.settingsRepository,
    paths: paths,
  );

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    tmp = await Directory.systemTemp.createTemp('vv_retired_');
    paths = StoragePaths(p.join(tmp.path, 'vv'));
    database = VaultVoiceDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
    await tmp.delete(recursive: true);
  });

  test('[MDL-03/AC1] the retired Qwen row, files and active setting are '
      'removed; other models and sideloaded ones stay', () async {
    await install(_qwen, db.ModelType.llm);
    await install(_llama, db.ModelType.llm);
    await install(_custom, db.ModelType.llm);
    await database.settingsRepository.set(ActiveModelKeys.llm, _qwen);

    expect(await purge(), [_qwen]);

    final left = await database.modelsRepository.watchAll().first;
    expect([for (final r in left) r.id], [_custom, _llama]);
    expect(Directory(p.join(paths.modelsDir, _qwen)).existsSync(), isFalse);
    expect(Directory(p.join(paths.modelsDir, _custom)).existsSync(), isTrue);
    expect(
      (await database.settingsRepository.get(ActiveModelKeys.llm)).valueOrNull,
      isNull,
    );
  });

  test('[MDL-03/AC1] an active setting for another model is kept and the '
      'cleanup is idempotent', () async {
    await install(_qwen, db.ModelType.llm);
    await database.settingsRepository.set(ActiveModelKeys.llm, _llama);
    expect(await purge(), [_qwen]);
    expect(await purge(), isEmpty);
    expect(
      (await database.settingsRepository.get(ActiveModelKeys.llm)).valueOrNull,
      _llama,
    );
  });

  test(
    '[MDL-03/AC1] a leftover directory without a row is removed too',
    () async {
      Directory(p.join(paths.modelsDir, _qwen)).createSync(recursive: true);
      expect(await purge(), [_qwen]);
      expect(Directory(p.join(paths.modelsDir, _qwen)).existsSync(), isFalse);
    },
  );

  test('[MDL-03/AC1] after the cleanup no LLM counts as installed', () async {
    await install(_qwen, db.ModelType.llm);
    final c = ProviderContainer(
      overrides: [
        vaultVoiceDatabaseProvider.overrideWithValue(database),
        storagePathsProvider.overrideWith((ref) async => paths),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(installedModelsProvider, (_, _) {});
    addTearDown(sub.close);
    final installed = await c.read(installedModelsProvider.future);
    expect(installed, isEmpty);
  });
}
