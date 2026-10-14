import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/features/models/data/model_import_providers.dart';
import 'package:vaultvoice/features/models/data/model_importer.dart';
import 'package:vaultvoice/features/models/data/model_installer.dart';
import 'package:vaultvoice/features/models/domain/catalog_verifier.dart';
import 'package:vaultvoice/features/models/presentation/model_import_tile.dart';

import '../helpers/catalog_signing.dart';
import '../helpers/model_download_server.dart';

class _Picker implements ModelFilePicker {
  _Picker(this.files);
  final List<File> files;
  int calls = 0;

  @override
  Future<List<File>> pick() async {
    calls++;
    return files;
  }
}

void main() {
  testWidgets('import tile reports an unsigned file as not importable', (
    tester,
  ) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    late Directory tmp;
    late VaultVoiceDatabase database;
    late ModelImporter importer;
    late File file;
    await tester.runAsync(() async {
      tmp = await Directory.systemTemp.createTemp('vv_mdl04_w_');
      database = VaultVoiceDatabase(NativeDatabase.memory());
      final signer = await TestCatalogSigner.fromSeed(4);
      final device = FakeDownloadDevice();
      importer = ModelImporter(
        installer: ModelInstaller(
          paths: StoragePaths(p.join(tmp.path, 'vv')),
          models: database.modelsRepository,
          device: device,
        ),
        verifier: CatalogVerifier(trustedKeys: [signer.publicKey]),
        device: device,
      );
      file = File(p.join(tmp.path, 'unknown.gguf'))
        ..writeAsBytesSync([1, 2, 3]);
    });
    addTearDown(() async {
      await database.close();
      await tmp.delete(recursive: true);
    });
    final picker = _Picker([file]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          modelFilePickerProvider.overrideWithValue(picker),
          modelImporterProvider.overrideWith((ref) async => importer),
        ],
        child: const MaterialApp(home: Scaffold(body: ModelImportTile())),
      ),
    );
    expect(find.text('Import model from file'), findsOneWidget);
    await tester.tap(find.byType(ListTile));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(picker.calls, 1);
    expect(
      find.textContaining('Not a signed VaultVoice model'),
      findsOneWidget,
    );
    expect(file.existsSync(), isTrue, reason: 'host picker returns originals');
  });
}
