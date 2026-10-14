import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/network/model_hosts.dart';
import 'package:vaultvoice/core/network/network_gateway.dart';
import 'package:vaultvoice/core/platform/audio_recorder.dart';
import 'package:vaultvoice/core/platform/clock.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/core/platform/stt_engine.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';

part 'providers.g.dart';

// Engine providers have no default: the owning feature supplies the real
// implementation (STT-xx, LLM-xx, AUD-xx, EXP-xx) by overriding the provider in
// `bootstrap`; tests override with the fakes in `test/fakes/`.

@Riverpod(keepAlive: true)
AudioRecorder audioRecorder(Ref ref) =>
    throw UnimplementedError('audioRecorderProvider must be overridden');

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

/// Allowlist config: model catalog/CDN hosts only (MDL-01).
@Riverpod(keepAlive: true)
NetworkConfig networkConfig(Ref ref) => const NetworkConfig(
  allowedHosts: kModelHosts,
  redirectHosts: kModelRedirectHosts,
);

@Riverpod(keepAlive: true)
NetworkGateway networkGateway(Ref ref) {
  final gateway = NetworkGateway(
    config: ref.watch(networkConfigProvider),
    // Checked before every request; unreadable → refused (fail closed).
    networkDisabled: () async {
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
