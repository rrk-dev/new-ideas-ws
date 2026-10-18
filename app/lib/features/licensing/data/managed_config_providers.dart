import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/features/licensing/data/managed_config_source.dart';
import 'package:vaultvoice/features/licensing/domain/managed_config.dart';

part 'managed_config_providers.g.dart';

/// The platform MDM managed configuration (LIC-04). Tests override it.
@Riverpod(keepAlive: true)
ManagedConfigSource managedConfigSource(Ref ref) {
  final source = PlatformManagedConfigSource();
  ref.onDispose(source.dispose);
  return source;
}

/// The current configuration and every change.
@Riverpod(keepAlive: true)
Stream<ManagedConfig> managedConfig(Ref ref) =>
    ref.watch(managedConfigSourceProvider).watch();

/// The configuration as of now, read from the source (not a cached stream
/// value) so an enforcement point never acts on a stale policy.
Future<ManagedConfig> readManagedConfig(Ref ref) =>
    ref.read(managedConfigSourceProvider).read();
