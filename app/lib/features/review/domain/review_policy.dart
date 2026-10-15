import 'dart:convert';

import 'package:vaultvoice/core/utils/ids.dart';
import 'package:vaultvoice/features/profiles/domain/profile_issue.dart';
import 'package:vaultvoice/features/profiles/domain/profile_schema.dart';

/// `settings` keys of review-before-export (APP-05).
abstract final class ReviewKeys {
  /// bool per profile: true = review first, false = export automatically.
  /// Unset = the profile's own `review_before_export`.
  static String mode(String profileId) => 'review.mode.$profileId';

  /// String: `extractionHash` of the extraction content the user approved.
  /// The gate passes only while the stored content still has that hash, so
  /// a re-extraction (same extraction id, new content) is reviewed again.
  static String approved(String extractionId) =>
      'review.approved.$extractionId';
}

/// Whether a profile's results need review: the user's setting when set,
/// else the profile's `review_before_export`.
bool reviewRequired({required Object? setting, required bool profileDefault}) =>
    setting is bool ? setting : profileDefault;

/// Stable content hash of extracted JSON (keys sorted at every level).
String extractionHash(Map<String, Object?> json) =>
    fnv1a32(jsonEncode(_canonical(json)));

Object? _canonical(Object? v) => switch (v) {
  final Map<String, Object?> m => {
    for (final k in m.keys.toList()..sort()) k: _canonical(m[k]),
  },
  final List<Object?> l => [for (final e in l) _canonical(e)],
  _ => v,
};

/// Recording position of an evidence timestamp `hh:mm:ss` / `mm:ss` /
/// `ss` (LLM-05 evidence field `t`), or null when it is not one.
int? timestampToMs(Object? t) {
  if (t is! String) return null;
  final parts = t.trim().split(':');
  if (parts.isEmpty || parts.length > 3) return null;
  var seconds = 0;
  for (final p in parts) {
    final n = int.tryParse(p);
    if (n == null || n < 0) return null;
    seconds = seconds * 60 + n;
  }
  return seconds * 1000;
}

/// Content-free problems of [data] against the profile [schema] (types,
/// limits, required fields) — shown before the edited result is exported.
List<ProfileIssue> validateEdited(ObjectSchema schema, Object? data) {
  final sink = IssueSink();
  validateInstance(schema, data, 'result', sink);
  return sink.issues;
}
