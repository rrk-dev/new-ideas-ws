import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart' as db;
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/network/network_gateway.dart';
import 'package:vaultvoice/features/models/data/gateway_download_transport.dart';
import 'package:vaultvoice/features/models/data/model_downloader.dart';
import 'package:vaultvoice/features/models/data/model_importer.dart';
import 'package:vaultvoice/features/models/data/model_installer.dart';
import 'package:vaultvoice/features/models/domain/catalog_verifier.dart';
import 'package:vaultvoice/features/models/domain/custom_model_entitlement.dart';
import 'package:vaultvoice/features/models/domain/download_policy.dart';
import 'package:vaultvoice/features/models/domain/gguf_header.dart';

import '../../helpers/catalog_signing.dart';
import '../../helpers/model_download_server.dart';

class _AllowCustom implements CustomModelEntitlement {
  @override
  Future<bool> allowsCustomModels() async => true;
}

/// Minimal GGUF: header + padding so the counts fit the file size.
Uint8List gguf({
  String magic = 'GGUF',
  int version = 3,
  int tensors = 2,
  int kvs = 3,
  int tensorsHigh = 0,
  int padding = 4096,
}) {
  final b = ByteData(kGgufHeaderBytes + padding);
  for (var i = 0; i < 4; i++) {
    b.setUint8(i, magic.codeUnitAt(i));
  }
  b
    ..setUint32(4, version, Endian.little)
    ..setUint32(8, tensors, Endian.little)
    ..setUint32(12, tensorsHigh, Endian.little)
    ..setUint32(16, kvs, Endian.little);
  return b.buffer.asUint8List();
}

