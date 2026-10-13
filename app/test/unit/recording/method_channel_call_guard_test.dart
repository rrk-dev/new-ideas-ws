import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/platform/call_guard.dart';
import 'package:vaultvoice/features/recording/data/method_channel_call_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const methods = MethodChannel(MethodChannelCallGuard.methodChannelName);

  tearDown(() => messenger.setMockMethodCallHandler(methods, null));

  test('[SEC-09/AC2] isInCall reports the platform in-call state', () async {
    var answer = true;
    messenger.setMockMethodCallHandler(methods, (call) async {
      expect(call.method, 'isInCall');
      return answer;
    });
    final guard = MethodChannelCallGuard();
    expect((await guard.isInCall()).valueOrNull, isTrue);
    answer = false;
    expect((await guard.isInCall()).valueOrNull, isFalse);
  });

  test('[SEC-09/AC2] a missing or failing platform side is an error '
      '(callers fail closed)', () async {
    final guard = MethodChannelCallGuard();
    // No handler registered → MissingPluginException.
    expect((await guard.isInCall()).isOk, isFalse);

    messenger.setMockMethodCallHandler(
      methods,
      (_) async => throw PlatformException(code: 'unavailable'),
    );
    expect((await guard.isInCall()).isOk, isFalse);

    messenger.setMockMethodCallHandler(methods, (_) async => null);
    expect((await guard.isInCall()).isOk, isFalse);
  });

  test('[SEC-09/AC2] platform events decode to timestamped signals', () async {
    const name = MethodChannelCallGuard.eventChannelName;
    const codec = StandardMethodCodec();
    messenger.setMockMethodCallHandler(const MethodChannel(name), (call) async {
      if (call.method == 'listen') {
        for (final payload in <Object?>[
          {'signal': 'callActive', 'atMs': 1000},
          {'signal': 'bogus', 'atMs': 1},
          'not a map',
          {'signal': 'callEnded'},
          {'signal': 'callEnded', 'atMs': 2500},
        ]) {
          await messenger.handlePlatformMessage(
            name,
            codec.encodeSuccessEnvelope(payload),
            (_) {},
          );
        }
      }
      return null;
    });
    final events = await MethodChannelCallGuard().events.take(2).toList();
    expect(events.map((e) => e.signal), [
      CallGuardSignal.callActive,
      CallGuardSignal.callEnded,
    ]);
    expect(
      events.first.at,
      DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
    );
    expect(events.last.at.millisecondsSinceEpoch, 2500);
    messenger.setMockMethodCallHandler(const MethodChannel(name), null);
  });

  test('[SEC-09/AC3] blocking signals are exactly call, interruption and '
      'silenced', () {
    expect(CallGuardSignal.values.where((s) => s.blocksCapture).toSet(), {
      CallGuardSignal.callActive,
      CallGuardSignal.interruptionBegan,
      CallGuardSignal.captureSilenced,
    });
    for (final s in CallGuardSignal.values) {
      expect(CallGuardSignal.tryParse(s.name), s);
    }
    expect(CallGuardSignal.tryParse(42), isNull);
  });
}
