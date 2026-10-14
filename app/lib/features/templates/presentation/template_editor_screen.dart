import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/handlebars.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/routing/app_routes.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/core/widgets/status_message.dart';
import 'package:vaultvoice/features/export/domain/filename_pattern.dart';
import 'package:vaultvoice/features/licensing/data/licensing_providers.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/licensing/domain/paywall.dart';
import 'package:vaultvoice/features/licensing/presentation/feature_gate.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/domain/profile_issue.dart';
import 'package:vaultvoice/features/profiles/domain/render_context.dart';
import 'package:vaultvoice/features/settings/domain/setting_definitions.dart';
import 'package:vaultvoice/features/settings/presentation/setting_texts.dart';
import 'package:vaultvoice/features/templates/data/template_editor_providers.dart';
import 'package:vaultvoice/features/templates/data/template_store.dart';
import 'package:vaultvoice/features/templates/domain/builtin_templates.dart';
import 'package:vaultvoice/features/templates/domain/template_editing.dart';
import 'package:vaultvoice/features/templates/presentation/templates_screen.dart'
    show flavorLabel;

/// Typing pause after which the preview re-renders. The AC is "preview
/// updates < 200 ms after typing stops": debounce + render (a few ms for
/// the built-in templates) stays below it.
const Duration kPreviewDebounce = Duration(milliseconds: 150);

/// Edits one template (Settings → Templates → template, EXP-07). Built-in
/// templates open read-only with "Duplicate"; custom templates are
/// editable with `Feature.customTemplates` (read-only after a downgrade).
class TemplateEditorScreen extends ConsumerWidget {
  const TemplateEditorScreen({required this.templateId, super.key});

  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final builtins = ref.watch(builtinTemplateSourcesProvider);
    final custom = ref.watch(customTemplatesProvider);
    final profiles = ref.watch(editorProfilesProvider);
    Widget simple(Widget body) => Scaffold(
      appBar: AppBar(title: Text(templateId)),
      body: body,
    );
    if (builtins.isLoading || custom.isLoading || profiles.isLoading) {
      return simple(
        Center(
          child: CircularProgressIndicator(semanticsLabel: l.commonLoading),
        ),
      );
    }
    if (builtins.hasError || custom.hasError || profiles.hasError) {
      return simple(
        StatusMessage(
          icon: Icons.error_outline,
          message: l.templatesLoadFailed,
        ),
      );
    }
    final info = kBuiltinTemplates.where((t) => t.id == templateId).firstOrNull;
    final mine = custom.value!.where((t) => t.id == templateId).firstOrNull;
    final source = info != null ? builtins.value![info.id] : mine?.body;
    if (source == null) {
      return simple(
        StatusMessage(icon: Icons.search_off, message: l.templateNotFound),
      );
    }
    final profileId = info?.profileId ?? mine?.profileId ?? 'meeting';
    final all = profiles.value!;
    final profile =
        all.where((p) => p.id == profileId).firstOrNull ?? all.first;
    return _TemplateEditor(
      key: ValueKey('template-editor-$templateId'),
      templateId: templateId,
      builtin: info,
      custom: mine,
      source: source,
      profile: profile,
      builtinSources: builtins.value!,
      takenIds: {
        for (final t in kBuiltinTemplates) t.id,
        for (final t in custom.value!) t.id,
      },
    );
  }
}

class _TemplateEditor extends ConsumerStatefulWidget {
  const _TemplateEditor({
    required this.templateId,
    required this.builtin,
    required this.custom,
    required this.source,
    required this.profile,
    required this.builtinSources,
    required this.takenIds,
    super.key,
  });

  final String templateId;
  final BuiltinTemplateInfo? builtin;
  final CustomTemplate? custom;
  final String source;
  final Profile profile;
  final Map<String, String> builtinSources;
  final Set<String> takenIds;

  @override
  ConsumerState<_TemplateEditor> createState() => _TemplateEditorState();
}

enum _PreviewMode { raw, rendered }

