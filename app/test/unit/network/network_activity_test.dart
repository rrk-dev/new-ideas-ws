import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/network/network_activity.dart';
import 'package:vaultvoice/core/network/network_gateway.dart';

void main() {
  final t0 = DateTime.utc(2026, 10, 14, 9);

  test('[SEC-02] the log is bounded, persisted and survives a restart', () {
    final dir = Directory.systemTemp.createTempSync('vv_netlog_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File(p.join(dir.path, 'network', 'activity.jsonl'));
    final log = NetworkActivityLog(file: file, capacity: 3);
    for (var i = 0; i < 5; i++) {
      log.record(
        NetworkActivityEntry.request(
          t0.add(Duration(seconds: i)),
          Uri.parse('https://huggingface.co/m$i?token=secret'),
          NetworkOutcome.completed,
          statusCode: 200,
          bytes: i,
        ),
      );
    }
    expect(log.entries.map((e) => e.path), ['/m2', '/m3', '/m4']);
    expect(file.readAsStringSync(), isNot(contains('secret')));

    final reopened = NetworkActivityLog(file: file, capacity: 3);
    expect(reopened.entries.map((e) => e.path), ['/m2', '/m3', '/m4']);
    expect(reopened.entries.last.bytes, 4);
    expect(reopened.entries.last.statusCode, 200);
    reopened.clear();
    expect(NetworkActivityLog(file: file).entries, isEmpty);

    file.writeAsStringSync('garbage\n{"at":1}\n');
    expect(NetworkActivityLog(file: file).entries, isEmpty);
  });

  test('[SEC-02] the gateway logs completed, denied and failed requests '
      'without query strings', () async {
    final log = NetworkActivityLog();
    var fail = false;
    final gateway = NetworkGateway(
      config: const NetworkConfig(allowedHosts: {'models.example'}),
      client: MockClient((req) async {
        if (fail) throw http.ClientException('down');
        return http.Response('abc', 200);
      }),
      activity: log,
      now: () => t0,
    );
    await gateway.get(Uri.parse('https://models.example/c.json?x=1'));
    await gateway.get(Uri.parse('https://evil.example/leak'));
    await gateway.get(Uri.parse('http://models.example/plain'));
    fail = true;
    await gateway.get(Uri.parse('https://models.example/c.json'));
    await gateway.authorize(Uri.parse('https://models.example/big.bin'));
    expect(
      [for (final e in log.entries) '${e.outcome.name} ${e.host}${e.path}'],
      [
        'completed models.example/c.json',
        'denied evil.example/leak',
        'denied models.example/plain',
        'failed models.example/c.json',
        'handedToSystem models.example/big.bin',
      ],
    );
    expect(log.entries.first.bytes, 3);
    expect(log.entries.first.at, t0);
    final watched = await log.watch().first;
    expect(watched, hasLength(5));
    expect(
      NetworkActivityEntry.fromJson(log.entries.first.toJson())!.host,
      'models.example',
    );
    await log.dispose();
  });
}
