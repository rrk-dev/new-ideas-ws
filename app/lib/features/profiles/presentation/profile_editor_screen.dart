import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/widgets/status_message.dart';
import 'package:vaultvoice/features/profiles/data/custom_profile_providers.dart';
import 'package:vaultvoice/features/profiles/data/custom_profile_service.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/domain/profile_draft.dart';
import 'package:vaultvoice/features/profiles/presentation/profile_transfer_actions.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

/// Custom profile editor (PRF-07): field builder → JSON Schema (never shown),
/// instructions, optional examples, routing target, "Test on a recording".
/// [profileId] null = new profile. Built-in / managed profiles and custom
/// profiles without Pro open read-only.
class ProfileEditorScreen extends ConsumerWidget {
  const ProfileEditorScreen({this.profileId, super.key});

  final String? profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final id = profileId;
    final canEdit = ref.watch(canEditProfilesProvider);
    if (id == null) {
      return _Editor(
        key: const ValueKey('new'),
        initial: ProfileDraft.empty(),
        editable: canEdit,
        source: ProfileSource.user,
        isNew: true,
      );
    }
    final profile = ref.watch(profileByIdProvider(id));
    return switch (profile) {
      AsyncData(value: final p?) => _Editor(
        key: ValueKey('${p.id}@${p.version}'),
        initial: ProfileDraft.fromProfile(p),
        editable: canEdit && p.source == ProfileSource.user,
        source: p.source,
        isNew: false,
      ),
      AsyncData() || AsyncError() => Scaffold(
        appBar: AppBar(title: Text(l.profileEditorViewTitle)),
        body: StatusMessage(
          icon: Icons.error_outline,
          message: l.profileEditorNotFound,
        ),
      ),
      _ => Scaffold(appBar: AppBar(title: Text(l.profileEditorViewTitle))),
    };
  }
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({
    required this.initial,
    required this.editable,
    required this.source,
    required this.isNew,
    super.key,
  });

  final ProfileDraft initial;
  final bool editable;
  final ProfileSource source;
  final bool isNew;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  late ProfileDraft _draft = widget.initial;
  late final List<int> _fieldKeys = [
    for (var i = 0; i < widget.initial.fields.length; i++) i,
  ];
  late int _nextKey = _fieldKeys.length;
  bool _fieldsChanged = false;
  bool _saving = false;
  bool _showIssues = false;

  bool get _editable => widget.editable;

  void _update(ProfileDraft d, {bool fields = false}) => setState(() {
    _draft = d;
    _fieldsChanged |= fields;
  });

  void _setField(int i, FieldSpec f) {
    final list = [..._draft.fields]..[i] = f;
    _update(_draft.copyWith(fields: list), fields: true);
  }

  void _addField() {
    final n = _draft.fields.length + 1;
    setState(() {
      _fieldKeys.add(_nextKey++);
      _draft = _draft.copyWith(
        fields: [
          ..._draft.fields,
          FieldSpec(name: 'field_$n', kind: FieldKind.text),
        ],
      );
      _fieldsChanged = true;
    });
  }

  void _removeField(int i) => setState(() {
    _fieldKeys.removeAt(i);
    _draft = _draft.copyWith(fields: [..._draft.fields]..removeAt(i));
    _fieldsChanged = true;
  });

  Future<void> _save() async {
    final l = context.l10n;
    setState(() => _showIssues = true);
    if (_draft.check().isNotEmpty) return;
    setState(() => _saving = true);
    final service = await ref.read(customProfileServiceProvider.future);
    final result = await service.save(
      _draft,
      regenerateTemplate: _fieldsChanged,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    final messenger = ScaffoldMessenger.of(context);
    switch (result) {
      case Ok(:final value):
        messenger.showSnackBar(SnackBar(content: Text(l.profileEditorSaved)));
        if (widget.isNew) {
          context.go('/profiles/${value.id}');
        } else {
          _update(_draft.copyWith(version: value.version));
          _fieldsChanged = false;
        }
      case Err(:final failure):
        final reason = failure is ProfileValidationFailure
            ? failure.issues.join('; ')
            : failure.message;
        messenger.showSnackBar(
          SnackBar(content: Text(l.profileEditorSaveFailed(reason))),
        );
    }
  }

  Future<void> _delete() async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.profileEditorDeleteTitle),
        content: Text(l.profileEditorDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l.profileEditorCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.profileEditorDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final service = await ref.read(customProfileServiceProvider.future);
    final result = await service.delete(_draft.id);
    if (!mounted) return;
    if (result.isOk) context.go('/profiles');
  }

  Future<void> _test() async {
    final recordingId = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => const _RecordingPicker(),
    );
    if (recordingId == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _PreviewDialog(draft: _draft, recordingId: recordingId),
    );
  }

  String? _issueText(AppLocalizations l, DraftIssueKind k) => switch (k) {
    DraftIssueKind.nameMissing => l.profileEditorIssueName,
    DraftIssueKind.noFields => l.profileEditorIssueNoFields,
    DraftIssueKind.tooManyFields => l.profileEditorIssueTooManyFields,
    DraftIssueKind.fieldName => l.profileEditorIssueFieldName,
    DraftIssueKind.duplicateField => l.profileEditorIssueDuplicateField,
    DraftIssueKind.columns => l.profileEditorIssueColumns,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final issues = _showIssues ? _draft.check() : const <DraftIssue>[];
    String? issueFor(int? field, Set<DraftIssueKind> kinds) {
      for (final i in issues) {
        if (i.field == field && kinds.contains(i.kind)) {
          return _issueText(l, i.kind);
        }
      }
      return null;
    }

    final title = !_editable
        ? l.profileEditorViewTitle
        : (widget.isNew ? l.profileEditorNewTitle : l.profileEditorEditTitle);
    final targets =
        ref.watch(vaultTargetsProvider).value ?? const <VaultTargetInfo>[];
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (!widget.isNew)
            Builder(
              builder: (c) => IconButton(
                icon: const Icon(Icons.ios_share),
                tooltip: l.profileEditorExport,
                onPressed: () => exportProfileBundle(c, ref, _draft.id),
              ),
            ),
          if (_editable && !widget.isNew)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l.profileEditorDelete,
              onPressed: _delete,
            ),
          if (_editable)
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: l.profileEditorSave,
              onPressed: _saving ? null : _save,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (!_editable)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  widget.source == ProfileSource.user
                      ? l.profileEditorProBanner
                      : l.profileEditorReadOnlyBanner,
                ),
              ),
            ),
          TextFormField(
            initialValue: _draft.name,
            enabled: _editable,
            decoration: InputDecoration(
              labelText: l.profileEditorName,
              errorText: issueFor(null, {DraftIssueKind.nameMissing}),
            ),
            onChanged: (v) => _update(_draft.copyWith(name: v)),
          ),
          TextFormField(
            initialValue: _draft.description,
            enabled: _editable,
            decoration: InputDecoration(labelText: l.profileEditorDescription),
            onChanged: (v) => _update(_draft.copyWith(description: v)),
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: _draft.instructions,
            enabled: _editable,
            minLines: 3,
            maxLines: 8,
            maxLength: 1500,
            decoration: InputDecoration(
              labelText: l.profileEditorInstructions,
              hintText: l.profileEditorInstructionsHint,
            ),
            onChanged: (v) => _update(_draft.copyWith(instructions: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.profileEditorSpeakers),
            subtitle: Text(l.profileEditorSpeakersHint),
            value: _draft.diarization,
            onChanged: _editable
                ? (v) => _update(_draft.copyWith(diarization: v))
                : null,
          ),
          DropdownButtonFormField<String>(
            initialValue: _draft.defaultTarget ?? '',
            decoration: InputDecoration(labelText: l.profileEditorTarget),
            items: [
              DropdownMenuItem(
                value: '',
                child: Text(l.profileEditorTargetDefault),
              ),
              DropdownMenuItem(
                value: 'ask',
                child: Text(l.profileEditorTargetAsk),
              ),
              for (final t in targets)
                DropdownMenuItem(value: t.id, child: Text(t.name)),
              if (_draft.defaultTarget case final t?
                  when t != 'ask' && !targets.any((x) => x.id == t))
                DropdownMenuItem(value: t, child: Text(t)),
            ],
            onChanged: _editable
                ? (v) => _update(
                    v == null || v.isEmpty
                        ? _draft.copyWith(clearDefaultTarget: true)
                        : _draft.copyWith(defaultTarget: v),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(
              l.profileEditorFields,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (issueFor(null, {
                DraftIssueKind.noFields,
                DraftIssueKind.tooManyFields,
              })
              case final e?)
            Text(
              e,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          for (final (i, f) in _draft.fields.indexed)
            _FieldCard(
              key: ValueKey('field-${_fieldKeys[i]}'),
              field: f,
              editable: _editable,
              error: issueFor(i, {
                DraftIssueKind.fieldName,
                DraftIssueKind.duplicateField,
                DraftIssueKind.columns,
              }),
              onChanged: (nf) => _setField(i, nf),
              onRemove: () => _removeField(i),
            ),
          if (_editable)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addField,
                icon: const Icon(Icons.add),
                label: Text(l.profileEditorAddField),
              ),
            ),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(
              l.profileEditorExamples,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final (i, e) in _draft.examples.indexed)
            _ExampleCard(
              key: ValueKey('example-$i-${_draft.examples.length}'),
              example: e,
              fields: _draft.fields,
              editable: _editable,
              onChanged: (ne) => _update(
                _draft.copyWith(examples: [..._draft.examples]..[i] = ne),
              ),
              onRemove: () => _update(
                _draft.copyWith(examples: [..._draft.examples]..removeAt(i)),
              ),
            ),
          if (_editable && _draft.examples.length < 2)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _update(
                  _draft.copyWith(
                    examples: [
                      ..._draft.examples,
                      const ExampleDraft(transcript: ''),
                    ],
                  ),
                ),
                icon: const Icon(Icons.add),
                label: Text(l.profileEditorAddExample),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: _draft.fields.isEmpty ? null : _test,
            icon: const Icon(Icons.play_arrow),
            label: Text(l.profileEditorTest),
          ),
        ],
      ),
    );
  }
}

