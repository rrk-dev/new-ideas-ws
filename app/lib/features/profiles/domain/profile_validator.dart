import 'package:vaultvoice/features/profiles/domain/post_processors.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/domain/profile_issue.dart';
import 'package:vaultvoice/features/profiles/domain/profile_schema.dart';
import 'package:vaultvoice/features/profiles/domain/render_context.dart';
import 'package:vaultvoice/features/profiles/domain/template_variables.dart';

/// Profile ids (profile spec): `^[a-z][a-z0-9_-]{1,39}$`.
final RegExp kProfileIdPattern = RegExp(r'^[a-z][a-z0-9_-]{1,39}$');

/// Template ids (built-in or user template).
final RegExp kTemplateIdPattern = RegExp(r'^[a-z][a-z0-9_-]{1,63}$');

final RegExp _iconPattern = RegExp(r'^[a-z][a-z0-9_]{0,63}$');

/// Limits from the profile spec.
abstract final class ProfileLimits {
  static const int maxInstructions = 2000;
  static const int maxExamples = 2;
  static const int maxExampleTranscript = 4000;
  static const int maxName = 60;
  static const int maxDescription = 200;
  static const int maxVocabularyChars = 200;
  static const int maxKeywords = 30;
  static const int maxKeywordLength = 40;
  static const int maxSpeakers = 10;
}

/// Top-level keys of a format-1 definition.
const Set<String> kProfileKeys = {
  'format',
  'id',
  'version',
  'name',
  'description',
  'icon',
  'tier',
  'stt',
  'classify',
  'instructions',
  'schema',
  'map_schema',
  'reduce',
  'post_process',
  'examples',
  'template_id',
  'filename_pattern',
  'routing',
  'review_before_export',
  'consent_confirmation',
};

/// Filename-pattern tokens (`vv-markdown-vault-export` → Filename patterns).
const Set<String> kFilenameTokens = {'time', 'title', 'slug', 'profile', 'id'};
final RegExp _dateTokenFormat = RegExp(r'^(YYYY|MM|DD|HH|mm|ss|[-_. ])+$');

/// Outcome of [ProfileValidator.validate]: a [profile] exactly when
/// [issues] is empty.
class ProfileValidation {
  const ProfileValidation(this.profile, this.issues);

  final Profile? profile;
  final List<ProfileIssue> issues;

  bool get isValid => issues.isEmpty;
}

/// Validates profile definitions (PRF-01, spec `docs/profile-spec.md`).
///
/// Every problem is reported, not just the first, each with the key path and
/// what to change (e.g. `schema.action_items[].owner: missing maxLength — …`).
/// Grammar conversion (needs the native bridge) is a separate step run by
/// the repository on save.
class ProfileValidator {
  const ProfileValidator();

