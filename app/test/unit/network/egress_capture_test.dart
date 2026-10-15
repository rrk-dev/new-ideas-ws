import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/network/model_hosts.dart';
import 'package:vaultvoice/core/network/network_activity.dart';
import 'package:vaultvoice/core/network/network_gateway.dart';
import 'package:vaultvoice/features/models/data/catalog_repository.dart';
import 'package:vaultvoice/features/models/data/gateway_download_transport.dart';
import 'package:vaultvoice/features/models/data/model_downloader.dart';
import 'package:vaultvoice/features/models/domain/catalog_keys.dart';
import 'package:vaultvoice/features/models/domain/catalog_state_store.dart';
import 'package:vaultvoice/features/models/domain/catalog_verifier.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_engines.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_orchestrator.dart';
import 'package:vaultvoice/features/pipeline/domain/heavy_model_gate.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';

import '../../db/db_test_utils.dart';
import '../../fakes/fake_clock.dart';
import '../../fakes/fake_vault_writer.dart';
import '../../helpers/model_download_server.dart';
import '../pipeline/pipeline_test_utils.dart';

const _secret = 'quarterly merger with initech';
const _hfPath = '/ggerganov/whisper.cpp/resolve/abc/ggml-tiny.en.bin';
const _cdnPath = '/xet-bridge-us/whisper/abc';
const _catalogBase = '/vv-test/catalog/resolve/main/v1/';

/// SEC-02 host egress capture: the production allowlist + gateway behind a
/// recording "proxy" (a local server that sees every request, standing in
/// for mitmproxy), driven through a whole session — catalog refresh, a model
/// download with a CDN redirect, then a full recording → transcript →
/// extraction → note → vault pipeline run. Device-level proxy capture:
/// docs/test-plans/device/SEC-02.md.
void main() {
  late ModelFileServer proxy;
  late Directory tmp;
  late StoragePaths paths;
  late VaultVoiceDatabase db;
  late NetworkActivityLog activity;
  late NetworkGateway gateway;
  var offline = false;
  final bytes = modelBytes(256 * 1024);

  setUpAll(() {
    HttpOverrides.global = null; // a real local server
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    proxy = await ModelFileServer.start();
    tmp = await Directory.systemTemp.createTemp('vv_sec02_');
    paths = StoragePaths(p.join(tmp.path, 'vv'));
    db = VaultVoiceDatabase(NativeDatabase.memory());
    activity = NetworkActivityLog();
    offline = false;
    gateway = NetworkGateway(
      // Production allowlist (MDL-01/MDL-02).
      config: const NetworkConfig(
        allowedHosts: kModelHosts,
        redirectHosts: kModelRedirectHosts,
      ),
      client: LoopbackClient(proxy.port),
      networkDisabled: () async => offline,
      activity: activity,
    );
    proxy.routes['huggingface.co$_hfPath'] = const RedirectRoute(
      'https://us.aws.cdn.hf.co$_cdnPath?Expires=1&Signature=s',
    );
    proxy.routes['us.aws.cdn.hf.co$_cdnPath'] = FileRoute(bytes);
  });

  tearDown(() async {
    gateway.close();
    await db.close();
    await proxy.close();
    await activity.dispose();
    await tmp.delete(recursive: true);
  });

  Future<void> session() async {
    // 1. Catalog refresh. Production has no catalog endpoint until the
    // Hugging Face catalog repo is named (ADR-MDL-01, HF only), so an HF
    // test base stands in (not served by the proxy → 404).
    final catalog = CatalogRepository(
      baseUris: [Uri.parse('https://huggingface.co$_catalogBase')],
      gateway: gateway,
      verifier: CatalogVerifier(trustedKeys: pinnedCatalogKeys()),
      stateStore: InMemoryCatalogStateStore(),
      loadAsset: (key) => File(key).readAsBytes(),
    );
    await catalog.loadBundled();
    await catalog.refresh();

    // 2. A model download from the mirror, redirected to the HF CDN.
    final downloader = ModelDownloader(
      paths: paths,
      models: db.modelsRepository,
      transport: GatewayDownloadTransport(gateway),
      device: FakeDownloadDevice(),
      networkDisabled: () async => offline,
      delay: (_) async {},
    );
    await downloader.download(
      testCatalogModel(bytes, urls: const ['https://huggingface.co$_hfPath']),
    );

    // 3. The full pipeline on a recording containing sensitive speech.
    await seedRecordingWithChunks(db, 'r1');
    await seedVaultTarget(db);
    final llm = ScriptedLlm(
      output: '{"summary":"$_secret","action_items":["Call $_secret"]}',
    );
    final o = PipelineOrchestrator.withEngines(
      db: db,
      paths: paths,
      engines: PipelineEngines(
        stt: ScriptedStt(),
        llm: llm,
        vault: FakeVaultWriter(),
        clock: FakeClock(t0),
        gate: HeavyModelGate(release: (_) async {}),
      ),
      newId: sequentialIds(),
    );
    addTearDown(o.dispose);
    await o.start();
    final id = expectOk(await o.enqueue('r1'));
    await o.whenIdle();
    expect((await loadJob(db, id)).state, JobState.done);
  }

  test('[SEC-02/AC1] a whole session only contacts allowlisted model hosts, '
      'sends no content and every request is in the activity log', () async {
    await session();
    final allowed = {...kModelHosts, ...kModelRedirectHosts};
    expect(proxy.requests, isNotEmpty);
    for (final r in proxy.requests) {
      expect(allowed, contains(r.host), reason: '${r.host}${r.uri.path}');
      expect(r.headers.keys, isNot(contains('cookie')));
      expect(r.headers.keys, isNot(contains('authorization')));
      final all = '${r.uri}${r.headers}'.toLowerCase();
      expect(all, isNot(contains(_secret)));
      expect(all, isNot(contains('r1')));
    }
    // What was actually seen: the catalog on Hugging Face, the model on
    // Hugging Face and its redirect target — nothing from the pipeline.
    expect(
      {for (final r in proxy.requests) '${r.host}${r.uri.path}'},
      containsAll(<String>[
        'huggingface.co${_catalogBase}catalog.json',
        'huggingface.co$_hfPath',
        'us.aws.cdn.hf.co$_cdnPath',
      ]),
    );
    final installed = File(
      p.join(paths.modelsDir, 'whisper-tiny.en', 'ggml-tiny.en.bin'),
    );
    expect(
      crypto.sha256.convert(installed.readAsBytesSync()),
      crypto.sha256.convert(bytes),
    );

    // The in-app log lists every request (host + path, no query string).
    final logged = [
      for (final e in activity.entries)
        if (e.outcome == NetworkOutcome.completed) '${e.host}${e.path}',
    ];
    expect(logged, [for (final r in proxy.requests) '${r.host}${r.uri.path}']);
    expect(activity.entries.map((e) => e.path).join(), isNot(contains('?')));
  });

  test(
    '[SEC-02/AC1] offline mode: the same session makes zero requests',
    () async {
      offline = true;
      await session();
      expect(proxy.requests, isEmpty);
      expect(activity.entries.map((e) => e.outcome).toSet(), {
        NetworkOutcome.denied,
      });
    },
  );
}