String kindLabel(AppLocalizations l, FieldKind k) => switch (k) {
  FieldKind.text => l.profileEditorKindText,
  FieldKind.longText => l.profileEditorKindLongText,
  FieldKind.textList => l.profileEditorKindTextList,
  FieldKind.date => l.profileEditorKindDate,
  FieldKind.number => l.profileEditorKindNumber,
  FieldKind.boolean => l.profileEditorKindBoolean,
  FieldKind.checkboxList => l.profileEditorKindCheckboxList,
  FieldKind.table => l.profileEditorKindTable,
  FieldKind.advanced => l.profileEditorKindAdvanced,
};

class _FieldCard extends StatelessWidget {
  const _FieldCard({
    required this.field,
    required this.editable,
    required this.onChanged,
    required this.onRemove,
    this.error,
    super.key,
  });

  final FieldSpec field;
  final bool editable;
  final String? error;
  final ValueChanged<FieldSpec> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final advanced = field.kind == FieldKind.advanced;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: field.name,
                    enabled: editable,
                    decoration: InputDecoration(
                      labelText: l.profileEditorFieldLabel,
                      errorText: error,
                    ),
                    onChanged: (v) =>
                        onChanged(field.copyWith(name: fieldNameFrom(v))),
                  ),
                ),
                if (editable)
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: l.profileEditorFieldRemove(field.name),
                    onPressed: onRemove,
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                l.profileEditorFieldKey(field.name),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (advanced)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(l.profileEditorFieldAdvanced),
              )
            else ...[
              DropdownButtonFormField<FieldKind>(
                initialValue: field.kind,
                decoration: InputDecoration(
                  labelText: l.profileEditorFieldType,
                ),
                items: [
                  for (final k in FieldKind.values)
                    if (k != FieldKind.advanced)
                      DropdownMenuItem(value: k, child: Text(kindLabel(l, k))),
                ],
                onChanged: editable
                    ? (k) => onChanged(field.copyWith(kind: k))
                    : null,
              ),
              if (field.kind == FieldKind.table)
                TextFormField(
                  initialValue: [for (final c in field.columns) c.name]
                      .join(', '),
                  enabled: editable,
                  decoration: InputDecoration(
                    labelText: l.profileEditorFieldColumns,
                  ),
                  onChanged: (v) => onChanged(
                    field.copyWith(
                      columns: [
                        for (final c in v.split(','))
                          if (c.trim().isNotEmpty)
                            ColumnSpec(name: fieldNameFrom(c)),
                      ],
                    ),
                  ),
                ),
            ],
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextFormField(
                initialValue: field.description,
                enabled: editable,
                maxLength: 300,
                decoration: InputDecoration(
                  labelText: l.profileEditorFieldDescription,
                ),
                onChanged: (v) => onChanged(field.copyWith(description: v)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExampleCard extends StatelessWidget {
  const _ExampleCard({
    required this.example,
    required this.fields,
    required this.editable,
    required this.onChanged,
    required this.onRemove,
    super.key,
  });

  final ExampleDraft example;
  final List<FieldSpec> fields;
  final bool editable;
  final ValueChanged<ExampleDraft> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: example.transcript,
                    enabled: editable,
                    minLines: 2,
                    maxLines: 6,
                    decoration: InputDecoration(
                      labelText: l.profileEditorExampleTranscript,
                    ),
                    onChanged: (v) => onChanged(
                      ExampleDraft(transcript: v, values: example.values),
                    ),
                  ),
                ),
                if (editable)
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: l.profileEditorExampleRemove,
                    onPressed: onRemove,
                  ),
              ],
            ),
            for (final f in fields)
              if (f.kind != FieldKind.advanced)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextFormField(
                    key: ValueKey('ex-${f.name}'),
                    initialValue: example.values[f.name] ?? '',
                    enabled: editable,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: l.profileEditorExampleValue(f.name),
                    ),
                    onChanged: (v) => onChanged(
                      ExampleDraft(
                        transcript: example.transcript,
                        values: {...example.values, f.name: v},
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _RecordingPicker extends ConsumerWidget {
  const _RecordingPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final recs =
        ref.watch(previewRecordingsProvider).value ??
        const <PreviewRecording>[];
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(title: Text(l.profileEditorTestPick)),
          if (recs.isEmpty) ListTile(title: Text(l.profileEditorTestNone)),
          for (final r in recs)
            ListTile(
              leading: const Icon(Icons.graphic_eq),
              title: Text(
                r.title.isEmpty
                    ? MaterialLocalizations.of(context)
                          .formatMediumDate(r.createdAt.toLocal())
                    : r.title,
              ),
              onTap: () => Navigator.pop(context, r.id),
            ),
        ],
      ),
    );
  }
}

