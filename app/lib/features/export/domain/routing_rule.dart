import 'package:flutter/foundation.dart' show immutable;

/// What happens after a rule matched (vv-markdown-vault-export → routing).
enum RuleMode {
  /// First match wins: no later rule is evaluated.
  stop,

  /// Multi-target: the note also goes to this rule's target, and evaluation
  /// continues with the next rule.
  continueMatching;

  /// Name persisted in `routing_rules.match.mode`.
  String get wire => this == stop ? 'stop' : 'continue';

  static RuleMode fromWire(Object? raw) =>
      raw == 'continue' ? continueMatching : stop;
}

/// The conditions of a routing rule. Every *non-empty* condition must hold
/// (AND); inside one condition any value may match (OR). A rule without any
/// condition matches every note (a catch-all).
///
/// Matching is case-insensitive. Tags ignore a leading `#`; keywords match
/// as substrings of the note title or summary; speakers match a speaker's
/// display name (or label when it has no name). Persisted as the JSON map in
/// `routing_rules.match` (FND-04 schema v1), together with [RoutingRule.mode],
/// [RoutingRule.name] and [RoutingRule.enabled].
@immutable
class RuleMatch {
  const RuleMatch({
    this.profileIds = const [],
    this.tagsAny = const [],
    this.keywordsAny = const [],
    this.speakersAny = const [],
    this.classificationAny = const [],
  });

  factory RuleMatch.fromJson(Map<String, Object?> json) => RuleMatch(
    profileIds: _strings(json['profile_ids']),
    tagsAny: _strings(json['tags_any']),
    keywordsAny: _strings(json['keywords_any']),
    speakersAny: _strings(json['speakers_any']),
    classificationAny: _strings(json['classification_any']),
  );

  /// Profile ids the note was extracted with (`meeting`, …).
  final List<String> profileIds;
  final List<String> tagsAny;
  final List<String> keywordsAny;
  final List<String> speakersAny;

  /// Profile ids suggested by auto classification (PRF-06).
  final List<String> classificationAny;

  bool get isCatchAll =>
      profileIds.isEmpty &&
      tagsAny.isEmpty &&
      keywordsAny.isEmpty &&
      speakersAny.isEmpty &&
      classificationAny.isEmpty;

  static List<String> _strings(Object? raw) => raw is List
      ? [
          for (final v in raw)
            if (v is String && v.trim().isNotEmpty) v.trim(),
        ]
      : const [];

  Map<String, Object?> toJson() => {
    if (profileIds.isNotEmpty) 'profile_ids': profileIds,
    if (tagsAny.isNotEmpty) 'tags_any': tagsAny,
    if (keywordsAny.isNotEmpty) 'keywords_any': keywordsAny,
    if (speakersAny.isNotEmpty) 'speakers_any': speakersAny,
    if (classificationAny.isNotEmpty) 'classification_any': classificationAny,
  };
}

/// One routing rule (`routing_rules` row): when [match] holds, the note
/// goes to [targetId] under [subPath], named by [filenamePattern] (null =
/// the target's / global pattern).
@immutable
class RoutingRule {
  const RoutingRule({
    required this.id,
    required this.priority,
    required this.targetId,
    this.match = const RuleMatch(),
    this.mode = RuleMode.stop,
    this.subPath = '',
    this.filenamePattern,
    this.name,
    this.enabled = true,
  });

  /// Builds a rule from the `routing_rules` columns.
  factory RoutingRule.fromRow({
    required String id,
    required int priority,
    required String targetId,
    required Map<String, Object?> match,
    required String subPath,
    String? filenamePattern,
  }) => RoutingRule(
    id: id,
    priority: priority,
    targetId: targetId,
    match: RuleMatch.fromJson(match),
    mode: RuleMode.fromWire(match['mode']),
    subPath: subPath,
    filenamePattern: filenamePattern,
    name: match['name'] is String ? match['name']! as String : null,
    enabled: match['enabled'] != false,
  );

  final String id;

  /// Lower is evaluated first.
  final int priority;
  final String targetId;
  final RuleMatch match;
  final RuleMode mode;

  /// Folder inside the target (`Meetings/2026`), `''` = target root.
  final String subPath;
  final String? filenamePattern;

  /// Optional user label (user content: shown, never logged).
  final String? name;

  /// Disabled rules are kept but skipped.
  final bool enabled;

  /// The `routing_rules.match` JSON (conditions + mode/name/enabled).
  Map<String, Object?> matchJson() => {
    ...match.toJson(),
    'mode': mode.wire,
    if (name != null && name!.trim().isNotEmpty) 'name': name!.trim(),
    if (!enabled) 'enabled': false,
  };

  RoutingRule copyWith({
    int? priority,
    String? targetId,
    RuleMatch? match,
    RuleMode? mode,
    String? subPath,
    String? Function()? filenamePattern,
    String? Function()? name,
    bool? enabled,
  }) => RoutingRule(
    id: id,
    priority: priority ?? this.priority,
    targetId: targetId ?? this.targetId,
    match: match ?? this.match,
    mode: mode ?? this.mode,
    subPath: subPath ?? this.subPath,
    filenamePattern: filenamePattern == null
        ? this.filenamePattern
        : filenamePattern(),
    name: name == null ? this.name : name(),
    enabled: enabled ?? this.enabled,
  );

  @override
  String toString() => 'RoutingRule($id, p$priority, ${mode.wire})';
}
