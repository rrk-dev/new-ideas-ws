import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/network/model_hosts.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/features/licensing/data/managed_config_providers.dart';
import 'package:vaultvoice/features/models/data/catalog_providers.dart';
import 'package:vaultvoice/features/models/data/gateway_download_transport.dart';
import 'package:vaultvoice/features/models/data/model_download_channel.dart';
import 'package:vaultvoice/features/models/data/model_downloader.dart';
import 'package:vaultvoice/features/models/data/model_import_providers.dart';
import 'package:vaultvoice/features/models/domain/download_transport.dart';

part 'download_providers.g.dart';

/// Settings key: user allowed model downloads over cellular (default false).
const kAllowCellularDownloadsKey = 'models.allow_cellular_downloads';

@Riverpod(keepAlive: true)
MethodChannelDownloadPlatform modelDownloadPlatform(Ref ref) =>
    const MethodChannelDownloadPlatform();

/// iOS: background download session (survives suspension/termination).
/// Android / host: in-process gateway stream kept alive by a `dataSync`
/// foreground service (ADR-MDL-02).
@Riverpod(keepAlive: true)
DownloadTransport modelDownloadTransport(Ref ref) {
  final gateway = ref.watch(networkGatewayProvider);
  return Platform.isIOS
      ? BackgroundSessionTransport(gateway)
      : GatewayDownloadTransport(gateway);
}

@Riverpod(keepAlive: true)
Future<ModelDownloader> modelDownloader(Ref ref) async {
  final paths = await ref.watch(storagePathsProvider.future);
  final platform = ref.watch(modelDownloadPlatformProvider);
  final settings = ref.watch(settingsRepositoryProvider);
  final downloader = ModelDownloader(
    paths: paths,
    models: ref.watch(modelsRepositoryProvider),
    transport: ref.watch(modelDownloadTransportProvider),
    device: platform,
    keepAlive: platform,
    clock: ref.watch(clockProvider),
    cellularAllowedSetting: () async =>
        (await settings.get(kAllowCellularDownloadsKey)).valueOrNull == true,
    networkDisabled: () async {
      if ((await readManagedConfig(ref)).networkDisabled) return true;
      final v = await settings.get(kNetworkDisabledKey);
      return !v.isOk || v.valueOrNull == true;
    },
  );
  // MDL-04: turning network_disabled on stops transfers already running.
  ref.listen(networkDisabledProvider, (_, next) {
    if (next.value == true) downloader.pauseAll();
  });
  return downloader;
}

/// Resumes downloads interrupted by an app kill (MDL-02/AC1). Watched once
/// at app start; returns the resumed model ids (empty on any error — never
/// blocks startup).
@Riverpod(keepAlive: true)
Future<List<String>> resumeModelDownloads(Ref ref) async {
  try {
    final downloader = await ref.watch(modelDownloaderProvider.future);
    if ((await downloader.pendingModelIds()).isEmpty) return const [];
    final repo = ref.watch(catalogRepositoryProvider);
    final catalog = repo.current ?? (await repo.loadBundled()).valueOrNull;
    if (catalog == null) return const [];
    return await downloader.resumePending(catalog);
  } on Object {
    return const [];
  }
}
