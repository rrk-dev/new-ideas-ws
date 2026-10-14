import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/repositories/profiles_repository.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/clock.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/features/extraction/domain/output_schema_validator.dart';
import 'package:vaultvoice/features/profiles/data/profile_registry.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/domain/profile_draft.dart';
import 'package:vaultvoice/features/profiles/domain/prompt_builder.dart';
import 'package:vaultvoice/features/profiles/domain/render_context.dart';
import 'package:vaultvoice/features/templates/domain/note_context.dart';
import 'package:vaultvoice/features/templates/domain/template_engine.dart';
import 'package:vaultvoice/features/templates/domain/template_generator.dart';

/// Default filename pattern of a generated custom-profile template.
const String kCustomFilenamePattern = '{{date:YYYY-MM-DD}}-{{slug}}.md';

/// Custom profiles (PRF-07): save a [ProfileDraft] through the
/// [ProfileRegistry] (validation, version bump, grammar), bind a template
/// generated from the schema (EXP-01 generic generator; editable later in
/// EXP-07), duplicate built-ins into drafts, delete.
///
/// Gating: creating and editing need `Feature.customProfiles` ([canEdit],
/// from LIC-01's `featureProvider`). Without it (Free, or Pro expired)
/// existing custom profiles stay usable and visible but read-only — never
/// deleted.
class CustomProfileService {
  CustomProfileService({
    required this.registry,
    required this.dao,
    required this.canEdit,
    this.clock = const SystemClock(),
  });

  final ProfileRegistry registry;
  final ProfilesRepository dao;
  final bool Function() canEdit;
  final Clock clock;

  static const _proRequired = ProfileReadOnlyFailure(
    'custom profiles need Pro',
  );

  /// Ids in use (built-in, user, enterprise).
  Future<Set<String>> takenIds() async => {
    ...registry.builtins.ids,
    for (final p in await registry.watchAll().first) p.id,
  };

  /// A new editable draft copied from profile [id] (any source): new id
  /// `<id>-copy-N`, version 1, its own generated template.
  Future<Result<ProfileDraft>> duplicateAsDraft(
    String id, {
    required String copyName,
  }) async {
    if (!canEdit()) return const Err(_proRequired);
    final original = await registry.get(id);
    if (original case Err(:final failure)) return Err(failure);
    final draft = ProfileDraft.fromProfile(original.valueOrNull!);
    return Ok(
      ProfileDraft(
        id: nextCopyId(id, await takenIds()),
        name: copyName,
        description: draft.description,
        instructions: draft.instructions,
        fields: draft.fields,
        examples: draft.examples,
        diarization: draft.diarization,
        defaultTarget: draft.defaultTarget,
      ),
    );
  }

  /// Validates and stores [draft]; a new draft (empty id) gets an id from
  /// its name. The bound template is generated when it does not exist yet
  /// or when [regenerateTemplate] is set (e.g. after field changes).
  Future<Result<Profile>> save(
    ProfileDraft draft, {
    bool regenerateTemplate = false,
  }) async {
    if (!canEdit()) return const Err(_proRequired);
    final issues = draft.check();
    if (issues.isNotEmpty) {
      return Err(ProfileValidationFailure([for (final i in issues) '$i']));
    }
    var d = draft;
    if (d.id.isEmpty) {
      d = d.copyWith(id: profileIdFrom(d.name, await takenIds()));
    }
    final saved = await registry.save(d.toDefinition());
    if (saved case Err(:final failure)) return Err(failure);
    final profile = saved.valueOrNull!;
    final existing = await dao.getTemplate(profile.templateId);
    if (existing is Err || regenerateTemplate) {
      final stored = await dao.upsertTemplate(
        TemplatesCompanion.insert(
          id: profile.templateId,
          profileId: Value(profile.id),
          body: generateTemplate(profile),
          filenamePattern: kCustomFilenamePattern,
          updatedAt: clock.now(),
        ),
      );
      if (stored case Err(:final failure)) return Err(failure);
    }
    return Ok(profile);
  }

  /// Deletes custom profile [id] and its generated template.
  Future<Result<void>> delete(String id) async {
    if (!canEdit()) return const Err(_proRequired);
    final profile = await registry.get(id);
    final deleted = await registry.delete(id);
    if (deleted case Err()) return deleted;
    if (profile case Ok(:final value)
        when value.templateId == defaultTemplateIdFor(id)) {
      await dao.deleteTemplate(value.templateId);
    }
    return const Ok(null);
  }
}

/// Output of [ProfilePreview.run]: the JSON the model produced and the
/// Markdown note it renders to.
final class PreviewResult {
  const PreviewResult({
    required this.json,
    required this.markdown,
    required this.valid,
    this.issues = const [],
  });

