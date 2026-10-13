import 'package:riverpod_annotation/riverpod_annotation.dart';
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

/// Allowlist config; MDL-01 fills in the model catalog/CDN hosts.
@Riverpod(keepAlive: true)
NetworkConfig networkConfig(Ref ref) => const NetworkConfig();

@Riverpod(keepAlive: true)
NetworkGateway networkGateway(Ref ref) {
  final gateway = NetworkGateway(config: ref.watch(networkConfigProvider));
  ref.onDispose(gateway.close);
  return gateway;
}