class _TemplateEditorState extends ConsumerState<_TemplateEditor> {
  late final CodeLineEditingController _code =
      CodeLineEditingController.fromText(widget.source);
  late final TextEditingController _pattern = TextEditingController(
    text: widget.custom?.filenamePattern ?? kDefaultFilenamePattern,
  );
  late final List<TemplateCompletion> _completions = templateCompletions(
    rootShapeFor(widget.profile),
  );
  late TemplatePreview _preview;
  String _rendered = '';
  Timer? _debounce;
  _PreviewMode _mode = _PreviewMode.raw;
  PreviewRecording? _data;
  bool _saving = false;
  String? _patternError;

  bool get _isBuiltin => widget.builtin != null;

  @override
  void initState() {
    super.initState();
    _render();
    _code.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _code
      ..removeListener(_onChanged)
      ..dispose();
    _pattern.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (_code.text == _rendered) return; // selection-only change
    _debounce?.cancel();
    _debounce = Timer(kPreviewDebounce, () {
      if (mounted) setState(_render);
    });
  }

  void _render() {
    _rendered = _code.text;
    _preview = previewTemplate(
      _rendered,
      profile: widget.profile,
      data: _data?.data ?? sampleDataFor(widget.profile),
      name: widget.templateId,
    );
  }

  List<ProfileIssue> get _issues =>
      // Built-ins are tested assets; `summary-only` has its own shape.
      _isBuiltin ? const [] : _preview.issues;

  Set<int> get _errorLines => {
    for (final i in _issues)
      if (issuePosition(i) case final p?) p.line,
  };

  Future<void> _save() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    _debounce?.cancel();
    setState(_render);
    final code =
        validateFilenamePattern(_pattern.text) ??
        (FilenamePattern.parse(_pattern.text.trim()).isOk ? null : 'invalid');
    setState(
      () => _patternError = code == null
          ? null
          : SettingTexts.patternError(l, code),
    );
    if (_issues.isNotEmpty || code != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l.templateFixIssues(_issues.length + (code == null ? 0 : 1)),
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final saved = await ref
        .read(templateStoreProvider)
        .save(
          widget.custom!.copyWith(
            body: _code.text,
            filenamePattern: _pattern.text.trim(),
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(saved.isOk ? l.templateSaved : l.templateSaveFailed),
      ),
    );
  }