  /// Pretty-printed model output (or the raw text when it is not JSON).
  final String json;
  final String markdown;
  final bool valid;
  final List<String> issues;
}

/// "Test on a recording" (PRF-07): runs [draft] on a chosen transcript and
/// renders the result with the draft's generated template.
///
/// The preview sends the PRF-02 system and user messages through
/// [LlmEngine] (which applies the model's chat template) without few-shot
/// examples; the exact-budget `BuiltPrompt` path needs a tokenizer from the
/// loaded model (follow-up for the extraction wiring).
class ProfilePreview {
  ProfilePreview({
    required this.llm,
    required this.grammarFor,
    this.validator = const OutputSchemaValidator(),
    this.engine = const MarkdownTemplateEngine(),
    this.appVersion = '',
  });

  final LlmEngine llm;
  final Future<Result<String>> Function(Profile profile) grammarFor;
  final OutputSchemaValidator validator;
  final MarkdownTemplateEngine engine;
  final String appVersion;

  /// Transcripts longer than this are cut (preview only; ≈ 2.5k tokens).
  static const int maxTranscriptChars = 10000;

  Future<Result<PreviewResult>> run(
    ProfileDraft draft, {
    required PromptInput Function(Profile profile) input,
    CancelToken? cancel,
  }) async {
    final d = draft.id.isEmpty ? draft.copyWith(id: 'preview') : draft;
    final validation = validateDraft(d);
    final profile = validation.profile;
    if (profile == null) {
      return Err(
        ProfileValidationFailure([for (final i in validation.issues) '$i']),
      );
    }
    final grammar = await grammarFor(profile);
    if (grammar case Err(:final failure)) return Err(failure);
    final full = input(profile);
    final builder = PromptBuilder(_NoTemplate.instance);
    var transcript = builder.transcriptLines(full.segments, full.metadata);
    if (transcript.length > maxTranscriptChars) {
      transcript = transcript.substring(0, maxTranscriptChars);
    }
    final user = [
      builder.metadataBlock(full.metadata),
      '<transcript>',
      transcript,
      '</transcript>',
      'Return one JSON object with the keys '
          '${profile.schema.properties.keys.join(', ')}. Return the JSON now.',
    ].join('\n');
    final out = await llm.generate(
      LlmRequest(
        systemPrompt: builder.systemMessage(profile, profile.schema),
        prompt: user,
        grammar: grammar.valueOrNull,
        sampling: const LlmSampling(preset: LlmPreset.deterministic),
      ),
      cancel: cancel,
    );
    if (out case Err(:final failure)) return Err(failure);
    final text = out.valueOrNull!;
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      return Ok(
        PreviewResult(
          json: text,
          markdown: '',
          valid: false,
          issues: const [r'$: not valid JSON'],
        ),
      );
    }
    final issues = validator.validate(decoded, profile.schema.toJson());
    final data = decoded is Map<String, Object?>
        ? decoded
        : const <String, Object?>{};
    return Ok(
      PreviewResult(
        json: const JsonEncoder.withIndent('  ').convert(decoded),
        markdown: renderPreview(profile, data, full),
        valid: issues.isEmpty,
        issues: issues,
      ),
    );
  }

  /// The note [data] renders to with [profile]'s generated template.
  String renderPreview(
    Profile profile,
    Map<String, Object?> data,
    PromptInput input,
  ) {
    final compiled = engine.compile(generateTemplate(profile));
    if (compiled case Err()) return '';
    final m = input.metadata;
    final context = buildRenderContext(
      profile: profile,
      data: data,
      meta: buildNoteMeta(
        recordingId: 'preview',
        createdAt: m.recordedAt,
        durationMs: m.duration.inMilliseconds,
        profileId: profile.id,
        profileName: profile.name,
        appVersion: appVersion,
        speakers: [for (final s in m.speakers) (label: s.label, name: s.name)],
      ),
      transcript: buildNoteTranscript([
        for (final s in input.segments)
          (
            startMs: s.start.inMilliseconds,
            speaker: m.displayName(s.speaker),
            text: s.text,
          ),
      ]),
    );
    return engine.render(compiled.valueOrNull!, context).markdown;
  }
}

/// The preview only uses the builder's text helpers, never templating.
final class _NoTemplate implements PromptTokenizer {
  const _NoTemplate();

  static const instance = _NoTemplate();

  @override
  String applyChatTemplate(List<ChatMessage> messages) =>
      throw UnsupportedError('preview does not template');

  @override
  int countTokens(String text) => 0;
}
