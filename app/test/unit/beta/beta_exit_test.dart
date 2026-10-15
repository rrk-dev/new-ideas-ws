import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/beta/domain/beta_exit.dart';

BetaReport _passing() => const BetaReport(
  iosTesters: 20,
  androidTesters: 30,
  crashFreeSessionRate: 0.995,
  dataLossReports: 0,
  extractionSatisfaction: 0.8,
  openS1: 0,
);

void main() {
  test('[REL-04/AC1] production stays blocked until 50 testers '
      'across platforms and the exit criteria are met', () {
    final file = File('tools/release/beta_thresholds.json').existsSync()
        ? File('tools/release/beta_thresholds.json')
        : File('../tools/release/beta_thresholds.json');
    final thresholds = BetaThresholds.parse(file.readAsStringSync());
    // Literals, not "whatever the file says", so a lowered bar fails.
    expect(thresholds.minTesters, 50);
    expect(thresholds.minCrashFreeSessionRate, 0.995);
    expect(thresholds.maxDataLossReports, 0);
    expect(thresholds.minExtractionSatisfaction, 0.8);
    expect(thresholds.maxOpenS1, 0);

    expect(evaluateBetaExit(_passing(), thresholds).met, isTrue);

    final short = evaluateBetaExit(
      const BetaReport(
        iosTesters: 19,
        androidTesters: 30,
        crashFreeSessionRate: 0.995,
        dataLossReports: 0,
        extractionSatisfaction: 0.8,
        openS1: 0,
      ),
      thresholds,
    );
    expect(19 + 30, 49);
    expect(short.met, isFalse);
    expect(short.blockers.join('\n'), contains('50'));

    final onePlatform = evaluateBetaExit(
      const BetaReport(
        iosTesters: 50,
        androidTesters: 0,
        crashFreeSessionRate: 0.995,
        dataLossReports: 0,
        extractionSatisfaction: 0.8,
        openS1: 0,
      ),
      thresholds,
    );
    expect(onePlatform.met, isFalse);
    expect(onePlatform.blockers.join('\n'), contains('both'));

    expect(
      evaluateBetaExit(
        const BetaReport(
          iosTesters: 20,
          androidTesters: 30,
          crashFreeSessionRate: 0.994,
          dataLossReports: 0,
          extractionSatisfaction: 0.8,
          openS1: 0,
        ),
        thresholds,
      ).met,
      isFalse,
    );
    expect(
      evaluateBetaExit(
        const BetaReport(
          iosTesters: 20,
          androidTesters: 30,
          crashFreeSessionRate: 0.995,
          dataLossReports: 1,
          extractionSatisfaction: 0.8,
          openS1: 0,
        ),
        thresholds,
      ).met,
      isFalse,
    );
    expect(
      evaluateBetaExit(
        const BetaReport(
          iosTesters: 20,
          androidTesters: 30,
          crashFreeSessionRate: 0.995,
          dataLossReports: 0,
          extractionSatisfaction: 0.79,
          openS1: 0,
        ),
        thresholds,
      ).met,
      isFalse,
    );
    expect(
      evaluateBetaExit(
        const BetaReport(
          iosTesters: 20,
          androidTesters: 30,
          crashFreeSessionRate: 0.995,
          dataLossReports: 0,
          extractionSatisfaction: 0.8,
          openS1: 1,
        ),
        thresholds,
      ).met,
      isFalse,
    );
  });
}