  Future<void> _duplicate() async {
    final l = context.l10n;
    if (!await ensureFeature(
      ref,
      Feature.customTemplates,
      from: PaywallEntryPoint.templateEditor,
    )) {
      return;
    }
    if (!mounted) return;
    final name = await showDialog<String>(
      context: context,
      builder: (context) =>
          _DuplicateDialog(initial: '${widget.templateId}-copy'),
    );
    if (name == null || !mounted) return;
    final id = templateIdFrom(name, widget.takenIds);
    final saved = await ref
        .read(templateStoreProvider)
        .save(
          CustomTemplate(
            id: id,
            body: _code.text,
            filenamePattern:
                widget.custom?.filenamePattern ?? kDefaultFilenamePattern,
            profileId: widget.profile.id,
            baseId: widget.builtin?.id ?? widget.custom?.baseId,
          ),
        );
    if (!mounted) return;
    if (saved case Err()) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.templateSaveFailed)));
      return;
    }
    TemplateEditorRoute(templateId: id).pushReplacement(context);
  }

  void _reset() {
    final base = widget.custom?.baseId;
    final source = base == null ? null : widget.builtinSources[base];
    if (source == null) return;
    _code.text = source;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.templateResetDone)));
  }

  Future<void> _delete() async {
    final l = context.l10n;
    final navigator = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.templateDeleteTitle),
        content: Text(l.templateDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.templateDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(templateStoreProvider).delete(widget.templateId);
    if (mounted && navigator.canPop()) navigator.pop();
  }

  void _jumpTo(ProfileIssue issue) {
    final p = issuePosition(issue);
    if (p == null) return;
    final line = (p.line - 1).clamp(0, _code.codeLines.length - 1);
    _code.selection = CodeLineSelection.collapsed(
      index: line,
      offset: (p.column - 1).clamp(0, _code.codeLines[line].length),
    );
    _code.makeCursorVisible();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final editable =
        !_isBuiltin && ref.watch(featureProvider(Feature.customTemplates));
    final bindings = ref.watch(templateBindingsProvider).value ?? const {};
    final recordings =
        ref.watch(previewRecordingsProvider(widget.profile.id)).value ??
        const <PreviewRecording>[];
    final dark = theme.brightness == Brightness.dark;
    final errorLines = _errorLines;
    final issues = _issues;
    final forProfile = l.templateForProfile(widget.profile.name);
    final scope = widget.builtin?.profileId == null && _isBuiltin
        ? l.templateForAnyProfile
        : forProfile;

    final editor = SizedBox(
      height: 320,
      child: Semantics(
        label: l.templateSource,
        textField: true,
        child: CodeAutocomplete(
          viewBuilder: (context, notifier, onSelected) =>
              _CompletionList(notifier: notifier, onSelected: onSelected),
          promptsBuilder: _MustachePromptsBuilder(_completions),
          child: CodeEditor(
            controller: _code,
            readOnly: !editable,
            wordWrap: false,
            border: Border.all(color: theme.colorScheme.outline),
            style: CodeEditorStyle(
              fontSize: 14,
              fontFamily: 'monospace',
              codeTheme: CodeHighlightTheme(
                languages: {
                  'handlebars': CodeHighlightThemeMode(mode: langHandlebars),
                },
                theme: dark ? atomOneDarkTheme : atomOneLightTheme,
              ),
            ),
            indicatorBuilder: (context, editing, chunk, notifier) => Row(
              children: [
                DefaultCodeLineNumber(
                  controller: editing,
                  notifier: notifier,
                  // Lines with a problem are marked inline in the gutter.
                  customLineIndex2Text: (i) =>
                      errorLines.contains(i + 1) ? '⚠${i + 1}' : '${i + 1}',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final preview = switch ((_preview.markdown, _mode)) {
      (null, _) => Text(l.templatePreviewUnavailable),
      (final md?, _PreviewMode.raw) => SelectableText(
        md,
        key: const ValueKey('template-preview-raw'),
        style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
      ),
      (final md?, _PreviewMode.rendered) => MarkdownBody(
        key: const ValueKey('template-preview-rendered'),
        data: md,
        // No network: images are never fetched, only their alt text shown.
        imageBuilder: (uri, title, alt) =>
            Text(l.templateImageOmitted(alt ?? '')),
      ),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.templateId),
        actions: [
          if (editable)
            IconButton(
              key: const ValueKey('template-save'),
              tooltip: l.templateSave,
              icon: const Icon(Icons.save_outlined),
              onPressed: _saving ? null : _save,
            ),
          IconButton(
            key: const ValueKey('template-duplicate'),
            tooltip: l.templateDuplicate,
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: _duplicate,
          ),
          if (editable)
            PopupMenuButton<String>(
              key: const ValueKey('template-more'),
              tooltip: l.templateMore,
              onSelected: (v) => v == 'reset' ? _reset() : _delete(),
              itemBuilder: (context) => [
                if (widget.custom?.baseId != null)
                  PopupMenuItem(value: 'reset', child: Text(l.templateReset)),
                PopupMenuItem(value: 'delete', child: Text(l.templateDelete)),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (_isBuiltin)
            Text(l.templateReadOnly, key: const ValueKey('template-readonly'))
          else if (!editable)
            Text(l.templateLockedReadOnly),
          Text(switch (widget.builtin) {
            null => forProfile,
            final b => '${flavorLabel(context, b.flavor)} · $scope',
          }, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          editor,
          for (final i in issues)
            ListTile(
              key: ValueKey('template-issue-${i.path}'),
              dense: true,
              leading: Icon(
                Icons.error_outline,
                color: theme.colorScheme.error,
              ),
              title: Text(switch (issuePosition(i)) {
                final p? => l.templateIssueAt(p.line, p.column, i.message),
                null => i.message,
              }, style: TextStyle(color: theme.colorScheme.error)),
              onTap: () => _jumpTo(i),
            ),
          if (!_isBuiltin) ...[
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey('template-pattern'),
              controller: _pattern,
              readOnly: !editable,
              decoration: InputDecoration(
                labelText: l.templateFilename,
                errorText: _patternError,
                border: const OutlineInputBorder(),
              ),
            ),
            SwitchListTile(
              key: const ValueKey('template-bind'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.templateUseFor(widget.profile.name)),
              value: bindings[widget.profile.id] == widget.templateId,
              onChanged: editable
                  ? (on) => ref
                        .read(templateStoreProvider)
                        .bind(widget.profile.id, on ? widget.templateId : null)
                        .ignore()
                  : null,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(l.templatePreview, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            key: const ValueKey('template-preview-data'),
            initialValue: _data?.recordingId ?? '',
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l.templatePreviewData,
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(value: '', child: Text(l.templatePreviewSample)),
              for (final r in recordings)
                DropdownMenuItem(
                  value: r.recordingId,
                  child: Text(
                    r.title.isEmpty
                        ? MaterialLocalizations.of(context)
                              .formatMediumDate(r.createdAt)
                        : r.title,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (id) => setState(() {
              _data = recordings.where((r) => r.recordingId == id).firstOrNull;
              _render();
            }),
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<_PreviewMode>(
            key: const ValueKey('template-preview-mode'),
            segments: [
              ButtonSegment(
                value: _PreviewMode.raw,
                label: Text(l.templatePreviewRaw),
              ),
              ButtonSegment(
                value: _PreviewMode.rendered,
                label: Text(l.templatePreviewRendered),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.single),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: preview,
          ),
        ],
      ),
    );
  }
}

class _DuplicateDialog extends StatefulWidget {
  const _DuplicateDialog({required this.initial});

  final String initial;

  @override
  State<_DuplicateDialog> createState() => _DuplicateDialogState();
}

class _DuplicateDialogState extends State<_DuplicateDialog> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.templateDuplicateTitle),
      content: TextField(
        key: const ValueKey('template-duplicate-name'),
        controller: _name,
        autofocus: true,
        decoration: InputDecoration(labelText: l.templateDuplicateName),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_name.text),
          child: Text(l.templateDuplicateCreate),
        ),
      ],
    );
  }
}

/// A completion as a re_editor prompt (prefix match on the full path).
class _PathPrompt extends CodePrompt {
  _PathPrompt(this.completion) : super(word: completion.path);

  final TemplateCompletion completion;

  @override
  CodeAutocompleteResult get autocomplete =>
      CodeAutocompleteResult.fromWord(completion.path);

  @override
  bool match(String input) => true;
}

/// Offers variable paths while the cursor is inside an open `{{ … ` tag.
class _MustachePromptsBuilder implements CodeAutocompletePromptsBuilder {
  _MustachePromptsBuilder(this.all);

  final List<TemplateCompletion> all;

  @override
  CodeAutocompleteEditingValue? build(
    BuildContext context,
    CodeLine codeLine,
    CodeLineSelection selection,
  ) {
    final text = codeLine.text;
    final end = selection.extentOffset.clamp(0, text.length);
    final input = mustacheInput(text.substring(0, end));
    if (input == null || input.isEmpty) return null;
    final matches = matchCompletions(all, input);
    if (matches.isEmpty) return null;
    return CodeAutocompleteEditingValue(
      input: input,
      prompts: [for (final m in matches) _PathPrompt(m)],
      index: 0,
    );
  }
}

class _CompletionList extends StatelessWidget implements PreferredSizeWidget {
  const _CompletionList({required this.notifier, required this.onSelected});

  final ValueNotifier<CodeAutocompleteEditingValue> notifier;
  final ValueChanged<CodeAutocompleteResult> onSelected;

  @override
  Size get preferredSize => const Size(260, 200);

  @override
  Widget build(BuildContext context) => Material(
    elevation: 4,
    borderRadius: BorderRadius.circular(AppRadius.sm),
    child: ConstrainedBox(
      constraints: BoxConstraints.loose(preferredSize),
      child: ValueListenableBuilder(
        valueListenable: notifier,
        builder: (context, value, _) => ListView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          children: [
            for (final (i, p) in value.prompts.indexed)
              ListTile(
                dense: true,
                selected: i == value.index,
                title: Text(p.word, overflow: TextOverflow.ellipsis),
                onTap: () => onSelected(value.copyWith(index: i).autocomplete),
              ),
          ],
        ),
      ),
    ),
  );
}