void main() {
  late TestCatalogSigner signer;
  late Directory tmp;
  late StoragePaths paths;
  late VaultVoiceDatabase database;
  late FakeDownloadDevice device;

  final whisper = modelBytes(40000, seed: 1);
  final llm = modelBytes(70000, seed: 2);

  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    signer = await TestCatalogSigner.fromSeed(3);
  });

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('vv_mdl04_');
    paths = StoragePaths(p.join(tmp.path, 'vv'));
    database = VaultVoiceDatabase(NativeDatabase.memory());
    device = FakeDownloadDevice();
  });

  tearDown(() async {
    await database.close();
    await tmp.delete(recursive: true);
  });

  ModelImporter importer({
    CustomModelEntitlement entitlement = const DenyCustomModels(),
    bool advanced = false,
  }) => ModelImporter(
    installer: ModelInstaller(
      paths: paths,
      models: database.modelsRepository,
      device: device,
    ),
    verifier: CatalogVerifier(trustedKeys: [signer.publicKey]),
    device: device,
    entitlement: entitlement,
    advancedCustomModelSetting: () async => advanced,
  );

  Map<String, Object?> entry(String id, Uint8List bytes, String type) =>
      testModel(
        id: id,
        patch: {
          'type': type,
          'file': '$id.bin',
          'size': bytes.length,
          'sha256': crypto.sha256.convert(bytes).toString(),
        },
      );

  /// Writes model + `<id>.json` + `<id>.json.sig` to a "USB stick" dir.
  Future<(File, File, File)> sideloadSet(
    String id,
    Uint8List bytes, {
    String type = 'stt',
    List<Map<String, Object?>>? models,
  }) async {
    final dir = Directory(p.join(tmp.path, 'usb'))..createSync();
    final manifest = testCatalogBytes(
      models: models ?? [entry(id, bytes, type)],
    );
    final m = File(p.join(dir.path, '$id.bin'))..writeAsBytesSync(bytes);
    final j = File(p.join(dir.path, '$id.json'))..writeAsBytesSync(manifest);
    final s = File(p.join(dir.path, '$id.json.sig'))
      ..writeAsBytesSync(await signer.sign(manifest));
    return (m, j, s);
  }

  File installed(String id, String file) =>
      File(p.join(paths.modelsDir, id, file));

  test('[MDL-04/AC1] with the network disabled, a fresh install is fully '
      'provisioned by sideload without a single request', () async {
    final requests = <http.BaseRequest>[];
    final gateway = NetworkGateway(
      config: const NetworkConfig(allowedHosts: {'models.vaultvoice.example'}),
      client: MockClient((r) async {
        requests.add(r);
        return http.Response('', 200);
      }),
      networkDisabled: () async => true,
    );
    addTearDown(gateway.close);
    // The online path is refused up front (UI hides it).
    final downloader = ModelDownloader(
      paths: paths,
      models: database.modelsRepository,
      transport: GatewayDownloadTransport(gateway),
      device: device,
      networkDisabled: () async => true,
    );
    final stt = await sideloadSet('whisper-tiny.en', whisper);
    final online = testCatalogModel(
      whisper,
      urls: const ['https://models.vaultvoice.example/stt/x.bin'],
    );
    expect(
      (await downloader.plan(online)).blocks,
      contains(ModelDownloadBlock.offline),
    );
    expect((await downloader.download(online)).isOk, isFalse);

    // Sideload STT + LLM.
    final i = importer();
    final r1 = await i.importPicked([
      stt.$1,
      stt.$2,
      stt.$3,
    ], moveSource: false);
    expect(r1.isOk, isTrue, reason: '${r1.failureOrNull}');
    final llmSet = await sideloadSet('qwen-test', llm, type: 'llm');
    final r2 = await i.importPicked([llmSet.$3, llmSet.$1, llmSet.$2]);
    expect(r2.isOk, isTrue, reason: '${r2.failureOrNull}');

    final rows = await database.modelsRepository.watchAll().first;
    expect(
      {for (final r in rows) r.id: r.type},
      {'whisper-tiny.en': db.ModelType.stt, 'qwen-test': db.ModelType.llm},
    );
    expect(
      installed('whisper-tiny.en', 'whisper-tiny.en.bin').readAsBytesSync(),
      whisper,
    );
    expect(installed('qwen-test', 'qwen-test.bin').readAsBytesSync(), llm);
    expect(device.excluded, contains(paths.modelsDir));
    expect(requests, isEmpty);
  });

  group('signed import (same checks as the online path)', () {
    test('a tampered manifest is rejected and nothing is installed', () async {
      final (m, j, s) = await sideloadSet('whisper-tiny.en', whisper);
      final doc = j.readAsStringSync().replaceFirst('Whisper', 'Evil');
      j.writeAsStringSync(doc);
      final r = await importer().importSigned(
        model: m,
        manifest: j,
        signature: s,
      );
      expect(r.failureOrNull, isA<CatalogFailure>());
      expect(
        (r.failureOrNull! as CatalogFailure).reason,
        CatalogRejection.badSignature,
      );
      expect(Directory(paths.modelsDir).existsSync(), isFalse);
    });

    test('a manifest signed by an unpinned key is rejected', () async {
      final (m, j, _) = await sideloadSet('whisper-tiny.en', whisper);
      final other = await TestCatalogSigner.fromSeed(9);
      final s = File('${j.path}.other')
        ..writeAsBytesSync(await other.sign(j.readAsBytesSync()));
      final r = await importer().importSigned(
        model: m,
        manifest: j,
        signature: s,
      );
      expect(
        (r.failureOrNull! as CatalogFailure).reason,
        CatalogRejection.unknownKey,
      );
    });

    test('a hash mismatch is rejected and the staged copy deleted', () async {
      final (m, j, s) = await sideloadSet('whisper-tiny.en', whisper);
      final corrupt = Uint8List.fromList(whisper)..[100] ^= 1;
      m.writeAsBytesSync(corrupt);
      final r = await importer().importSigned(
        model: m,
        manifest: j,
        signature: s,
      );
      expect(r.failureOrNull, isA<ModelIntegrityFailure>());
      expect((r.failureOrNull! as ModelIntegrityFailure).sizeMismatch, isFalse);
      expect(
        Directory(p.join(paths.modelsDir, '.partial')).listSync(),
        isEmpty,
      );
      expect(
        installed('whisper-tiny.en', 'whisper-tiny.en.bin').existsSync(),
        isFalse,
      );
      expect(m.existsSync(), isTrue, reason: 'copy mode keeps the source');
    });

    test('a size mismatch is rejected before copying', () async {
      final (m, j, s) = await sideloadSet('whisper-tiny.en', whisper);
      m.writeAsBytesSync([...whisper, 0]);
      final r = await importer().importSigned(
        model: m,
        manifest: j,
        signature: s,
      );
      expect((r.failureOrNull! as ModelIntegrityFailure).sizeMismatch, isTrue);
      expect(Directory(paths.modelsDir).existsSync(), isFalse);
    });

    test('a multi-model document is not a single-model manifest', () async {
      final (m, j, s) = await sideloadSet(
        'whisper-tiny.en',
        whisper,
        models: [
          entry('whisper-tiny.en', whisper, 'stt'),
          entry('qwen-test', llm, 'llm'),
        ],
      );
      final r = await importer().importSigned(
        model: m,
        manifest: j,
        signature: s,
      );
      expect(
        (r.failureOrNull! as ModelImportFailure).reason,
        ModelImportRejection.notSingleModel,
      );
    });

    test('picker copies are moved, not duplicated', () async {
      final (m, j, s) = await sideloadSet('whisper-tiny.en', whisper);
      final r = await importer().importPicked([m, j, s]);
      expect(r.isOk, isTrue);
      expect(m.existsSync(), isFalse);
    });

    test('copying needs size × 1.1 + 200 MB free', () async {
      final (m, j, s) = await sideloadSet('whisper-tiny.en', whisper);
      device.free = requiredFreeBytes(whisper.length) - 1;
      final r = await importer().importSigned(
        model: m,
        manifest: j,
        signature: s,
      );
      expect(
        (r.failureOrNull! as ModelDownloadFailure).block,
        ModelDownloadBlock.insufficientSpace,
      );
    });

    test('incomplete file sets are refused', () async {
      final (m, j, s) = await sideloadSet('whisper-tiny.en', whisper);
      for (final set in [
        [m, j],
        [m, s],
        [j, s],
        [m, m, j, s],
      ]) {
        final r = await importer().importPicked(set, moveSource: false);
        expect(
          (r.failureOrNull! as ModelImportFailure).reason,
          ModelImportRejection.missingFiles,
        );
      }
    });
  });

  group('advanced: custom model (Pro)', () {
    Future<File> customFile(Uint8List bytes) async =>
        File(p.join(tmp.path, 'my-model.gguf'))..writeAsBytesSync(bytes);

    test('an unknown model is rejected unless advanced is enabled', () async {
      final f = await customFile(gguf());
      final r = await importer().importPicked([f], moveSource: false);
      expect(
        (r.failureOrNull! as ModelImportFailure).reason,
        ModelImportRejection.unknownModel,
      );
    });

    test(
      'the placeholder entitlement denies custom models (LIC-01 pending)',
      () async {
        final f = await customFile(gguf());
        final i = importer(advanced: true);
        expect(await i.customModelsEnabled(), isFalse);
        final r = await i.importPicked([f], moveSource: false);
        expect(
          (r.failureOrNull! as ModelImportFailure).reason,
          ModelImportRejection.entitlementRequired,
        );
      },
    );

    test('a valid GGUF installs under a content-derived id', () async {
      final bytes = gguf();
      final f = await customFile(bytes);
      final i = importer(entitlement: _AllowCustom(), advanced: true);
      expect(await i.customModelsEnabled(), isTrue);
      final row = (await i.importPicked([f], moveSource: false)).valueOrNull!;
      final sha = crypto.sha256.convert(bytes).toString();
      expect(row.id, 'custom-${sha.substring(0, 16)}');
      expect(row.type, db.ModelType.llm);
      expect(row.sha256, sha);
      expect(row.path, p.join('models', row.id, 'custom.gguf'));
      expect(row.path, isNot(contains('my-model')));
      expect(installed(row.id, 'custom.gguf').readAsBytesSync(), bytes);
    });

    for (final (name, bytes) in [
      ('bad magic', gguf(magic: 'GGML')),
      ('version 1', gguf(version: 1)),
      ('version 4', gguf(version: 4)),
      ('zero tensors', gguf(tensors: 0)),
      ('too many tensors', gguf(tensors: kMaxGgufTensors + 1)),
      ('64-bit tensor count', gguf(tensorsHigh: 1)),
      ('too many KVs', gguf(kvs: kMaxGgufMetadataKvs + 1)),
      ('counts larger than the file', gguf(tensors: 1000, padding: 100)),
      ('truncated header', Uint8List.fromList('GGUF'.codeUnits)),
    ]) {
      test('GGUF sanity check rejects $name', () async {
        final f = await customFile(bytes);
        final r = await importer(
          entitlement: _AllowCustom(),
          advanced: true,
        ).importCustomGguf(model: f);
        expect(
          (r.failureOrNull! as ModelImportFailure).reason,
          ModelImportRejection.invalidGguf,
        );
        expect(Directory(paths.modelsDir).existsSync(), isFalse);
      });
    }

    test('checkGgufHeader accepts v2 and v3', () {
      for (final v in [2, 3]) {
        final h = checkGgufHeader(gguf(version: v), 4096 + 24).valueOrNull!;
        expect(h.version, v);
        expect(h.tensorCount, 2);
        expect(h.metadataKvCount, 3);
      }
    });
  });
}