  /// Validates a decoded definition. [source] is set by the app (a `source`
  /// key in the definition is an error). [takenIds] are ids used by *other*
  /// profiles (built-ins + stored rows).
  ProfileValidation validate(
    Map<String, Object?> json, {
    ProfileSource source = ProfileSource.user,
    Set<String> takenIds = const {},
  }) {
    final sink = IssueSink();
    for (final key in json.keys) {
      if (key == 'source') {
        sink.add(
          'source',
          'is set by the app (builtin/user/enterprise); remove it',
        );
      } else if (!kProfileKeys.contains(key)) {
        sink.add(key, 'unknown key (allowed: ${kProfileKeys.join(', ')})');
      }
    }

    final format = json['format'];
    if (format == null) {
      sink.add('format', 'missing; add "format: $kProfileFormat"');
    } else if (format != kProfileFormat) {
      sink.add('format', 'unsupported format; this app reads format 1');
    }

    final id = _requiredString(json, 'id', sink);
    if (id != null) {
      if (!kProfileIdPattern.hasMatch(id)) {
        sink.add(
          'id',
          'must match ${kProfileIdPattern.pattern} (lowercase letter first, '
              'then 1-39 of a-z 0-9 _ -)',
        );
      } else if (takenIds.contains(id)) {
        sink.add(
          'id',
          'is already used by another profile; choose a unique id',
        );
      }
    }

    final version = json['version'];
    if (version is! int || version < 1) {
      sink.add('version', 'must be an integer >= 1');
    }

    final name = _requiredString(json, 'name', sink);
    if (name != null && name.length > ProfileLimits.maxName) {
      sink.add('name', 'is ${name.length} chars, max ${ProfileLimits.maxName}');
    }
    final description = _requiredString(json, 'description', sink);
    if (description != null) {
      if (description.length > ProfileLimits.maxDescription) {
        sink.add(
          'description',
          'is ${description.length} chars, max '
              '${ProfileLimits.maxDescription}',
        );
      }
      if (description.contains('\n')) {
        sink.add(
          'description',
          'must be one line (auto-classification lists it)',
        );
      }
    }

    final icon = json['icon'];
    if (icon != null && (icon is! String || !_iconPattern.hasMatch(icon))) {
      sink.add('icon', 'must be a Material icon name such as "groups"');
    }

    final tier = _enum(json, 'tier', ProfileTier.values, sink);
    final consent = _enum(
      json,
      'consent_confirmation',
      ConsentConfirmation.values,
      sink,
    );
    final stt = _parseStt(json['stt'], sink);
    if (stt?.diarization == true && consent == ConsentConfirmation.none) {
      sink.add(
        'consent_confirmation',
        'multi-speaker profiles (stt.diarization: true) must use "required" '
            'or "optional" (SEC-07)',
      );
    }
    final keywords = _parseClassify(json['classify'], sink);

    final instructions = _requiredString(json, 'instructions', sink);
    if (instructions != null &&
        instructions.length > ProfileLimits.maxInstructions) {
      sink.add(
        'instructions',
        'is ${instructions.length} chars, max '
            '${ProfileLimits.maxInstructions}; shorten to imperative bullets',
      );
    }

    final schema = _parseRootSchema(json['schema'], 'schema', sink);
    final mapSchema = json.containsKey('map_schema')
        ? _parseRootSchema(json['map_schema'], 'map_schema', sink)
        : null;
    final postProcess = _parsePostProcess(json['post_process'], schema, sink);
    if (schema != null) _checkDerivedCollisions(schema, postProcess, sink);
    final reduce = _parseReduce(json['reduce'], schema, sink);
    final examples = _parseExamples(json['examples'], schema, sink);

    final templateId = _requiredString(json, 'template_id', sink);
    if (templateId != null && !kTemplateIdPattern.hasMatch(templateId)) {
      sink.add('template_id', 'must match ${kTemplateIdPattern.pattern}');
    }
    final filenamePattern = _parseFilenamePattern(
      json['filename_pattern'],
      sink,
    );
    final defaultTarget = _parseRouting(json['routing'], sink);
    final review = json['review_before_export'];
    if (review != null && review is! bool) {
      sink.add('review_before_export', 'must be true or false');
    }

    if (!sink.isEmpty) return ProfileValidation(null, sink.issues);
    return ProfileValidation(
      Profile(
        id: id!,
        version: version! as int,
        name: name!,
        description: description!,
        icon: icon as String?,
        tier: tier!,
        source: source,
        stt: stt ?? const ProfileStt(),
        classifyKeywords: keywords,
        instructions: instructions!,
        schema: schema!,
        mapSchema: mapSchema,
        reduce: reduce,
        postProcess: postProcess,
        examples: examples,
        templateId: templateId!,
        filenamePattern: filenamePattern,
        defaultTarget: defaultTarget,
        reviewBeforeExport: review as bool? ?? false,
        consentConfirmation: consent!,
      ),
      const [],
    );
  }