class _PreviewDialog extends ConsumerStatefulWidget {
  const _PreviewDialog({required this.draft, required this.recordingId});

  final ProfileDraft draft;
  final String recordingId;

  @override
  ConsumerState<_PreviewDialog> createState() => _PreviewDialogState();
}

class _PreviewDialogState extends ConsumerState<_PreviewDialog> {
  late final Future<Result<PreviewResult>> _run = _start();

  Future<Result<PreviewResult>> _start() async {
    final parts = await ref.read(
      previewInputProvider(widget.recordingId).future,
    );
    final preview = await ref.read(profilePreviewProvider.future);
    return await preview.run(widget.draft, input: parts.forProfile);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.profileEditorTest),
      content: SizedBox(
        width: double.maxFinite,
        child: FutureBuilder<Result<PreviewResult>>(
          future: _run,
          builder: (context, snap) => switch (snap.data) {
            null when snap.hasError => Text(l.profileEditorTestFailed),
            null => Text(l.profileEditorTestRunning),
            Err() => Text(l.profileEditorTestFailed),
            Ok(:final value) => DefaultTabController(
              length: 2,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!value.valid) Text(l.profileEditorTestInvalid),
                  TabBar(
                    tabs: [
                      Tab(text: l.profileEditorTestJson),
                      Tab(text: l.profileEditorTestMarkdown),
                    ],
                  ),
                  SizedBox(
                    height: 360,
                    child: TabBarView(
                      children: [
                        SingleChildScrollView(
                          child: SelectableText(value.json),
                        ),
                        SingleChildScrollView(
                          child: SelectableText(value.markdown),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.profileEditorTestClose),
        ),
      ],
    );
  }
}
