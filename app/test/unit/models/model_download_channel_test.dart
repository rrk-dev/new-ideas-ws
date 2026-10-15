import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/network/network_gateway.dart';
import 'package:vaultvoice/features/models/data/model_download_channel.dart';
import 'package:vaultvoice/features/models/domain/download_transport.dart';

/// Dart side of the native model-download channel (iOS background session
/// transport + device facts). The native code itself is covered by the
/// device rows in docs/test-plans/device/MDL-02.md.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const codec = StandardMethodCodec();
  late List<MethodCall> calls;
  late List<Uri> httpRequests;

  /// Native answers: `bgStart` → [onStart] decides which events to send.
  void mockNative(void Function(MethodCall start)? onStart) {
    calls = [];
    messenger.setMockMethodCallHandler(kModelDownloadChannel, (call) async {
      calls.add(call);
      if (call.method == 'bgStart') onStart?.call(call);
      if (call.method == 'networkStatus') {
        return {'connected': true, 'unmetered': false, 'lowPowerMode': true};
      }
      if (call.method == 'freeBytes') return 1234;
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(kModelDownloadChannel, null),
    );
  }

  Future<void> nativeEvent(Map<String, Object?> event) async {
    await messenger.handlePlatformMessage(
      kModelDownloadChannel.name,
      codec.encodeMethodCall(MethodCall('bgEvent', event)),
      (_) {},
    );
  }

  NetworkGateway gateway() {
    httpRequests = [];
    return NetworkGateway(
      config: const NetworkConfig(
        allowedHosts: {'huggingface.co'},
        redirectHosts: {'us.aws.cdn.hf.co'},
      ),
      client: MockClient((req) async {
        httpRequests.add(req.url);
        return switch (req.url.host) {
          'huggingface.co' when req.url.path == '/evil' => http.Response(
            '',
            302,
            headers: {'location': 'https://evil.example/m'},
          ),
          'huggingface.co' => http.Response(
            '',
            302,
            headers: {'location': 'https://us.aws.cdn.hf.co/x?sig=1'},
          ),
          'us.aws.cdn.hf.co' => http.Response('', 206),
          _ => http.Response('', 404),
        };
      }),
    );
  }

  TransportRequest request(String path, {int offset = 10}) => TransportRequest(
    modelId: 'whisper-tiny.en',
    uri: Uri.parse('https://huggingface.co$path'),
    partial: File('/tmp/vv/models/.partial/whisper-tiny.en'),
    offset: offset,
    totalBytes: 100,
    headers: const {'User-Agent': 'VaultVoice/1', 'Accept': '*/*'},
    allowCellular: false,
  );

  Future<Failure?> noCheck() async => null;

  test('[MDL-02/AC3] iOS transport hands the validated final URL to the '
      'background session and maps its completion', () async {
    final progress = <int>[];
    mockNative((start) {
      final key = (start.arguments as Map)['key'];
      unawaited(
        Future<void>.microtask(() async {
          await nativeEvent({'key': key, 'event': 'progress', 'length': 60});
          await nativeEvent({
            'key': key,
            'event': 'done',
            'result': 'completed',
            'etag': '"abc"',
          });
        }),
      );
    });
    final t = BackgroundSessionTransport(gateway());
    final out = await t.fetch(
      request('/r/resolve/x/m.bin'),
      control: DownloadControl(),
      onProgress: progress.add,
      checkpoint: noCheck,
    );
    expect(out, isA<TransportCompleted>());
    expect((out as TransportCompleted).validator, '"abc"');
    expect(progress, [60]);
    final start = calls.firstWhere((c) => c.method == 'bgStart');
    final args = (start.arguments as Map).cast<String, Object?>();
    expect(args['url'], 'https://us.aws.cdn.hf.co/x?sig=1');
    expect((args['headers']! as Map)['Range'], 'bytes=10-');
    expect(args['offset'], 10);
    expect(args['allowCellular'], isFalse);
    expect((args['allowedHosts']! as List).toSet(), {
      'huggingface.co',
      'us.aws.cdn.hf.co',
    });
    expect(calls.last.method, 'bgAck');
  });

  test(
    'a redirect to an unlisted host never reaches the native session',
    () async {
      mockNative(null);
      final out = await BackgroundSessionTransport(gateway()).fetch(
        request('/evil'),
        control: DownloadControl(),
        onProgress: (_) {},
        checkpoint: noCheck,
      );
      expect(out, isA<TransportFailed>());
      out as TransportFailed;
      expect(out.retryable, isFalse);
      expect((out.failure as EgressDeniedFailure).host, 'evil.example');
      expect(calls.where((c) => c.method == 'bgStart'), isEmpty);
      expect(httpRequests.map((u) => u.host), ['huggingface.co']);
    },
  );

  test(
    'a native redirect to an unlisted host is a non-retryable denial',
    () async {
      mockNative((start) {
        final key = (start.arguments as Map)['key'];
        unawaited(
          Future<void>.microtask(
            () => nativeEvent({
              'key': key,
              'event': 'done',
              'result': 'redirectDenied',
              'host': 'evil.example',
            }),
          ),
        );
      });
      final out = await BackgroundSessionTransport(gateway()).fetch(
        request('/r/resolve/x/m.bin'),
        control: DownloadControl(),
        onProgress: (_) {},
        checkpoint: noCheck,
      );
      out as TransportFailed;
      expect(out.retryable, isFalse);
      expect(out.failure, isA<EgressDeniedFailure>());
    },
  );

  test('[MDL-02/AC3] [SEC-02/AC1] iOS authorises every redirect before it is '
      'sent (willPerformHTTPRedirection)', () {
    final swift = File('ios/Runner/ModelDownload/ModelDownloadPlugin.swift')
        .readAsStringSync();
    final start = swift.indexOf('willPerformHTTPRedirection');
    expect(start, isNonNegative);
    final body = swift.substring(start, swift.indexOf('didWriteData'));
    expect(body, contains('info.allowedHosts.contains(host)'));
    expect(body, contains('scheme == "https"'));
    expect(body, contains('completionHandler(nil)'));
    expect(body, contains('redirectDenied'));
  });

  test('pause asks the session to keep resume data', () async {
    final control = DownloadControl();
    mockNative(null);
    messenger.setMockMethodCallHandler(kModelDownloadChannel, (call) async {
      calls.add(call);
      if (call.method == 'bgStart') {
        unawaited(Future<void>.microtask(control.pause));
      }
      if (call.method == 'bgPause') {
        final key = (call.arguments as Map)['key'];
        unawaited(
          Future<void>.microtask(
            () =>
                nativeEvent({'key': key, 'event': 'done', 'result': 'stopped'}),
          ),
        );
      }
      return null;
    });
    final out = await BackgroundSessionTransport(gateway()).fetch(
      request('/r/resolve/x/m.bin'),
      control: control,
      onProgress: (_) {},
      checkpoint: noCheck,
    );
    expect(out, isA<TransportStopped>());
    expect(calls.map((c) => c.method), containsAll(['bgPause', 'bgAck']));
  });

  test('device facts are read from the channel; a missing plugin is '
      '"metered" so Wi-Fi-only never silently uses cellular', () async {
    mockNative(null);
    const platform = MethodChannelDownloadPlatform();
    final s = await platform.networkStatus();
    expect(s.connected, isTrue);
    expect(s.unmetered, isFalse);
    expect(s.lowPowerMode, isTrue);
    expect(await platform.freeBytes('/x'), 1234);

    messenger.setMockMethodCallHandler(kModelDownloadChannel, null);
    final missing = await platform.networkStatus();
    expect(missing.unmetered, isFalse);
    expect(await platform.freeBytes('/x'), isNull);
    expect(await platform.excludeFromBackup('/x'), isFalse);
  });
}