  /// Checks that every variable of [templateSource] exists in the render
  /// context of [profile] (schema fields + post-processor fields + `meta` +
  /// `transcript` + `has_*` helpers) and is used the way strict Mustache
  /// allows. Run on profile/template save, never first at export time.
  List<ProfileIssue> validateTemplate(
    Profile profile,
    String templateSource, {
    String name = 'template',
  }) =>
      checkTemplateVariables(templateSource, rootShapeFor(profile), name: name);

  String? _requiredString(
    Map<String, Object?> json,
    String key,
    IssueSink sink,
  ) {
    final value = json[key];
    if (value == null) {
      sink.add(key, 'is required');
      return null;
    }
    if (value is! String || value.trim().isEmpty) {
      sink.add(key, 'must be non-empty text');
      return null;
    }
    return value;
  }

  T? _enum<T extends Enum>(
    Map<String, Object?> json,
    String key,
    List<T> values,
    IssueSink sink,
  ) {
    final allowed = values.map((v) => v.name).join(' | ');
    final value = json[key];
    if (value == null) {
      sink.add(key, 'is required ($allowed)');
      return null;
    }
    for (final v in values) {
      if (v.name == value) return v;
    }
    sink.add(key, 'must be one of $allowed');
    return null;
  }

  ProfileStt? _parseStt(Object? raw, IssueSink sink) {
    if (raw == null) return null;
    if (raw is! Map<String, Object?>) {
      sink.add('stt', 'must be a map (vocabulary, diarization, num_speakers)');
      return null;
    }
    for (final key in raw.keys) {
      if (!const {'vocabulary', 'diarization', 'num_speakers'}.contains(key)) {
        sink.add(
          'stt.$key',
          'unknown key (allowed: vocabulary, diarization, num_speakers)',
        );
      }
    }
    final vocabulary = _stringList(raw['vocabulary'], 'stt.vocabulary', sink);
    final joined = vocabulary.join(', ').length;
    if (joined > ProfileLimits.maxVocabularyChars) {
      sink.add(
        'stt.vocabulary',
        'joins to $joined chars, max ${ProfileLimits.maxVocabularyChars} '
            "(Whisper's initial prompt is short)",
      );
    }
    final diarization = raw['diarization'];
    if (diarization != null && diarization is! bool) {
      sink.add('stt.diarization', 'must be true or false');
    }
    final speakers = raw['num_speakers'];
    int? numSpeakers;
    if (speakers is int &&
        speakers >= 1 &&
        speakers <= ProfileLimits.maxSpeakers) {
      numSpeakers = speakers;
    } else if (speakers != null && speakers != 'auto') {
      sink.add(
        'stt.num_speakers',
        'must be "auto" or an integer 1-${ProfileLimits.maxSpeakers}',
      );
    }
    return ProfileStt(
      vocabulary: vocabulary,
      diarization: diarization is bool ? diarization : null,
      numSpeakers: numSpeakers,
    );
  }

  List<String> _parseClassify(Object? raw, IssueSink sink) {
    if (raw == null) return const [];
    if (raw is! Map<String, Object?>) {
      sink.add('classify', 'must be a map with "keywords"');
      return const [];
    }
    for (final key in raw.keys) {
      if (key != 'keywords') {
        sink.add('classify.$key', 'unknown key (allowed: keywords)');
      }
    }
    final keywords = _stringList(raw['keywords'], 'classify.keywords', sink);
    if (keywords.length > ProfileLimits.maxKeywords) {
      sink.add(
        'classify.keywords',
        'has ${keywords.length} entries, max ${ProfileLimits.maxKeywords}',
      );
    }
    if (keywords.any((k) => k.length > ProfileLimits.maxKeywordLength)) {
      sink.add(
        'classify.keywords',
        'entries must be at most ${ProfileLimits.maxKeywordLength} chars',
      );
    }
    return keywords;
  }

