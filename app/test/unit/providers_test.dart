import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/flavor.dart';
import 'package:vaultvoice/core/flavor_provider.dart';
import 'package:vaultvoice/core/network/network_gateway.dart';
import 'package:vaultvoice/core/platform/clock.dart';
import 'package:vaultvoice/core/platform/providers.dart';

import '../fakes/fake_clock.dart';
import '../helpers/test_container.dart';

void main() {
  test('defaults: prod flavor, system clock, empty allowlist', () {
    final c = createContainer();
    expect(c.read(flavorProvider), Flavor.prod);
    expect(c.read(flavorProvider).isDev, isFalse);
    expect(c.read(clockProvider), isA<SystemClock>());
    expect(c.read(networkConfigProvider).allowedHosts, isEmpty);
  });

  test('every engine provider throws until overridden', () {
    final c = createContainer();
    for (final read in <void Function()>[
      () => c.read(audioRecorderProvider),
      () => c.read(sttEngineProvider),
      () => c.read(llmEngineProvider),
      () => c.read(vaultWriterProvider),
    ]) {
      expect(read, throwsA(anything));
    }
  });

  test('gateway provider uses the configured allowlist and is closed', () {
    final c = createContainer(
      overrides: [
        networkConfigProvider.overrideWithValue(
          const NetworkConfig(allowedHosts: {'cdn.example.com'}),
        ),
      ],
    );
    expect(c.read(networkGatewayProvider).config.allowedHosts, {
      'cdn.example.com',
    });
  });

  test('clock override and FakeClock advance', () {
    final clock = FakeClock(DateTime.utc(2026));
    final c = createContainer(overrides: fakeEngineOverrides(clock: clock));
    clock.advance(const Duration(hours: 1));
    expect(c.read(clockProvider).now(), DateTime.utc(2026, 1, 1, 1));
    expect(const SystemClock().now().isUtc, isFalse);
  });

  test('failures carry content-free, descriptive messages', () {
    const failures = <Failure>[
      PermissionFailure('microphone'),
      StorageFailure('disk full'),
      ModelMissingFailure('whisper-tiny'),
      OutOfMemoryFailure(),
      CancelledFailure(),
      NativeFailure(7, 'bridge error'),
      EgressDeniedFailure('evil.example'),
      NetworkFailure('ClientException'),
      UnexpectedFailure('StateError'),
    ];
    for (final f in failures) {
      expect(f.message, isNotEmpty);
      expect(f.toString(), 'Failure(${f.message})');
    }
    expect(const NativeFailure(7, 'x').code, 7);
    expect(const PermissionFailure('microphone').permission, 'microphone');
    expect(const ModelMissingFailure('m').modelId, 'm');
    expect(const EgressDeniedFailure('h').host, 'h');
    expect(const UnexpectedFailure('E').errorType, 'E');
  });
}
