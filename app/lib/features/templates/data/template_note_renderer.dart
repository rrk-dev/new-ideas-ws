import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/pipeline/data/steps/render_write_steps.dart';
import 'package:vaultvoice/features/profiles/domain/builtin_profiles.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/domain/render_context.dart';
import 'package:vaultvoice/features/templates/domain/builtin_templates.dart';
import 'package:vaultvoice/features/templates/domain/note_context.dart';
import 'package:vaultvoice/features/templates/domain/template_engine.dart';
import 'package:vaultvoice/features/templates/domain/template_generator.dart';
import 'package:vaultvoice/features/templates/domain/template_lambdas.dart';

/// Renders a pipeline [NoteInput] with the profile's Mustache template
/// (EXP-01). An instance is a `NoteRenderer` (`call`), the seam FND-05's
/// `RenderStep` takes; it is synchronous, so everything it needs (parsed
/// built-ins, user profiles/templates) is loaded before construction.
///
/// Template choice: the user template [templateOverrides] maps to the
/// profile id, else the profile's `template_id` (user template or
/// built-in), else a template generated from the schema. Invalid
/// extraction or unknown profile → `summary-only`.
class TemplateNoteRenderer {
  TemplateNoteRenderer({
    required this.profiles,
    required this.templates,
    required this.appVersion,
    this.userProfiles = const {},
    this.userTemplates = const {},
    this.templateOverrides = const {},
    this.device,
    this.engine = const MarkdownTemplateEngine(),
    this.onWarnings,
  });

  final BuiltinProfiles profiles;
  final BuiltinTemplates templates;
  final String appVersion;

  /// User / enterprise profiles by id.
  final Map<String, Profile> userProfiles;

  /// User template sources by template id.
  final Map<String, String> userTemplates;

  /// Profile id → template id chosen by the user.
  final Map<String, String> templateOverrides;
  final String? device;
  final MarkdownTemplateEngine engine;

  /// Receives content-free render warnings (for the export log).
  final void Function(List<String> warnings)? onWarnings;

  final Map<String, CompiledTemplate> _compiled = {};

  /// `NoteRenderer` entry point.
  String call(NoteInput input) => renderNote(input).markdown;

  RenderedNote renderNote(
    NoteInput input, {
    LambdaOptions options = const LambdaOptions(),
  }) {
    final ext = input.extraction;
    final profile = userProfiles[ext.profileId] ?? profiles[ext.profileId];
    final meta = _meta(input, profile);
    final transcript = buildNoteTranscript([
      for (final s in input.segments)
        (
          startMs: s.startMs,
          speaker: s.speaker == null
              ? null
              : input.speakerNames[s.speaker] ?? s.speaker,
          text: s.body,
        ),
    ]);
    final warnings = <String>[];
    RenderedNote? note;
    if (profile != null && ext.valid) {
      final template = _templateFor(profile, warnings);
      final context = buildRenderContext(
        profile: profile,
        data: ext.json,
        meta: meta,
        transcript: transcript,
      );
      note = engine.render(template, context, options: options);
      warnings.addAll(note.warnings);
      if (note.markdown.isEmpty) note = null;
    }
    if (note == null) {
      final fallback = engine.render(
        templates.summaryOnly,
        normalizeContext(
          kSummaryOnlyRootShape,
          data: {'title': ext.json['title'], 'summary': ext.json['summary']},
          meta: meta,
          transcript: transcript,
        ),
        options: options,
      );
      warnings.addAll(fallback.warnings);
      note = fallback;
    }
    final result = RenderedNote(note.markdown, warnings: warnings);
    if (result.hasWarnings) onWarnings?.call(result.warnings);
    return result;
  }

  CompiledTemplate _templateFor(Profile profile, List<String> warnings) {
    final id = templateOverrides[profile.id] ?? profile.templateId;
    if (userTemplates[id] case final source?) {
      final cached = _compiled[id];
      if (cached != null && cached.source == source) return cached;
      switch (engine.compile(source, name: id)) {
        case Ok(:final value):
          return _compiled[id] = value;
        case Err(:final failure):
          warnings.add(failure.message);
      }
    }
    if (templates[id] case final builtin?) return builtin;
    final generatedId = 'generated:${profile.id}@${profile.version}';
    return _compiled.putIfAbsent(generatedId, () {
      final compiled = engine.compile(
        generateTemplate(profile),
        name: generatedId,
      );
      // The generator's output is tested to parse for every schema shape.
      return compiled.valueOrNull!;
    });
  }

  Map<String, Object?> _meta(NoteInput input, Profile? profile) {
    final r = input.recording;
    final speakers = <String>{
      for (final s in input.segments)
        if (s.speaker case final label? when label.isNotEmpty) label,
    };
    return buildNoteMeta(
      recordingId: r.id,
      title: r.title.isEmpty ? null : r.title,
      createdAt: r.createdAt.toLocal(),
      durationMs: r.durationMs,
      profileId: input.extraction.profileId,
      profileName: profile?.name ?? input.extraction.profileId,
      speakers: [
        for (final s in speakers) (label: s, name: input.speakerNames[s]),
      ],
      tags: r.tags,
      llmModel: input.extraction.modelId,
      appVersion: appVersion,
      device: device,
      consentAt: r.consentConfirmedAt?.toLocal(),
    );
  }
}
