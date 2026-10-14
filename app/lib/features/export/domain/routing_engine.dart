import 'package:flutter/foundation.dart' show immutable;
import 'package:unorm_dart/unorm_dart.dart' as unorm;
import 'package:vaultvoice/features/export/domain/routing_rule.dart';

/// What routing may use under the current entitlement (LIC-01).
///
/// The pipeline worker runs in a background isolate without the
/// `EntitlementService`, so the UI isolate mirrors this snapshot into the
/// settings key `export.routing_policy` (see `routingPolicyMirror`); a
/// missing/invalid value decodes to [free] (fail closed).
@immutable
class RoutingPolicy {
  const RoutingPolicy({required this.rulesEnabled, required this.maxTargets});

  factory RoutingPolicy.fromJson(Object? raw) {
    if (raw is! Map) return free;
    final max = raw['max_targets'];
    return RoutingPolicy(
      rulesEnabled: raw['rules'] == true,
      maxTargets: max == null ? null : (max is int && max >= 1 ? max : 1),
    );
  }

  /// Free tier: no rules, one target (vv-licensing-iap).
  static const free = RoutingPolicy(rulesEnabled: false, maxTargets: 1);

  /// Pro / personal build: unlimited.
  static const unlimited = RoutingPolicy(rulesEnabled: true, maxTargets: null);

  /// Routing rules are applied (`Feature.routingRules`). When false they are
  /// kept but ignored (downgrade = read-only).
  final bool rulesEnabled;

  /// Active vault targets, in the user's order (`null` = unlimited,
  /// `Feature.multiTarget`). Targets beyond it are disabled, not deleted.
  final int? maxTargets;

  Map<String, Object?> toJson() => {
    'rules': rulesEnabled,
    'max_targets': maxTargets,
  };

  @override
  bool operator ==(Object other) =>
      other is RoutingPolicy &&
      other.rulesEnabled == rulesEnabled &&
      other.maxTargets == maxTargets;

  @override
  int get hashCode => Object.hash(rulesEnabled, maxTargets);

  @override
  String toString() =>
      'RoutingPolicy(rules: $rulesEnabled, max: ${maxTargets ?? '∞'})';
}

/// The note facts rules match on. User content: never logged.
@immutable
class RoutingInput {
  const RoutingInput({
    required this.profileId,
    this.title,
    this.summary,
    this.tags = const [],
    this.speakers = const [],
    this.classifiedProfileId,
    this.profileDefaultTargetId,
  });

  final String profileId;
  final String? title;
  final String? summary;
  final List<String> tags;

  /// Speaker display names (or labels when unnamed).
  final List<String> speakers;

  /// Auto-classification result (PRF-06), if classification ran.
  final String? classifiedProfileId;

  /// The profile's `routing.default_target` (PRF-01); `ask` is treated as
  /// unset.
  final String? profileDefaultTargetId;
}

/// Why a destination was chosen (content-free, for the export log).
enum RouteSource {
  /// A routing rule matched.
  rule,

  /// No rule matched: the profile's default target.
  profileDefault,

  /// No rule / profile default applied: the first active target.
  fallback,
}

/// One destination of a note.
@immutable
class RouteDecision {
  const RouteDecision({
    required this.targetId,
    required this.source,
    this.subPath = '',
    this.filenamePattern,
    this.ruleId,
  });

  final String targetId;
  final RouteSource source;
  final String subPath;

  /// Rule-specific pattern; null = target / global pattern.
  final String? filenamePattern;
  final String? ruleId;

  @override
  bool operator ==(Object other) =>
      other is RouteDecision &&
      other.targetId == targetId &&
      other.source == source &&
      other.subPath == subPath &&
      other.filenamePattern == filenamePattern &&
      other.ruleId == ruleId;

  @override
  int get hashCode =>
      Object.hash(targetId, source, subPath, filenamePattern, ruleId);

  @override
  String toString() => 'RouteDecision($targetId, ${source.name}, $ruleId)';
}