  List<String> _stringList(Object? raw, String path, IssueSink sink) {
    if (raw == null) return const [];
    if (raw is! List<Object?> ||
        raw.any((e) => e is! String || e.trim().isEmpty)) {
      sink.add(path, 'must be a list of non-empty strings');
      return const [];
    }
    return List.unmodifiable(raw.cast<String>());
  }

  ObjectSchema? _parseRootSchema(Object? raw, String path, IssueSink sink) {
    if (raw == null) {
      sink.add(path, 'is required (a JSON Schema with root type: object)');
      return null;
    }
    final node = parseSchemaNode(raw, path, sink);
    if (node == null) return null;
    if (node is! ObjectSchema || node.nullable) {
      sink.add(path, 'root must be "type: object" (not nullable)');
      return null;
    }
    return node;
  }

  List<PostProcessor> _parsePostProcess(
    Object? raw,
    ObjectSchema? schema,
    IssueSink sink,
  ) {
    if (raw == null) return const [];
    final known = PostProcessor.values.map((p) => p.wireName).join(', ');
    if (raw is! List<Object?>) {
      sink.add('post_process', 'must be a list of names ($known)');
      return const [];
    }
    final out = <PostProcessor>[];
    for (var i = 0; i < raw.length; i++) {
      final path = 'post_process[$i]';
      final entry = raw[i];
      final processor = entry is String
          ? PostProcessor.fromWireName(entry)
          : null;
      if (processor == null) {
        sink.add(path, 'unknown post-processor "$entry" (known: $known)');
        continue;
      }
      if (out.contains(processor)) {
        sink.add(path, '"${processor.wireName}" is listed twice');
        continue;
      }
      out.add(processor);
      if (schema != null) {
        final problem = postProcessorRequirement(processor, schema);
        if (problem != null) sink.add(path, '${processor.wireName} $problem');
      }
    }
    return List.unmodifiable(out);
  }

  void _checkDerivedCollisions(
    ObjectSchema schema,
    List<PostProcessor> processors,
    IssueSink sink,
  ) {
    final set = processors.toSet();
    void walk(SchemaNode node, String path, {required bool isRoot}) {
      switch (node) {
        case ObjectSchema(:final properties):
          final derived = derivedFields(node, set, isRoot: isRoot);
          for (final name in derived.keys) {
            if (properties.containsKey(name) && name != kWarrantyExpiryField) {
              sink.add(
                joinPath(path, name),
                'collides with the field the post-processor adds; rename it',
              );
            }
          }
          for (final e in properties.entries) {
            walk(e.value, joinPath(path, e.key), isRoot: false);
          }
        case ArraySchema(:final items):
          walk(items, itemsPath(path), isRoot: false);
        default:
          break;
      }
    }

    walk(schema, 'schema', isRoot: true);
  }

  Map<String, ReduceStrategy> _parseReduce(
    Object? raw,
    ObjectSchema? schema,
    IssueSink sink,
  ) {
    if (raw == null) return const {};
    if (raw is! Map<String, Object?>) {
      sink.add('reduce', 'must map top-level fields to strategies');
      return const {};
    }
    final known = ReduceStrategy.values.map((s) => s.wireName).join(', ');
    final out = <String, ReduceStrategy>{};
    for (final entry in raw.entries) {
      final path = 'reduce.${entry.key}';
      final strategy = entry.value is String
          ? ReduceStrategy.fromWireName(entry.value! as String)
          : null;
      if (strategy == null) {
        sink.add(path, 'unknown strategy (known: $known)');
        continue;
      }
      if (schema == null) continue;
      final field = schema.properties[entry.key];
      if (field == null) {
        sink.add(path, 'is not a top-level schema field');
        continue;
      }
      final fits = switch (strategy) {
        ReduceStrategy.unionDedupe => field is ArraySchema,
        ReduceStrategy.llmSummarize =>
          field is StringSchema && field.enumValues == null,
        ReduceStrategy.max ||
        ReduceStrategy.min => field is NumberSchema || field is StringSchema,
        ReduceStrategy.firstNonNull => field is! ArraySchema,
      };
      if (!fits) {
        sink.add(
          path,
          '${strategy.wireName} does not fit a ${field.type.name} field '
          '(lists: union_dedupe; prose strings: llm_summarize; '
          'scalars/objects: first_non_null, max, min)',
        );
        continue;
      }
      out[entry.key] = strategy;
    }
    return Map.unmodifiable(out);
  }

