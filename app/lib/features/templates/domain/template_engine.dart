import 'package:mustache_template/mustache.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/profiles/domain/profile_issue.dart';
import 'package:vaultvoice/features/profiles/domain/render_context.dart';
import 'package:vaultvoice/features/profiles/domain/template_variables.dart';
import 'package:vaultvoice/features/templates/domain/markdown_sanitizer.dart';
import 'package:vaultvoice/features/templates/domain/template_lambdas.dart';

/// A parsed template (strict and lenient forms of the same source).
class CompiledTemplate {
  CompiledTemplate._(this.name, this.source, this._strict);

  final String name;
  final String source;
  final Template _strict;

  /// Lenient twin, built only when a strict render fails at export time.
  late final Template _lenient = Template(
    source,
    name: name,
    htmlEscapeValues: false,
    lenient: true,
  );
}

/// A rendered note plus content-free warnings for the export log.
class RenderedNote {
  const RenderedNote(this.markdown, {this.warnings = const []});

  final String markdown;

  /// `name:line:col: message` — template positions and variable names
  /// only, never values.
  final List<String> warnings;

  bool get hasWarnings => warnings.isNotEmpty;
}

final RegExp _isoDay = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final RegExp _fence = RegExp('^ {0,3}(`{3,}|~{3,})');

/// Mustache Markdown renderer (ADR-EXP-01): `mustache_template` with
/// `htmlEscapeValues: false, lenient: false`; safety comes from the
/// sanitized context ([InlineText]) and the lambdas.
class MarkdownTemplateEngine {
  const MarkdownTemplateEngine();

  /// Parses [source] in strict mode. Syntax errors (unclosed tags or
  /// sections, mismatched closing tags, invalid tag names) are returned as
  /// a [TemplateSyntaxFailure] with 1-based line and column.
  Result<CompiledTemplate> compile(String source, {String name = 'template'}) {
    try {
      final t = Template(
        source,
        name: name,
        htmlEscapeValues: false,
        // Strict lookups are the contract (ADR-EXP-01); keep it explicit.
        // ignore: avoid_redundant_argument_values
        lenient: false,
      );
      return Ok(CompiledTemplate._(name, source, t));
    } on TemplateException catch (e) {
      return Err(TemplateSyntaxFailure(name, e.line, e.column, e.message));
    }
  }

  /// Save-time validation of a template against a context [shape]: syntax
  /// (with line/column) plus PRF-01's strict variable check (unknown names,
  /// sections on scalars, …). Empty = the template cannot fail at export.
  List<ProfileIssue> validate(
    String source,
    MapShape shape, {
    String name = 'template',
  }) {
    final compiled = compile(source, name: name);
    if (compiled case Err(:final failure)) {
      final f = failure as TemplateSyntaxFailure;
      final detail = f.message.substring(f.message.indexOf(': ') + 2);
      return [ProfileIssue('$name:${f.line}:${f.column}', detail)];
    }
    return checkTemplateVariables(source, shape, name: name);
  }

  /// Renders [template] with a normalized [context] (PRF-01
  /// `buildRenderContext`). Strings are sanitized ([InlineText]); `meta.date`
  /// must be `YYYY-MM-DD` (it is unquoted in front-matter) or it is blanked.
  ///
  /// A strict-mode failure at export time (a template that skipped
  /// validation) does not lose the note: it re-renders leniently (missing
  /// values → empty) and reports the error in [RenderedNote.warnings].
  RenderedNote render(
    CompiledTemplate template,
    Map<String, Object?> context, {
    LambdaOptions options = const LambdaOptions(),
  }) {
    final warnings = <String>[];
    final values = _values(context, options, warnings);
    try {
      return RenderedNote(
        _finish(template._strict.renderString(values)),
        warnings: warnings,
      );
    } on TemplateException catch (e) {
      warnings.add('${template.name}:${e.line}:${e.column}: ${e.message}');
    }
    try {
      return RenderedNote(
        _finish(template._lenient.renderString(values)),
        warnings: warnings,
      );
    } on TemplateException catch (e) {
      warnings.add('${template.name}:${e.line}:${e.column}: ${e.message}');
      return RenderedNote('', warnings: warnings);
    }
  }

  Map<String, Object?> _values(
    Map<String, Object?> context,
    LambdaOptions options,
    List<String> warnings,
  ) {
    final wrapped = wrapContextValues(context)! as Map<String, Object?>;
    final meta = wrapped[ContextKeys.meta];
    if (meta is Map<String, Object?>) {
      final date = rawText(meta['date']);
      if (date != null && !_isoDay.hasMatch(date)) {
        warnings.add('context: meta.date is not YYYY-MM-DD; left empty');
        meta['date'] = null;
      }
    }
    // Lambdas live at the root; context keys win (Mustache lookup order).
    return {...buildLambdas(options), ...wrapped};
  }

  /// Normalizes line endings, trims trailing whitespace per line, collapses
  /// runs of blank lines (outside fenced code) and ends with exactly one
  /// newline.
  static String _finish(String s) {
    final lines = s.replaceAll('\r\n', '\n').split('\n');
    final out = <String>[];
    String? fence;
    for (final raw in lines) {
      final line = raw.trimRight();
      final marker = _fence.firstMatch(line)?.group(1);
      if (fence == null) {
        if (marker != null) fence = marker;
        if (line.isEmpty && (out.isEmpty || out.last.isEmpty)) continue;
      } else if (marker != null &&
          marker[0] == fence[0] &&
          marker.length >= fence.length &&
          line.trim() == marker) {
        fence = null;
      }
      out.add(line);
    }
    while (out.isNotEmpty && out.last.isEmpty) {
      out.removeLast();
    }
    return out.isEmpty ? '' : '${out.join('\n')}\n';
  }
}
