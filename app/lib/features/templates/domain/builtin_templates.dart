import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/templates/domain/template_engine.dart';

/// Output dialect of a template.
enum TemplateFlavor { obsidian, logseq, plain }

/// Metadata of a template shipped as an asset (`app/assets/templates/`).
class BuiltinTemplateInfo {
  const BuiltinTemplateInfo(this.id, {required this.flavor, this.profileId});

  final String id;
  final TemplateFlavor flavor;

  /// The built-in profile whose schema the template is written for; null
  /// for `summary-only`, which works for every profile.
  final String? profileId;

  String get assetPath => 'assets/templates/$id.mustache';
}

/// Id of the fallback template (invalid extraction / unknown profile).
const String kSummaryOnlyTemplateId = 'summary-only';

/// Every built-in template. A test asserts this equals the asset folder.
///
/// Built-in templates are read-only assets, like built-in profiles: they
/// are never stored as `templates` rows, so the FND-04 foreign key
/// `templates.profile_id → profiles.id` never has to reference a built-in
/// profile (ADR-EXP-01 → "Template storage").
const List<BuiltinTemplateInfo> kBuiltinTemplates = [
  BuiltinTemplateInfo(
    'meeting-default',
    flavor: TemplateFlavor.obsidian,
    profileId: 'meeting',
  ),
  BuiltinTemplateInfo(
    'meeting-logseq',
    flavor: TemplateFlavor.logseq,
    profileId: 'meeting',
  ),
  BuiltinTemplateInfo(
    'meeting-plain',
    flavor: TemplateFlavor.plain,
    profileId: 'meeting',
  ),
  BuiltinTemplateInfo(
    'warranty-default',
    flavor: TemplateFlavor.obsidian,
    profileId: 'warranty',
  ),
  BuiltinTemplateInfo(
    'warranty-logseq',
    flavor: TemplateFlavor.logseq,
    profileId: 'warranty',
  ),
  BuiltinTemplateInfo(
    'warranty-plain',
    flavor: TemplateFlavor.plain,
    profileId: 'warranty',
  ),
  BuiltinTemplateInfo(
    'engineering-default',
    flavor: TemplateFlavor.obsidian,
    profileId: 'engineering',
  ),
  BuiltinTemplateInfo(
    'engineering-logseq',
    flavor: TemplateFlavor.logseq,
    profileId: 'engineering',
  ),
  BuiltinTemplateInfo(
    'engineering-plain',
    flavor: TemplateFlavor.plain,
    profileId: 'engineering',
  ),
  BuiltinTemplateInfo(kSummaryOnlyTemplateId, flavor: TemplateFlavor.obsidian),
];

/// The built-in template of [profileId] in [flavor] (EXP-08 alternate
/// outputs), or null when the profile has none in that flavor.
BuiltinTemplateInfo? builtinVariant(String profileId, TemplateFlavor flavor) =>
    kBuiltinTemplates
        .where((t) => t.profileId == profileId && t.flavor == flavor)
        .firstOrNull;

/// Thrown when a shipped template does not parse — a build bug caught by
/// the asset tests.
class BuiltinTemplateException implements Exception {
  const BuiltinTemplateException(this.message);

  final String message;

  @override
  String toString() => 'BuiltinTemplateException: $message';
}

/// The parsed built-in templates, keyed by id.
class BuiltinTemplates {
  BuiltinTemplates._(this._byId);

  /// Compiles every template in [kBuiltinTemplates] from [sources]
  /// (asset path → template text). Throws [BuiltinTemplateException] when
  /// one is missing or does not parse.
  factory BuiltinTemplates.parse(
    Map<String, String> sources, {
    MarkdownTemplateEngine engine = const MarkdownTemplateEngine(),
  }) {
    final byId = <String, CompiledTemplate>{};
    for (final info in kBuiltinTemplates) {
      final source = sources[info.assetPath];
      if (source == null) {
        throw BuiltinTemplateException('missing ${info.assetPath}');
      }
      switch (engine.compile(source, name: info.id)) {
        case Ok(:final value):
          byId[info.id] = value;
        case Err(:final failure):
          throw BuiltinTemplateException(failure.message);
      }
    }
    return BuiltinTemplates._(Map.unmodifiable(byId));
  }

  final Map<String, CompiledTemplate> _byId;

  CompiledTemplate? operator [](String id) => _byId[id];

  CompiledTemplate get summaryOnly => _byId[kSummaryOnlyTemplateId]!;

  Set<String> get ids => _byId.keys.toSet();
}