/// PRODUCT-DECISION: a profile's `default_target: ask` is treated as "no
/// default" (first active target) until a destination prompt exists.
const String kAskTarget = 'ask';

String _fold(String s) => unorm.nfc(s).toLowerCase().trim();

String _tag(String s) => _fold(s.replaceFirst(RegExp('^#+'), ''));

/// Pure routing (vv-markdown-vault-export → "Vault targets & routing").
///
/// [targetIds] are the user's vault targets in display order; only the
/// first [RoutingPolicy.maxTargets] are active. With rules enabled, rules
/// run by ascending priority (ties: id); disabled rules and rules whose
/// target is inactive or gone are skipped. A matching `stop` rule ends the
/// evaluation; `continue` rules add a destination and go on. A target is
/// used at most once per note (the first matching rule wins — exports are
/// keyed by recording × target). No match ⇒ the profile default target (if
/// active) ⇒ the first active target. No active target ⇒ an empty list
/// (the pipeline then waits for a destination).
List<RouteDecision> routeNote({
  required RoutingInput input,
  required List<RoutingRule> rules,
  required List<String> targetIds,
  required RoutingPolicy policy,
}) {
  final max = policy.maxTargets;
  final active = (max == null || targetIds.length <= max)
      ? targetIds
      : targetIds.sublist(0, max);
  if (active.isEmpty) return const [];
  final activeSet = active.toSet();

  final decisions = <RouteDecision>[];
  final used = <String>{};
  if (policy.rulesEnabled) {
    final ordered = [...rules]
      ..sort((a, b) {
        final p = a.priority.compareTo(b.priority);
        return p != 0 ? p : a.id.compareTo(b.id);
      });
    for (final rule in ordered) {
      if (!rule.enabled || !activeSet.contains(rule.targetId)) continue;
      if (!ruleMatches(rule.match, input)) continue;
      if (used.add(rule.targetId)) {
        decisions.add(
          RouteDecision(
            targetId: rule.targetId,
            source: RouteSource.rule,
            subPath: rule.subPath,
            filenamePattern: rule.filenamePattern,
            ruleId: rule.id,
          ),
        );
      }
      if (rule.mode == RuleMode.stop) break;
    }
  }
  if (decisions.isNotEmpty) return List.unmodifiable(decisions);

  final profileDefault = input.profileDefaultTargetId;
  if (profileDefault != null &&
      profileDefault != kAskTarget &&
      activeSet.contains(profileDefault)) {
    return [
      RouteDecision(
        targetId: profileDefault,
        source: RouteSource.profileDefault,
      ),
    ];
  }
  return [RouteDecision(targetId: active.first, source: RouteSource.fallback)];
}

/// Whether every non-empty condition of [match] holds for [input].
bool ruleMatches(RuleMatch match, RoutingInput input) {
  bool anyOf(
    List<String> wanted,
    Iterable<String> have,
    String Function(String) norm,
  ) {
    final set = {for (final h in have) norm(h)};
    return wanted.any((w) => set.contains(norm(w)));
  }

  if (match.profileIds.isNotEmpty &&
      !anyOf(match.profileIds, [input.profileId], _fold)) {
    return false;
  }
  if (match.classificationAny.isNotEmpty &&
      (input.classifiedProfileId == null ||
          !anyOf(match.classificationAny, [
            input.classifiedProfileId!,
          ], _fold))) {
    return false;
  }
  if (match.tagsAny.isNotEmpty && !anyOf(match.tagsAny, input.tags, _tag)) {
    return false;
  }
  if (match.speakersAny.isNotEmpty &&
      !anyOf(match.speakersAny, input.speakers, _fold)) {
    return false;
  }
  if (match.keywordsAny.isNotEmpty) {
    final haystack = _fold('${input.title ?? ''}\n${input.summary ?? ''}');
    final hit = match.keywordsAny.any((k) {
      final needle = _fold(k);
      return needle.isNotEmpty && haystack.contains(needle);
    });
    if (!hit) return false;
  }
  return true;
}
