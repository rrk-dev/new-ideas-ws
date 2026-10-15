import 'dart:convert';

/// Counts-only picture of the external beta (REL-04). No tester names,
/// transcripts, or file names.
final class BetaReport {
  const BetaReport({
    required this.iosTesters,
    required this.androidTesters,
    required this.crashFreeSessionRate,
    required this.dataLossReports,
    required this.extractionSatisfaction,
    required this.openS1,
  });

  final int iosTesters;
  final int androidTesters;
  final double crashFreeSessionRate;
  final int dataLossReports;

  /// Mean satisfaction as a fraction from 0 to 1 (1.0 = 5/5).
  final double extractionSatisfaction;
  final int openS1;

  int get testers => iosTesters + androidTesters;
}

/// Thresholds from `tools/release/beta_thresholds.json`.
final class BetaThresholds {
  const BetaThresholds({
    required this.minTesters,
    required this.minCrashFreeSessionRate,
    required this.maxDataLossReports,
    required this.minExtractionSatisfaction,
    required this.maxOpenS1,
  });

  factory BetaThresholds.fromJson(Map<String, Object?> json) => BetaThresholds(
    minTesters: (json['min_testers']! as num).toInt(),
    minCrashFreeSessionRate: (json['min_crash_free_session_rate']! as num)
        .toDouble(),
    maxDataLossReports: (json['max_data_loss_reports']! as num).toInt(),
    minExtractionSatisfaction: (json['min_extraction_satisfaction']! as num)
        .toDouble(),
    maxOpenS1: (json['max_open_s1']! as num).toInt(),
  );

  factory BetaThresholds.parse(String source) {
    final json = jsonDecode(source);
    if (json is! Map) {
      throw const FormatException('thresholds must be an object');
    }
    return BetaThresholds.fromJson(Map<String, Object?>.from(json));
  }

  final int minTesters;
  final double minCrashFreeSessionRate;
  final int maxDataLossReports;
  final double minExtractionSatisfaction;
  final int maxOpenS1;
}

/// Whether a production release is allowed. [blockers] is empty only when
/// every exit criterion holds.
final class BetaExitDecision {
  const BetaExitDecision(this.blockers);

  final List<String> blockers;

  bool get met => blockers.isEmpty;
}

/// Production stays closed until the beta has enough testers on both
/// platforms and the quality bars in [thresholds] are met.
BetaExitDecision evaluateBetaExit(
  BetaReport report,
  BetaThresholds thresholds,
) {
  final blockers = <String>[];
  if (report.iosTesters < 1 || report.androidTesters < 1) {
    blockers.add(
      'need testers on both iOS and Android '
      '(ios=${report.iosTesters}, android=${report.androidTesters})',
    );
  }
  if (report.testers < thresholds.minTesters) {
    blockers.add(
      'need at least ${thresholds.minTesters} beta testers '
      '(have ${report.testers})',
    );
  }
  if (report.crashFreeSessionRate < thresholds.minCrashFreeSessionRate) {
    blockers.add(
      'crash-free sessions ${report.crashFreeSessionRate} '
      'is below ${thresholds.minCrashFreeSessionRate}',
    );
  }
  if (report.dataLossReports > thresholds.maxDataLossReports) {
    blockers.add(
      'data-loss reports ${report.dataLossReports} '
      'exceed ${thresholds.maxDataLossReports}',
    );
  }
  if (report.extractionSatisfaction < thresholds.minExtractionSatisfaction) {
    blockers.add(
      'extraction satisfaction ${report.extractionSatisfaction} '
      'is below ${thresholds.minExtractionSatisfaction}',
    );
  }
  if (report.openS1 > thresholds.maxOpenS1) {
    blockers.add(
      'open S1 beta issues ${report.openS1} exceed ${thresholds.maxOpenS1}',
    );
  }
  return BetaExitDecision(blockers);
}
