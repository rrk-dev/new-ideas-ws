import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/network/model_hosts.dart';
import 'package:vaultvoice/core/network/network_activity.dart';
import 'package:vaultvoice/core/network/network_gateway.dart';
import 'package:vaultvoice/core/platform/clock.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/core/platform/stt_engine.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';

part 'providers.g.dart';

// Engine providers have no default: the owning feature supplies the real
// implementation (STT-xx, LLM-xx, EXP-xx) by overriding the provider in
// `bootstrap`; tests override with the fakes in `test/fakes/`.
// Microphone capture is not an engine provider: it is opened only through
// `recordingControllerProvider` (features/recording, SEC-09 / AUD-01).

@Riverpod(keepAlive: true)
SttEngine sttEngine(Ref ref) =>
    throw UnimplementedError('sttEngineProvider must be overridden');

@Riverpod(keepAlive: true)
LlmEngine llmEngine(Ref ref) =>
    throw UnimplementedError('llmEngineProvider must be overridden');

@Riverpod(keepAlive: true)
VaultWriter vaultWriter(Ref ref) =>
    throw UnimplementedError('vaultWriterProvider must be overridden');

@Riverpod(keepAlive: true)
Clock clock(Ref ref) => const SystemClock();

/// `libvv_native` outside an app bundle (host tests and tools); null on
/// devices, where the library is bundled with the app.
@Riverpod(keepAlive: true)
String? nativeLibraryPath(Ref ref) => null;

/// Allowlist config: model catalog/CDN hosts only (MDL-01).
@Riverpod(keepAlive: true)
NetworkConfig networkConfig(Ref ref) => const NetworkConfig(
  allowedHosts: kModelHosts,
  redirectHosts: kModelRedirectHosts,
);

/// In-app "Network activity" log (SEC-02). In memory by default;
/// `bootstrap` overrides it with the file-backed log `vv/network/`.
@Riverpod(keepAlive: true)
NetworkActivityLog networkActivityLog(Ref ref) {
  final log = NetworkActivityLog();
  ref.onDispose(log.dispose);
  return log;
}

/// Organisation policy that switches the network off (MDM
/// `network_disabled`). The default is "not managed"; `bootstrap` overrides
/// it with the LIC-04 managed configuration.
@Riverpod(keepAlive: true)
Future<bool> Function() managedNetworkDisabled(Ref ref) =>
    () async => false;

@Riverpod(keepAlive: true)
NetworkGateway networkGateway(Ref ref) {
  final gateway = NetworkGateway(
    config: ref.watch(networkConfigProvider),
    activity: ref.watch(networkActivityLogProvider),
    now: ref.watch(clockProvider).now,
    // Checked before every request; unreadable → refused (fail closed).
    networkDisabled: () async {
      if (await ref.read(managedNetworkDisabledProvider)()) return true;
      final value = await ref
          .read(settingsRepositoryProvider)
          .get(kNetworkDisabledKey);
      if (!value.isOk) throw StateError('settings unreadable');
      return value.valueOrNull == true;
    },
  );
  ref.onDispose(gateway.close);
  return gateway;
}
