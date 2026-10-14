import 'dart:convert';

import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/features/profiles/domain/post_processors.dart';
import 'package:vaultvoice/features/profiles/domain/profile_issue.dart';
import 'package:vaultvoice/features/profiles/domain/profile_schema.dart';
import 'package:vaultvoice/features/profiles/domain/profile_validator.dart';

export 'package:vaultvoice/core/db/enums.dart' show ProfileSource;

/// The only definition format this app reads and writes (`format: 1`).
const int kProfileFormat = 1;

/// Entitlement tier a profile needs (gated by LIC-01's EntitlementService).
enum ProfileTier { free, pro, enterprise }

/// Per-recording consent step (SEC-07).
enum ConsentConfirmation { required, optional, none }

/// How map-reduce merges a top-level field across chunks (LLM-06).
enum ReduceStrategy {
  unionDedupe('union_dedupe'),
  firstNonNull('first_non_null'),
  llmSummarize('llm_summarize'),
  max('max'),
  min('min');

  ReduceStrategy(this.wireName);

  final String wireName;

  static ReduceStrategy? fromWireName(String name) {
    for (final s in values) {
      if (s.wireName == name) return s;
    }
    return null;
  }
}

/// Identity of one profile version; `extractions.profile_version` records
/// the `version` that produced a result.
typedef ProfileRef = ({String id, int version});

/// Speech-to-text hints.
class ProfileStt {
  const ProfileStt({
    this.vocabulary = const [],
    this.diarization,
    this.numSpeakers,
  });

  /// Joined into Whisper's `initial_prompt` (≤ 200 chars total).
  final List<String> vocabulary;

  /// Null = not specified (the app default applies).
  final bool? diarization;

  /// Speaker-count hint; null = `auto`.
  final int? numSpeakers;

  Map<String, Object?> toJson() => {
    'vocabulary': [...vocabulary],
    'diarization': ?diarization,
    'num_speakers': numSpeakers ?? 'auto',
  };
}

/// One few-shot example (synthetic transcript → expected output).
class ProfileExample {
  const ProfileExample({required this.transcript, required this.output});

  final String transcript;
  final Map<String, Object?> output;

  Map<String, Object?> toJson() => {'transcript': transcript, 'output': output};
}

/// An extraction profile ("skill"): drives STT hints, prompt, output schema,
/// post-processing, template and routing. Immutable; build one with
/// [Profile.fromJson] / `ProfileValidator.validate` so it is always valid.
///
/// Spec: `docs/profile-spec.md`.
class Profile {
  const Profile({
    required this.id,
    required this.version,
    required this.name,
    required this.description,
    required this.tier,
    required this.source,
    required this.instructions,
    required this.schema,
    required this.templateId,
    required this.consentConfirmation,
    this.icon,
    this.stt = const ProfileStt(),
    this.classifyKeywords = const [],
    this.mapSchema,
    this.reduce = const {},
    this.postProcess = const [],
    this.examples = const [],
    this.filenamePattern,
    this.defaultTarget,
    this.reviewBeforeExport = false,
  });

  /// Parses and validates a decoded YAML/JSON definition.
  ///
  /// Throws [ProfileFormatException] listing every problem.
  factory Profile.fromJson(
    Map<String, Object?> json, {
    ProfileSource source = ProfileSource.user,
  }) {
    final result = const ProfileValidator().validate(json, source: source);
    if (result.profile case final profile?) return profile;
    throw ProfileFormatException(result.issues);
  }

  final String id;
  final int version;
  final String name;
  final String description;
  final String? icon;
  final ProfileTier tier;

  /// Set by the app (`builtin` for assets, `user`/`enterprise` for DB rows);
  /// never read from a bundle.
  final ProfileSource source;
  final ProfileStt stt;
  final List<String> classifyKeywords;
  final String instructions;
  final ObjectSchema schema;
  final ObjectSchema? mapSchema;

  /// Explicit strategies only; see [reduceStrategyFor] for defaults.
  final Map<String, ReduceStrategy> reduce;
  final List<PostProcessor> postProcess;
  final List<ProfileExample> examples;
  final String templateId;
  final String? filenamePattern;

  /// Vault target id or `ask`; null = app default.
  final String? defaultTarget;
  final bool reviewBeforeExport;
  final ConsentConfirmation consentConfirmation;

  ProfileRef get ref => (id: id, version: version);

  /// Built-in and enterprise (managed) profiles cannot be edited — only
  /// duplicated.
  bool get isReadOnly => source != ProfileSource.user;

  /// Strategy for top-level [field]: explicit `reduce`, else lists
  /// `union_dedupe`, `summary`/`title` `llm_summarize`, scalars
  /// `first_non_null` (profile spec).
  ReduceStrategy reduceStrategyFor(String field) {
    if (reduce[field] case final s?) return s;
    if (schema.properties[field] is ArraySchema) {
      return ReduceStrategy.unionDedupe;
    }
    if (field == 'summary' || field == 'title') {
      return ReduceStrategy.llmSummarize;
    }
    return ReduceStrategy.firstNonNull;
  }

  /// Canonical definition (stable key order). [includeSource] adds `source`
  /// for DB rows; bundles and assets never carry it.
  Map<String, Object?> toJson({bool includeSource = false}) => {
    'format': kProfileFormat,
    'id': id,
    'version': version,
    'name': name,
    'description': description,
    'icon': ?icon,
    'tier': tier.name,
    if (includeSource) 'source': source.name,
    'stt': stt.toJson(),
    if (classifyKeywords.isNotEmpty)
      'classify': {
        'keywords': [...classifyKeywords],
      },
    'instructions': instructions,
    'schema': schema.toJson(),
    if (mapSchema case final m?) 'map_schema': m.toJson(),
    if (reduce.isNotEmpty)
      'reduce': {for (final e in reduce.entries) e.key: e.value.wireName},
    if (postProcess.isNotEmpty)
      'post_process': [for (final p in postProcess) p.wireName],
    if (examples.isNotEmpty) 'examples': [for (final e in examples) e.toJson()],
    'template_id': templateId,
    'filename_pattern': ?filenamePattern,
    if (defaultTarget case final t?) 'routing': {'default_target': t},
    'review_before_export': reviewBeforeExport,
    'consent_confirmation': consentConfirmation.name,
  };

  /// Hash input of everything that changes extraction results; a change
  /// requires a version bump (profile spec: `version`).
  String get extractionFingerprint => jsonEncode({
    'instructions': instructions,
    'schema': schema.toJson(),
    'map_schema': mapSchema?.toJson(),
    'examples': [for (final e in examples) e.toJson()],
    'reduce': {for (final e in reduce.entries) e.key: e.value.wireName},
    'post_process': [for (final p in postProcess) p.wireName],
  });

  /// A copy with a new identity/ownership (duplicate, save, import).
  Profile copyWith({
    String? id,
    int? version,
    String? name,
    ProfileSource? source,
    ProfileTier? tier,
  }) => Profile(
    id: id ?? this.id,
    version: version ?? this.version,
    name: name ?? this.name,
    description: description,
    icon: icon,
    tier: tier ?? this.tier,
    source: source ?? this.source,
    stt: stt,
    classifyKeywords: classifyKeywords,
    instructions: instructions,
    schema: schema,
    mapSchema: mapSchema,
    reduce: reduce,
    postProcess: postProcess,
    examples: examples,
    templateId: templateId,
    filenamePattern: filenamePattern,
    defaultTarget: defaultTarget,
    reviewBeforeExport: reviewBeforeExport,
    consentConfirmation: consentConfirmation,
  );

  @override
  String toString() => 'Profile($id v$version, ${source.name})';
}
