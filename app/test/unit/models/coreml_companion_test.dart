import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/network/network_gateway.dart';
import 'package:vaultvoice/features/licensing/domain/feature_access.dart';
import 'package:vaultvoice/features/models/data/catalog_config.dart';
import 'package:vaultvoice/features/models/data/coreml_encoder_installer.dart';
import 'package:vaultvoice/features/models/data/gateway_download_transport.dart';
import 'package:vaultvoice/features/models/data/model_downloader.dart';
import 'package:vaultvoice/features/models/data/model_installer.dart';
import 'package:vaultvoice/features/models/domain/coreml_companions.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';
import 'package:vaultvoice/features/models/domain/model_management.dart';

import '../../helpers/model_download_server.dart';

const _hf = 'huggingface.co';
const _rev = '/ggerganov/whisper.cpp/resolve/abc';
const _enc = 'ggml-tiny.en-encoder.mlmodelc';

/// A zip shaped like the Hugging Face whisper.cpp encoder archives (the
/// large-v3-turbo one carries macOS `__MACOSX/` resource forks too).
Uint8List _encoderZip({List<(String, String)> extra = const []}) {
  final a = Archive()
    ..add(ArchiveFile.directory('$_enc/'))
    ..add(ArchiveFile.string('$_enc/metadata.json', '{"v":1}'))
    ..add(ArchiveFile.string('$_enc/model.mil', 'program'))
    ..add(ArchiveFile.string('$_enc/coremldata.bin', 'cd'))
    ..add(ArchiveFile.string('$_enc/weights/weight.bin', 'w' * 4096))
    ..add(ArchiveFile.string('__MACOSX/$_enc/._model.mil', 'fork'));
  for (final (name, body) in extra) {
    a.add(ArchiveFile.string(name, body));
  }
  return Uint8List.fromList(ZipEncoder().encode(a));
}

