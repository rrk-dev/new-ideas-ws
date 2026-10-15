import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vaultvoice/core/network/model_hosts.dart';
import 'package:vaultvoice/core/network/network_gateway.dart';
import 'package:vaultvoice/features/beta/domain/beta_exit.dart';

/// GATE-04 automatable half (docs/test-plans/gates/GATE-04.md): the release
/// bar is encoded and consistent. The signed-build runs (stress plan,
/// performance protocol, proxy egress capture, beta numbers) are device and
/// human rows in docs/test-plans/device/GATE-04.md.
///   cd app && fvm flutter test integration_test/gate_04_release_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Tests run with cwd = app/.
  String read(String repoPath) => File('../$repoPath').readAsStringSync();

  testWidgets('[GATE-04/AC1] the stress plan has a device row for every '
      'device case, and the zero-data-loss launch rule is stated', (
    tester,
  ) async {
    final plan = read('docs/test-plans/stress.md');
    final rows = read('docs/test-plans/device/QA-04.md');
    expect(plan, contains('zero open data-loss bugs'));
    final covered = <int>{};
    for (final m in RegExp(r'D-(\d+)(?: to D-(\d+))?').allMatches(rows)) {
      final from = int.parse(m[1]!);
      for (var n = from; n <= int.parse(m[2] ?? m[1]!); n++) {
        covered.add(n);
      }
    }
    for (var n = 1; n <= 25; n++) {
      final id = 'D-${n.toString().padLeft(2, '0')}';
      expect(plan, contains('| $id |'), reason: '$id in the plan');
      expect(covered, contains(n), reason: '$id covered by a QA-04 row');
    }
  });

  testWidgets('[GATE-04/AC2] performance budgets exist for the Low and High '
      'tiers and forbid critical thermal states', (tester) async {
    final budgets = jsonDecode(
      read('tools/bench/perf/budgets.json'),
    ) as Map<String, Object?>;
    final tiers = budgets['tiers']! as Map<String, Object?>;
    final high = tiers['high']! as Map<String, Object?>;
    final low = tiers['low']! as Map<String, Object?>;
    expect(high['max_process_minutes_per_60'], 15);
    expect(low['max_process_minutes_per_60'], 30);
    expect(
      budgets['forbidden_thermal_states'],
      containsAll(['critical', 'severe']),
    );
  });

  testWidgets('[GATE-04/AC3] the release gateway reaches only allowlisted '
      'hosts', (tester) async {
    final gateway = NetworkGateway(
      config: const NetworkConfig(
        allowedHosts: kModelHosts,
        redirectHosts: kModelRedirectHosts,
      ),
    );
    for (final host in kModelHosts) {
      expect(
        (await gateway.authorize(Uri.https(host, '/m.bin'))).isOk,
        isTrue,
        reason: host,
      );
    }
    for (final uri in [
      Uri.https('analytics.example.com', '/'),
      Uri.https('us.aws.cdn.hf.co', '/direct'), // redirect-only host
      Uri.http('huggingface.co', '/insecure'),
    ]) {
      expect((await gateway.authorize(uri)).isOk, isFalse, reason: '$uri');
    }
  });

  testWidgets('[GATE-04/AC4] the beta exit bar is ≥ 99.5% crash-free and no '
      'open S1', (tester) async {
    final thresholds = BetaThresholds.parse(
      read('tools/release/beta_thresholds.json'),
    );
    BetaReport report({double crashFree = 0.995, int s1 = 0}) => BetaReport(
      iosTesters: 20,
      androidTesters: 30,
      crashFreeSessionRate: crashFree,
      dataLossReports: 0,
      extractionSatisfaction: 0.8,
      openS1: s1,
    );
    expect(evaluateBetaExit(report(), thresholds).met, isTrue);
    expect(evaluateBetaExit(report(crashFree: 0.994), thresholds).met, isFalse);
    expect(evaluateBetaExit(report(s1: 1), thresholds).met, isFalse);
  });
}
