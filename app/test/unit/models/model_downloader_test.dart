import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart' as crypto;
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart' as db;
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/network/model_hosts.dart';
import 'package:vaultvoice/core/network/network_gateway.dart';
import 'package:vaultvoice/features/models/data/gateway_download_transport.dart';
import 'package:vaultvoice/features/models/data/model_downloader.dart';
import 'package:vaultvoice/features/models/domain/download_platform.dart';
import 'package:vaultvoice/features/models/domain/download_policy.dart';
import 'package:vaultvoice/features/models/domain/download_state.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';

import '../../helpers/model_download_server.dart';

const _cdn = 'models.vaultvoice.example';
const _hf = 'huggingface.co';
const _hfCdn = 'us.aws.cdn.hf.co';
const _evil = 'evil.example';
const _cdnUrl = 'https://$_cdn/stt/ggml-tiny.en.bin';
const _hfPath = '/ggerganov/whisper.cpp/resolve/abc/ggml-tiny.en.bin';
const _hfUrl = 'https://$_hf$_hfPath';

const int _mib = 1024 * 1024;

NetworkConfig _config({bool offline = false}) => NetworkConfig(
  allowedHosts: const {_cdn, _hf},
  redirectHosts: const {_hfCdn},
  offline: offline,
);

/// Runs a download in its own isolate so the test can kill it hard
/// (no cleanup code runs — like the OS killing the app).
Future<void> _downloadInIsolate(
  (int, String, CatalogModel, SendPort) args,
) async {
  final (port, root, model, ready) = args;
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final database = VaultVoiceDatabase(NativeDatabase.memory());
  final downloader = ModelDownloader(
    paths: StoragePaths(root),
    models: database.modelsRepository,
    transport: GatewayDownloadTransport(
      NetworkGateway(config: _config(), client: LoopbackClient(port)),
    ),
    device: FakeDownloadDevice(),
  );
  ready.send(true);
  await downloader.download(model);
}