  List<ProfileExample> _parseExamples(
    Object? raw,
    ObjectSchema? schema,
    IssueSink sink,
  ) {
    if (raw == null) return const [];
    if (raw is! List<Object?>) {
      sink.add('examples', 'must be a list of {transcript, output}');
      return const [];
    }
    if (raw.length > ProfileLimits.maxExamples) {
      sink.add(
        'examples',
        'has ${raw.length} examples, max ${ProfileLimits.maxExamples} '
            '(they are trimmed first when the prompt is over budget)',
      );
    }
    final out = <ProfileExample>[];
    for (var i = 0; i < raw.length; i++) {
      final path = 'examples[$i]';
      final example = raw[i];
      if (example is! Map<String, Object?>) {
        sink.add(path, 'must be a map with transcript and output');
        continue;
      }
      for (final key in example.keys) {
        if (key != 'transcript' && key != 'output') {
          sink.add('$path.$key', 'unknown key (allowed: transcript, output)');
        }
      }
      final transcript = example['transcript'];
      if (transcript is! String || transcript.trim().isEmpty) {
        sink.add('$path.transcript', 'must be non-empty text');
      } else if (transcript.length > ProfileLimits.maxExampleTranscript) {
        sink.add(
          '$path.transcript',
          'is ${transcript.length} chars, max '
              '${ProfileLimits.maxExampleTranscript}',
        );
      }
      final output = example['output'];
      if (output is! Map<String, Object?>) {
        sink.add('$path.output', 'must be an object matching the schema');
        continue;
      }
      if (schema != null) {
        validateInstance(schema, output, '$path.output', sink);
      }
      if (transcript is String) {
        out.add(ProfileExample(transcript: transcript, output: output));
      }
    }
    return List.unmodifiable(out);
  }

  String? _parseFilenamePattern(Object? raw, IssueSink sink) {
    if (raw == null) return null;
    const path = 'filename_pattern';
    if (raw is! String || raw.trim().isEmpty) {
      sink.add(path, 'must be non-empty text');
      return null;
    }
    if (!raw.endsWith('.md')) sink.add(path, 'must end with ".md"');
    if (raw.startsWith('/') || raw.split('/').any((s) => s == '..')) {
      sink.add(path, 'must be relative and must not contain ".." segments');
    }
    for (final match in RegExp(r'\{\{([^}]*)\}\}').allMatches(raw)) {
      final token = match.group(1)!.trim();
      if (token.startsWith('date:')) {
        if (!_dateTokenFormat.hasMatch(token.substring(5))) {
          sink.add(
            path,
            'date token "{{$token}}" may only use YYYY MM DD HH mm ss and '
            '- _ . separators',
          );
        }
      } else if (!kFilenameTokens.contains(token)) {
        sink.add(
          path,
          'unknown token "{{$token}}" (known: date:FMT, '
          '${kFilenameTokens.join(', ')})',
        );
      }
    }
    return raw;
  }

  String? _parseRouting(Object? raw, IssueSink sink) {
    if (raw == null) return null;
    if (raw is! Map<String, Object?>) {
      sink.add('routing', 'must be a map with "default_target"');
      return null;
    }
    for (final key in raw.keys) {
      if (key != 'default_target') {
        sink.add('routing.$key', 'unknown key (allowed: default_target)');
      }
    }
    final target = raw['default_target'];
    if (target == null) return null;
    if (target is! String || target.trim().isEmpty) {
      sink.add('routing.default_target', 'must be a target id or "ask"');
      return null;
    }
    return target;
  }
}