void main() {
  group('encoder directory name (whisper_get_coreml_path_encoder)', () {
    test('drops the extension and a -qX_Y suffix', () {
      expect(coreMlEncoderDirName('ggml-tiny.en.bin'), _enc);
      expect(
        coreMlEncoderDirName('ggml-base.en-q5_1.bin'),
        'ggml-base.en-encoder.mlmodelc',
      );
      expect(
        coreMlEncoderDirName('ggml-large-v3-turbo-q5_0.bin'),
        'ggml-large-v3-turbo-encoder.mlmodelc',
      );
      expect(
        coreMlEncoderDirName('ggml-small.en-q8_0.bin'),
        'ggml-small.en-encoder.mlmodelc',
      );
    });
  });

  group('bundled catalog ships a Core ML encoder for every Whisper model', () {
    final catalog = ModelCatalog.parse(
      File(kBundledCatalogAsset).readAsBytesSync(),
    ).valueOrNull!;

    test('each STT model lists exactly one coreml-encoder companion whose '
        'zip unpacks to the directory whisper.cpp looks for', () {
      final stt = catalog.models.where((m) => m.type == ModelType.stt);
      expect(stt, isNotEmpty);
      for (final m in stt) {
        final comps = coreMlCompanionsOf(m, catalog.byId);
        expect(comps, hasLength(1), reason: m.id);
        final c = comps.single;
        expect(c.file, '${coreMlEncoderDirName(m.file)}.zip', reason: m.id);
        expect(c.urls.single.host, 'huggingface.co');
        // A Free model never depends on a Pro-only encoder.
        if (m.tier == ModelTier.free) expect(c.tier, ModelTier.free);
      }
    });

    test('encoders are not listed as their own rows in model management', () {
      final entries = buildModelEntries(
        catalog: catalog,
        installed: const [],
        access: (_, {required installed}) => AccessLevel.full,
        deviceRamMb: null,
        recommendedIds: const {},
        chosen: const {},
      );
      expect(
        entries.where((e) => e.model.type == ModelType.coremlEncoder),
        isEmpty,
      );
    });

    test('no catalog entry is a Core ML encoder without a parent', () {
      final referenced = {for (final m in catalog.models) ...m.companions};
      for (final m in catalog.models) {
        if (m.type == ModelType.coremlEncoder) {
          expect(referenced, contains(m.id));
        }
      }
    });
  });

  group('unzip', () {
    late Directory tmp;
    setUp(
      () async => tmp = await Directory.systemTemp.createTemp('vv_coreml_'),
    );
    tearDown(() => tmp.delete(recursive: true));

    String writeZip(Uint8List bytes) {
      final f = File(p.join(tmp.path, 'enc.zip'))..writeAsBytesSync(bytes);
      return f.path;
    }

    test('extracts the .mlmodelc next to the model and skips __MACOSX', () {
      final target = Directory(p.join(tmp.path, 'models', 'whisper-tiny.en'))
        ..createSync(recursive: true);
      final r = extractCoreMlEncoderZip(
        writeZip(_encoderZip()),
        target.path,
        _enc,
      );
      expect(r.isOk, isTrue);
      final dir = Directory(p.join(target.path, _enc));
      expect(
        File(p.join(dir.path, 'weights', 'weight.bin')).lengthSync(),
        4096,
      );
      expect(File(p.join(dir.path, 'model.mil')).readAsStringSync(), 'program');
      expect(Directory(p.join(target.path, '__MACOSX')).existsSync(), isFalse);
      // Only the encoder dir: no temp leftovers.
      expect(target.listSync().map((e) => p.basename(e.path)).toList(), [_enc]);
    });

    test('a path-traversal entry is refused and nothing is left behind', () {
      final target = Directory(p.join(tmp.path, 't'))..createSync();
      final r = extractCoreMlEncoderZip(
        writeZip(_encoderZip(extra: [('$_enc/../../evil.txt', 'x')])),
        target.path,
        _enc,
      );
      expect(r.isOk, isFalse);
      expect(target.listSync(), isEmpty);
      expect(File(p.join(tmp.path, 'evil.txt')).existsSync(), isFalse);
    });

    test('a zip without the expected directory is refused', () {
      final target = Directory(p.join(tmp.path, 't'))..createSync();
      final r = extractCoreMlEncoderZip(
        writeZip(_encoderZip()),
        target.path,
        'ggml-base.en-encoder.mlmodelc',
      );
      expect(r.isOk, isFalse);
      expect(target.listSync(), isEmpty);
    });

    test('garbage bytes are refused, not thrown', () {
      final r = extractCoreMlEncoderZip(
        writeZip(Uint8List.fromList(utf8.encode('not a zip'))),
        tmp.path,
        _enc,
      );
      expect(r.isOk, isFalse);
    });
  });

  group('downloader installs the companion with its STT model (iOS)', () {
    late ModelFileServer server;
    late Directory tmp;
    late StoragePaths paths;
    late VaultVoiceDatabase db;
    late NetworkGateway gateway;
    final modelBytesData = modelBytes(64 * 1024);
    final zip = _encoderZip();

    setUpAll(() {
      HttpOverrides.global = null;
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    });

    setUp(() async {
      server = await ModelFileServer.start();
      tmp = await Directory.systemTemp.createTemp('vv_coreml_dl_');
      paths = StoragePaths(p.join(tmp.path, 'vv'));
      db = VaultVoiceDatabase(NativeDatabase.memory());
      gateway = NetworkGateway(
        config: const NetworkConfig(allowedHosts: {_hf}),
        client: LoopbackClient(server.port),
      );
      server.routes['$_hf$_rev/ggml-tiny.en.bin'] = FileRoute(modelBytesData);
      server.routes['$_hf$_rev/$_enc.zip'] = FileRoute(zip);
    });

    tearDown(() async {
      gateway.close();
      await db.close();
      await server.close();
      await tmp.delete(recursive: true);
    });

    final encoder = testCatalogModel(
      zip,
      id: 'whisper-tiny.en-coreml-encoder',
      file: '$_enc.zip',
      type: ModelType.coremlEncoder,
      urls: const ['https://$_hf$_rev/$_enc.zip'],
    );
    final stt = testCatalogModel(
      modelBytesData,
      urls: const ['https://$_hf$_rev/ggml-tiny.en.bin'],
      companions: const ['whisper-tiny.en-coreml-encoder'],
    );
    CatalogModel? lookup(String id) => id == encoder.id ? encoder : null;

    ModelDownloader make({CatalogModel? Function(String)? companions}) =>
        ModelDownloader(
          paths: paths,
          models: db.modelsRepository,
          transport: GatewayDownloadTransport(gateway),
          device: FakeDownloadDevice(),
          delay: (_) async {},
          coreMlCompanions: companions,
          coreMlUnzip: ({
            required zipPath,
            required targetDir,
            required dirName,
          }) async => extractCoreMlEncoderZip(zipPath, targetDir, dirName),
        );

    test('iOS: the encoder lands next to the .bin; no extra models row; '
        'removed with the model', () async {
      final d = make(companions: lookup);
      final r = await d.download(stt);
      expect(r.isOk, isTrue);
      final dir = p.join(paths.modelsDir, 'whisper-tiny.en');
      expect(File(p.join(dir, 'ggml-tiny.en.bin')).existsSync(), isTrue);
      expect(
        File(p.join(dir, _enc, 'weights', 'weight.bin')).existsSync(),
        isTrue,
      );
      final rows = await db.modelsRepository.watchAll().first;
      expect(rows.map((r) => r.id), ['whisper-tiny.en']);
      // No partial / zip left over.
      final partial = Directory(p.join(paths.modelsDir, '.partial'));
      expect(partial.listSync(), isEmpty);
      // Deleting the model (MDL-03) removes its encoder too.
      final installer = ModelInstaller(
        paths: paths,
        models: db.modelsRepository,
        device: FakeDownloadDevice(),
      );
      expect((await installer.uninstall('whisper-tiny.en')).isOk, isTrue);
      expect(Directory(dir).existsSync(), isFalse);
    });

    test('Android/host (no lookup): only the model is downloaded', () async {
      final d = make();
      expect((await d.download(stt)).isOk, isTrue);
      final dir = p.join(paths.modelsDir, 'whisper-tiny.en');
      expect(Directory(p.join(dir, _enc)).existsSync(), isFalse);
      expect(
        server.requests.where((r) => r.uri.path.endsWith('.zip')),
        isEmpty,
      );
    });

    test('a failing companion never fails the model (ggml fallback)', () async {
      server.routes.remove('$_hf$_rev/$_enc.zip');
      final d = make(companions: lookup);
      final r = await d.download(stt);
      expect(r.isOk, isTrue);
      expect(
        Directory(p.join(paths.modelsDir, 'whisper-tiny.en', _enc))
            .existsSync(),
        isFalse,
      );
    });
  });
}