void main() {
  late ModelFileServer server;
  late Directory tmp;
  late StoragePaths paths;
  late VaultVoiceDatabase database;
  late FakeDownloadDevice device;
  late List<Duration> delays;
  late NetworkGateway gateway;
  final bytes = modelBytes(3 * _mib + 12345);
  final digest = crypto.sha256.convert(bytes).toString();

  setUpAll(() {
    // flutter_test mocks dart:io HTTP; these tests use a real local server.
    HttpOverrides.global = null;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    server = await ModelFileServer.start();
    tmp = await Directory.systemTemp.createTemp('vv_mdl02_');
    paths = StoragePaths(p.join(tmp.path, 'vv'));
    database = VaultVoiceDatabase(NativeDatabase.memory());
    device = FakeDownloadDevice();
    delays = [];
    gateway = NetworkGateway(
      config: _config(),
      client: LoopbackClient(server.port),
    );
  });

  tearDown(() async {
    gateway.close();
    await database.close();
    await server.close();
    await tmp.delete(recursive: true);
  });

  ModelDownloader downloader({
    NetworkGateway? via,
    Future<bool> Function()? cellular,
    ModelFileCheck? verify,
    Future<bool> Function()? networkDisabled,
  }) => ModelDownloader(
    paths: paths,
    models: database.modelsRepository,
    transport: GatewayDownloadTransport(
      via ?? gateway,
      checkpointEveryBytes: 256 * 1024,
    ),
    device: device,
    cellularAllowedSetting: cellular,
    networkDisabled: networkDisabled,
    verify: verify ?? verifyModelFileInIsolate,
    delay: (d) async => delays.add(d),
  );

  CatalogModel model({List<String> urls = const [_cdnUrl]}) =>
      testCatalogModel(bytes, urls: urls);

  File partialFile() =>
      File(p.join(paths.modelsDir, '.partial', 'whisper-tiny.en'));
  File installedFile() =>
      File(p.join(paths.modelsDir, 'whisper-tiny.en', 'ggml-tiny.en.bin'));

  Future<void> expectInstalled() async {
    expect(installedFile().existsSync(), isTrue);
    expect(
      crypto.sha256.convert(await installedFile().readAsBytes()).toString(),
      digest,
    );
    final row = (await database.modelsRepository.get('whisper-tiny.en'))
        .valueOrNull!;
    expect(row.sha256, digest);
    expect(row.size, bytes.length);
    expect(row.type, db.ModelType.stt);
    expect(row.path, p.join('models', 'whisper-tiny.en', 'ggml-tiny.en.bin'));
    expect(Directory(p.join(paths.modelsDir, '.partial')).listSync(), isEmpty);
  }

  group('policy', () {
    test('free space is remaining × 1.1 + 200 MB', () {
      expect(requiredFreeBytes(0), 200 * _mib);
      expect(requiredFreeBytes(1000), 1100 + 200 * _mib);
      expect(requiredFreeBytes(2000000001), 2200000002 + 200 * _mib);
    });

    test('backoff is 1 s doubling, capped at 60 s, 8 retries', () {
      expect(
        [for (var i = 1; i <= 9; i++) retryDelay(i).inSeconds],
        [1, 2, 4, 8, 16, 32, 60, 60, 60],
      );
      expect(kMaxDownloadRetries, 8);
    });
  });

  group('[MDL-02/AC1] resume from the last byte', () {
    test('[MDL-02/AC1] killing the app mid-download resumes from the last byte '
        'on relaunch', () async {
      const stallAt = _mib + 4096;
      server.routes['$_cdn/stt/ggml-tiny.en.bin'] = FileRoute(
        bytes,
        stallAfterBytes: stallAt,
      );
      final ready = ReceivePort();
      final errors = ReceivePort();
      final isolateErrors = <Object?>[];
      errors.listen(isolateErrors.add);
      addTearDown(errors.close);
      final isolate = await Isolate.spawn(_downloadInIsolate, (
        server.port,
        paths.root,
        model(),
        ready.sendPort,
      ), onError: errors.sendPort);
      await ready.first;
      // Wait until the first process has written everything it received.
      final deadline = DateTime.now().add(const Duration(seconds: 20));
      while (!partialFile().existsSync() || partialFile().lengthSync() < _mib) {
        if (DateTime.now().isAfter(deadline)) {
          fail(
            'no partial: $isolateErrors ${server.bodyBytesSent} '
            '${partialFile().existsSync() ? partialFile().lengthSync() : -1}',
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      isolate.kill(priority: Isolate.immediate);
      server.releaseStalled();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      // Whatever reached the disk before the kill is the resume offset.
      final have = partialFile().lengthSync();
      expect(have, inInclusiveRange(_mib, stallAt));

      // "Relaunch": a new downloader on the same files finds the pending
      // download and resumes it.
      final d = downloader();
      expect(await d.pendingModelIds(), ['whisper-tiny.en']);
      final catalog = ModelCatalog(
        schema: 1,
        issuedAt: DateTime.utc(2026, 10, 13),
        minAppVersion: const SemVer(1, 0, 0),
        models: [model()],
      );
      expect(await d.resumePending(catalog), ['whisper-tiny.en']);
      final result = await d.download(model());
      expect(result.isOk, isTrue, reason: '${result.failureOrNull}');

      final seen = server.to(_cdn);
      expect(seen, hasLength(2));
      expect(seen[0].range, isNull);
      expect(seen[1].range, 'bytes=$have-');
      // Nothing already on disk was downloaded again.
      expect(server.bodyBytesSent[1], bytes.length - have);
      await expectInstalled();
    });

    test('[MDL-02/AC1] pause keeps the partial; resume continues '
        'from its length', () async {
      server.routes['$_cdn/stt/ggml-tiny.en.bin'] = FileRoute(bytes);
      final d = downloader();
      final sub = d.progress.listen((e) {
        if (e.phase == DownloadPhase.downloading && e.receivedBytes >= _mib) {
          d.pause('whisper-tiny.en');
        }
      });
      final first = await d.download(model());
      await sub.cancel();
      expect(first.failureOrNull, isA<CancelledFailure>());
      expect(d.latest('whisper-tiny.en')!.phase, DownloadPhase.paused);
      final have = partialFile().lengthSync();
      expect(have, greaterThanOrEqualTo(_mib));
      expect(have, lessThan(bytes.length));

      expect((await d.download(model())).isOk, isTrue);
      expect(server.to(_cdn).last.range, 'bytes=$have-');
      await expectInstalled();
    });

    test('a server that ignores Range restarts from zero and still '
        'installs a correct file', () async {
      final route = FileRoute(bytes, honourRange: false);
      server.routes['$_cdn/stt/ggml-tiny.en.bin'] = route;
      // Pause after 1 MiB so the second run sends Range and gets a 200.
      final d = downloader();
      final pausing = d.progress.listen((e) {
        if (e.phase == DownloadPhase.downloading && e.receivedBytes >= _mib) {
          d.pause('whisper-tiny.en');
        }
      });
      await d.download(model());
      await pausing.cancel();
      expect((await d.download(model())).isOk, isTrue);
      expect(server.to(_cdn).last.range, isNotNull);
      await expectInstalled();
    });

    test('[MDL-02/AC2] cancel during verification does not install', () async {
      server.routes['$_cdn/stt/ggml-tiny.en.bin'] = FileRoute(bytes);
      late final ModelDownloader d;
      d = downloader(
        verify: (path, m) async {
          unawaited(d.cancel('whisper-tiny.en'));
          return await verifyModelFileInIsolate(path, m);
        },
      );
      final r = await d.download(model());
      expect(r.failureOrNull, isA<CancelledFailure>());
      expect(installedFile().existsSync(), isFalse);
      expect(
        (await database.modelsRepository.get('whisper-tiny.en')).valueOrNull,
        isNull,
      );
    });

    test('cancel deletes the partial file', () async {
      server.routes['$_cdn/stt/ggml-tiny.en.bin'] = FileRoute(bytes);
      final d = downloader();
      final sub = d.progress.listen((e) {
        if (e.phase == DownloadPhase.downloading && e.receivedBytes >= _mib) {
          unawaited(d.cancel('whisper-tiny.en'));
        }
      });
      final r = await d.download(model());
      await sub.cancel();
      expect(r.failureOrNull, isA<CancelledFailure>());
      expect(d.latest('whisper-tiny.en')!.phase, DownloadPhase.cancelled);
      expect(partialFile().existsSync(), isFalse);
      expect(await d.pendingModelIds(), isEmpty);
    });
  });

  group('[MDL-02/AC2] integrity', () {
    test('[MDL-02/AC2] a corrupted file (hash mismatch) is deleted and '
        're-downloaded from zero', () async {
      server.routes['$_cdn/stt/ggml-tiny.en.bin'] = FileRoute(
        bytes,
        corruptTimes: 1,
      );
      final phases = <DownloadPhase>[];
      final d = downloader();
      final sub = d.progress.listen((e) => phases.add(e.phase));
      final r = await d.download(model());
      await sub.cancel();
      expect(r.isOk, isTrue, reason: '${r.failureOrNull}');
      final seen = server.to(_cdn);
      expect(seen, hasLength(2));
      expect(seen[1].range, isNull, reason: 'retry must start from zero');
      expect(server.bodyBytesSent, [bytes.length, bytes.length]);
      expect(phases.where((ph) => ph == DownloadPhase.verifying), hasLength(2));
      await expectInstalled();
    });

    test('[MDL-02/AC2] a second mismatch fails, leaving no file and no '
        'row', () async {
      server.routes['$_cdn/stt/ggml-tiny.en.bin'] = FileRoute(
        bytes,
        corruptTimes: 2,
      );
      final r = await downloader().download(model());
      final f = r.failureOrNull;
      expect(f, isA<ModelIntegrityFailure>());
      expect((f! as ModelIntegrityFailure).sizeMismatch, isFalse);
      expect(server.to(_cdn), hasLength(2));
      expect(partialFile().existsSync(), isFalse);
      expect(installedFile().existsSync(), isFalse);
      expect(
        (await database.modelsRepository.get('whisper-tiny.en')).isOk,
        isFalse,
      );
    });

    test(
      'verification runs on the finished file in a background isolate',
      () async {
        final f = File(p.join(tmp.path, 'm.bin'))..writeAsBytesSync(bytes);
        expect((await verifyModelFileInIsolate(f.path, model())).isOk, isTrue);
        f.writeAsBytesSync([...bytes, 0]);
        expect(
          (await verifyModelFileInIsolate(f.path, model())).failureOrNull,
          isA<ModelIntegrityFailure>(),
        );
      },
    );

    test('a partial from a different catalog version is discarded', () async {
      server.routes['$_cdn/stt/ggml-tiny.en.bin'] = FileRoute(bytes);
      final old = testCatalogModel(
        modelBytes(bytes.length, seed: 99),
        urls: const [_cdnUrl],
      );
      final d = downloader();
      final sub = d.progress.listen((e) {
        if (e.receivedBytes >= _mib) d.pause('whisper-tiny.en');
      });
      // Old version: route serves new bytes, but we pause before the end.
      await d.download(old);
      await sub.cancel();
      expect(partialFile().existsSync(), isTrue);
      expect((await d.download(model())).isOk, isTrue);
      expect(server.to(_cdn).last.range, isNull);
      await expectInstalled();
    });
  });

  group('preconditions', () {
    test('no space: refused before any request', () async {
      server.routes['$_cdn/stt/ggml-tiny.en.bin'] = FileRoute(bytes);
      device.free = requiredFreeBytes(bytes.length) - 1;
      final d = downloader();
      final plan = await d.plan(model());
      expect(plan.requiredFreeBytes, requiredFreeBytes(bytes.length));
      expect(plan.blocks, {ModelDownloadBlock.insufficientSpace});
      final f = (await d.download(model())).failureOrNull!;
      expect(f, isA<ModelDownloadFailure>());
      f as ModelDownloadFailure;
      expect(f.block, ModelDownloadBlock.insufficientSpace);
      expect(f.requiredBytes, requiredFreeBytes(bytes.length));
      expect(server.requests, isEmpty);

      device.free = requiredFreeBytes(bytes.length);
      expect((await d.download(model())).isOk, isTrue);
    });

    test('unknown free space counts as not enough', () async {
      device.free = null;
      final plan = await downloader().plan(model());
      expect(plan.blocks, contains(ModelDownloadBlock.insufficientSpace));
    });

    test('Wi-Fi only by default; cellular needs an opt-in', () async {
      server.routes['$_cdn/stt/ggml-tiny.en.bin'] = FileRoute(bytes);
      device.status = const NetworkStatus(connected: true, unmetered: false);
      final d = downloader();
      final plan = await d.plan(model());
      expect(plan.totalBytes, bytes.length);
      expect(plan.blocks, {ModelDownloadBlock.unmeteredNetworkRequired});
      final f = (await d.download(model())).failureOrNull;
      expect(
        (f! as ModelDownloadFailure).block,
        ModelDownloadBlock.unmeteredNetworkRequired,
      );
      expect(server.requests, isEmpty);

      expect((await d.download(model(), allowCellular: true)).isOk, isTrue);
      await expectInstalled();
    });

    test('the saved cellular setting is honoured', () async {
      server.routes['$_cdn/stt/ggml-tiny.en.bin'] = FileRoute(bytes);
      device.status = const NetworkStatus(connected: true, unmetered: false);
      final d = downloader(cellular: () async => true);
      expect((await d.download(model())).isOk, isTrue);
    });

    test('losing Wi-Fi mid-download pauses and keeps the partial', () async {
      server.routes['$_cdn/stt/ggml-tiny.en.bin'] = FileRoute(bytes);
      device.onStatus = (call) {
        // Call 1 = precondition; later calls are mid-download checkpoints.
        if (call >= 2) {
          device.status = const NetworkStatus(
            connected: true,
            unmetered: false,
          );
        }
      };
      final d = downloader();
      final f = (await d.download(model())).failureOrNull;
      expect(
        (f! as ModelDownloadFailure).block,
        ModelDownloadBlock.unmeteredNetworkRequired,
      );
      expect(d.latest('whisper-tiny.en')!.phase, DownloadPhase.paused);
      final have = partialFile().lengthSync();
      expect(have, greaterThan(0));
      expect(have, lessThan(bytes.length));
      expect(await d.pendingModelIds(), ['whisper-tiny.en']);
    });

    test('[MDL-04/AC1] enabling network_disabled mid-download pauses and '
        'keeps the partial', () async {
      server.routes['$_cdn/stt/ggml-tiny.en.bin'] = FileRoute(bytes);
      // The first call is the pre-download check; later ones are mid-transfer
      // checkpoints. Counting calls avoids racing the async progress stream.
      var calls = 0;
      final d = downloader(networkDisabled: () async => ++calls > 1);
      final r = await d.download(model());
      expect(r.isOk, isFalse);
      expect(d.latest('whisper-tiny.en')!.phase, DownloadPhase.paused);
      expect(partialFile().existsSync(), isTrue);
      expect(installedFile().existsSync(), isFalse);
    });

    test('[MDL-04/AC1] pauseAll stops every running transfer', () async {
      server.routes['$_cdn/stt/ggml-tiny.en.bin'] = FileRoute(bytes);
      final d = downloader();
      final sub = d.progress.listen((e) {
        if (e.phase == DownloadPhase.downloading && e.receivedBytes >= _mib) {
          d.pauseAll();
        }
      });
      await d.download(model());
      await sub.cancel();
      expect(d.latest('whisper-tiny.en')!.phase, DownloadPhase.paused);
    });

    test('low-power mode needs an explicit OK', () async {
      server.routes['$_cdn/stt/ggml-tiny.en.bin'] = FileRoute(bytes);
      device.status = const NetworkStatus(
        connected: true,
        unmetered: true,
        lowPowerMode: true,
      );
      final d = downloader();
      expect(
        ((await d.download(model())).failureOrNull! as ModelDownloadFailure)
            .block,
        ModelDownloadBlock.lowPowerMode,
      );
      expect((await d.download(model(), allowLowPower: true)).isOk, isTrue);
    });

    test('offline (no connection) is refused up front', () async {
      device.status = const NetworkStatus(connected: false, unmetered: false);
      final f = (await downloader().download(model())).failureOrNull;
      expect((f! as ModelDownloadFailure).block, ModelDownloadBlock.offline);
      expect(server.requests, isEmpty);
    });
  });

  group('redirects', () {
    test('Hugging Face resolve → allowlisted CDN host is followed', () async {
      server.routes['$_hf$_hfPath'] = const RedirectRoute(
        'https://$_hfCdn/xet-bridge-us/abc/0d68?user_id=public&Expires=1',
      );
      server.routes['$_hfCdn/xet-bridge-us/abc/0d68'] = FileRoute(bytes);
      final r = await downloader().download(model(urls: const [_hfUrl]));
      expect(r.isOk, isTrue, reason: '${r.failureOrNull}');
      expect(server.to(_hfCdn), hasLength(1));
      await expectInstalled();
    });

    test(
      'redirect to an unlisted host is rejected and never contacted',
      () async {
        server.routes['$_hf$_hfPath'] = const RedirectRoute(
          'https://$_evil/ggml-tiny.en.bin',
        );
        server.routes['$_evil/ggml-tiny.en.bin'] = FileRoute(bytes);
        final r = await downloader().download(model(urls: const [_hfUrl]));
        final f = r.failureOrNull! as ModelDownloadFailure;
        expect(f.block, ModelDownloadBlock.allUrlsRejected);
        expect(f.cause, isA<EgressDeniedFailure>());
        expect((f.cause! as EgressDeniedFailure).host, _evil);
        expect(server.to(_evil), isEmpty);
        expect(delays, isEmpty, reason: 'a policy denial is not retried');
        expect(installedFile().existsSync(), isFalse);
      },
    );

    test('a rejected mirror falls through to the next catalog URL', () async {
      server.routes['$_hf$_hfPath'] = const RedirectRoute(
        'http://$_hfCdn/downgrade',
      );
      server.routes['$_cdn/stt/ggml-tiny.en.bin'] = FileRoute(bytes);
      final r = await downloader().download(
        model(urls: const [_hfUrl, _cdnUrl]),
      );
      expect(r.isOk, isTrue);
      expect(server.to(_hfCdn), isEmpty, reason: 'no https downgrade');
      await expectInstalled();
    });

    test('a redirect-only host is never contacted directly', () async {
      server.routes['$_hfCdn/x.bin'] = FileRoute(bytes);
      final r = await downloader().download(
        model(urls: const ['https://$_hfCdn/x.bin']),
      );
      expect(
        (r.failureOrNull! as ModelDownloadFailure).block,
        ModelDownloadBlock.allUrlsRejected,
      );
      expect(server.requests, isEmpty);
    });

    test('offline mode (network_disabled) refuses every request', () async {
      server.routes['$_cdn/stt/ggml-tiny.en.bin'] = FileRoute(bytes);
      final offline = NetworkGateway(
        config: _config(offline: true),
        client: LoopbackClient(server.port),
      );
      addTearDown(offline.close);
      final r = await downloader(via: offline).download(model());
      expect(r.isOk, isFalse);
      expect(server.requests, isEmpty);
    });
  });

  group('retry', () {
    test('5xx is retried with backoff and then succeeds', () async {
      server.routes['$_cdn/stt/ggml-tiny.en.bin'] = StatusRoute(
        503,
        times: 2,
        then: FileRoute(bytes),
      );
      final r = await downloader().download(model());
      expect(r.isOk, isTrue);
      expect(delays, [const Duration(seconds: 1), const Duration(seconds: 2)]);
      await expectInstalled();
    });

    test(
      'gives up after 8 retries (1 s → 60 s) and keeps the partial',
      () async {
        server.routes['$_cdn/stt/ggml-tiny.en.bin'] = StatusRoute(503);
        final r = await downloader().download(model());
        expect(
          (r.failureOrNull! as ModelDownloadFailure).block,
          ModelDownloadBlock.retriesExhausted,
        );
        expect(server.requests, hasLength(9));
        expect(
          [for (final d in delays) d.inSeconds],
          [1, 2, 4, 8, 16, 32, 60, 60],
        );
      },
    );

    test('[MDL-02/AC3] a blocked mirror caps the retries, is not contacted '
        'again and its failure is the one reported', () async {
      server.routes['$_cdn/stt/ggml-tiny.en.bin'] = StatusRoute(503);
      server.routes['$_hf$_hfPath'] = const RedirectRoute(
        'https://$_evil/block?x=1',
      );
      final r = await downloader().download(
        model(urls: const [_cdnUrl, _hfUrl]),
      );
      final f = r.failureOrNull! as ModelDownloadFailure;
      expect(f.block, ModelDownloadBlock.retriesExhausted);
      expect(f.cause, isA<EgressDeniedFailure>());
      expect((f.cause! as EgressDeniedFailure).host, _evil);
      expect(delays, hasLength(kMaxDownloadRetriesWithRejectedUrl));
      expect(server.to(_hf), hasLength(1));
      expect(server.to(_evil), isEmpty);
    });

    test('[MDL-02/AC3] an HTML block page is not retried or stored', () async {
      server.routes['$_cdn/stt/ggml-tiny.en.bin'] = const HtmlRoute();
      final r = await downloader().download(model());
      final f = r.failureOrNull! as ModelDownloadFailure;
      expect((f.cause! as NetworkFailure).message, kBlockedByNetwork);
      expect(
        delays.length,
        lessThanOrEqualTo(kMaxDownloadRetriesWithRejectedUrl),
      );
    });

    test('[MDL-02/AC3] 405 on the ranged GET is reported as blocked', () async {
      server.routes['$_cdn/stt/ggml-tiny.en.bin'] = StatusRoute(405);
      final r = await downloader().download(model());
      final f = r.failureOrNull! as ModelDownloadFailure;
      expect((f.cause! as NetworkFailure).message, kBlockedByNetwork);
    });

    test(
      '404 on the primary falls back to the mirror without backoff',
      () async {
        server.routes['$_hf$_hfPath'] = FileRoute(bytes);
        final r = await downloader().download(
          model(urls: const [_cdnUrl, _hfUrl]),
        );
        expect(r.isOk, isTrue);
        expect(delays, isEmpty);
        expect(server.to(_cdn).single.uri.path, '/stt/ggml-tiny.en.bin');
      },
    );
  });

  group('install', () {
    test('atomic install records models_installed and excludes models/ from '
        'backup', () async {
      server.routes['$_cdn/stt/ggml-tiny.en.bin'] = FileRoute(bytes);
      final phases = <DownloadPhase>[];
      final d = downloader();
      final sub = d.progress.listen((e) => phases.add(e.phase));
      final row = (await d.download(model())).valueOrNull!;
      await sub.cancel();
      expect(row.id, 'whisper-tiny.en');
      expect(row.version, '1');
      await expectInstalled();
      expect(device.excluded, contains(paths.modelsDir));
      expect(
        device.excluded,
        contains(p.join(paths.modelsDir, 'whisper-tiny.en')),
      );
      expect(phases.last, DownloadPhase.installed);
      expect(
        phases.toSet(),
        containsAll([
          DownloadPhase.checking,
          DownloadPhase.downloading,
          DownloadPhase.verifying,
          DownloadPhase.installing,
        ]),
      );
    });

    test('requests carry only the anonymous headers (+ Range)', () async {
      server.routes['$_cdn/stt/ggml-tiny.en.bin'] = FileRoute(bytes);
      await downloader().download(model());
      final h = server.requests.single.headers;
      expect(h['user-agent'], 'VaultVoice/1');
      expect(h['accept'], '*/*');
      expect(
        h.keys.toSet().difference({
          'user-agent',
          'accept',
          'accept-encoding',
          'content-length',
          'host',
          'range',
        }),
        isEmpty,
      );
      expect(server.requests.single.uri.hasQuery, isFalse);
    });

    test('a second download call while running shares the same job', () async {
      server.routes['$_cdn/stt/ggml-tiny.en.bin'] = FileRoute(bytes);
      final d = downloader();
      final a = d.download(model());
      final b = d.download(model());
      expect(identical(a, b), isTrue);
      expect((await a).isOk, isTrue);
      expect(server.requests, hasLength(1));
    });

    test('the shipped allowlist has the observed HF CDN as redirect-only', () {
      expect(kModelRedirectHosts, contains(_hfCdn));
      expect(kModelHosts.intersection(kModelRedirectHosts), isEmpty);
    });
  });
}
