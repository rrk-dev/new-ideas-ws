import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/routing/app_routes.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/core/widgets/circle_icon_button.dart';
import 'package:vaultvoice/core/widgets/grouped_card.dart';
import 'package:vaultvoice/core/widgets/section_header.dart';
import 'package:vaultvoice/core/widgets/status_message.dart';
import 'package:vaultvoice/features/ask/data/ask_providers.dart';
import 'package:vaultvoice/features/ask/presentation/ask_panel.dart';
import 'package:vaultvoice/features/library/data/library_providers.dart';
import 'package:vaultvoice/features/library/domain/extraction_summary.dart';
import 'package:vaultvoice/features/library/domain/library_models.dart';
import 'package:vaultvoice/features/library/domain/recording_detail.dart';
import 'package:vaultvoice/features/library/presentation/library_texts.dart';
import 'package:vaultvoice/features/library/presentation/transcript_lines_screen.dart';
import 'package:vaultvoice/features/library/presentation/transcript_navigation.dart';
import 'package:vaultvoice/features/mindmap/presentation/mind_map_tab.dart';
import 'package:vaultvoice/features/pipeline/domain/job_progress.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/presentation/job_commands.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_providers.dart';
import 'package:vaultvoice/features/pipeline/presentation/recording_status_screen.dart';
import 'package:vaultvoice/features/profiles/presentation/profile_picker.dart';
import 'package:vaultvoice/features/recording/data/recording_screen_providers.dart';

/// Lines of the transcript shown inline before "Show full transcript".
const int kTranscriptPreviewLines = 5;

/// One recording (APP-02; notification deep-link target): facts, processing
/// status, transcript preview, extracted result, export history, and the
/// actions re-extract / change profile / re-export / delete.
class RecordingDetailScreen extends ConsumerWidget {
  const RecordingDetailScreen({required this.recordingId, super.key});

  final String recordingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final header = ref.watch(recordingHeaderProvider(recordingId));
    return header.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: CircularProgressIndicator(semanticsLabel: l10n.commonLoading),
        ),
      ),
      error: (_, _) => Scaffold(
        appBar: AppBar(),
        body: StatusMessage(
          icon: Icons.error_outline,
          message: l10n.recordingLoadFailed,
          actionLabel: l10n.commonTryAgain,
          onAction: () => ref.invalidate(recordingHeaderProvider(recordingId)),
        ),
      ),
      data: (h) => h == null
          ? Scaffold(
              appBar: AppBar(),
              body: StatusMessage(
                icon: Icons.search_off,
                message: l10n.recordingNotFound,
              ),
            )
          : _Detail(header: h),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.header});

  final RecordingHeader header;

  String get _id => header.id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final views = ref.watch(processingViewsProvider).value;
    final view = views == null ? null : currentViewFor(views, _id);
    final lines = ref.watch(recordingTranscriptProvider(_id)).value;
    final extraction = ref.watch(recordingExtractionProvider(_id)).value;
    final exports = ref.watch(recordingExportsProvider(_id)).value ?? const [];
    final profiles = ref.watch(profileNamesProvider).value ?? const {};
    final profileId = header.profileId ?? extraction?.profileId;
    final facts = [
      LibraryTexts.date(l10n, header.createdAt),
      LibraryTexts.duration(l10n, header.duration),
      if (profileId != null) profiles[profileId] ?? profileId,
      if (header.imported) l10n.recordingImported,
    ].join(' · ');

    final actionFields = extraction == null
        ? const <ExtractionField>[]
        : summarizeExtraction(extraction.data)
              .where((f) => f.key == _actionItemsKey)
              .toList();
    final slots = ref.watch(recordingHubSlotsProvider);
    final tabs = <({String id, String label, Widget body})>[
      (
        id: 'summary',
        label: l10n.recordingTabSummary,
        body: _SummaryTab(
          header: header,
          view: view,
          extraction: extraction,
          exports: exports,
        ),
      ),
      (
        id: 'transcript',
        label: l10n.recordingTranscript,
        body: _TranscriptTab(recordingId: _id, lines: lines),
      ),
      (
        id: 'action-items',
        label: l10n.recordingTabActionItems,
        body: _ActionItemsTab(fields: actionFields),
      ),
      for (final slot in slots)
        (
          id: slot.id,
          label: slot.label(l10n),
          body: slot.builder(context, _id),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(LibraryTexts.title(l10n, header.title)),
        actions: [
          PopupMenuButton<_Action>(
            key: const ValueKey('recording-actions'),
            tooltip: l10n.recordingActions,
            style: circleMenuStyle(context),
            onSelected: (a) => _run(context, ref, a, view, exports),
            itemBuilder: (context) => [
              if (extraction != null)
                PopupMenuItem(
                  value: _Action.review,
                  child: Text(context.l10n.reviewEditResult),
                ),
              PopupMenuItem(
                value: _Action.reExtract,
                child: Text(context.l10n.recordingReExtract),
              ),
              PopupMenuItem(
                value: _Action.changeProfile,
                child: Text(context.l10n.recordingChangeProfile),
              ),
              PopupMenuItem(
                value: _Action.reExport,
                child: Text(context.l10n.recordingReExport),
              ),
              PopupMenuItem(
                value: _Action.delete,
                child: Text(context.l10n.recordingDelete),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
          child: DefaultTabController(
            length: tabs.length,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    0,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(facts, style: theme.textTheme.bodyMedium),
                  ),
                ),
                if (header.tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      0,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        children: [
                          for (final t in header.tags) Chip(label: Text(t)),
                        ],
                      ),
                    ),
                  ),
                if (view?.job.waitingReason == WaitingReason.review)
                  Card(
                    key: const ValueKey('recording-review-banner'),
                    margin: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                      0,
                    ),
                    color: theme.colorScheme.secondaryContainer,
                    child: ListTile(
                      leading: Icon(
                        Icons.rate_review_outlined,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                      title: Text(
                        l10n.reviewBanner,
                        style: TextStyle(
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                      trailing: FilledButton(
                        onPressed: () =>
                            RecordingReviewRoute(recordingId: _id).go(context),
                        child: Text(l10n.reviewOpen),
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                TabBar(
                  key: const ValueKey('recording-tabs'),
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [for (final t in tabs) Tab(text: t.label)],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      for (final t in tabs)
                        KeyedSubtree(
                          key: ValueKey('recording-tab-${t.id}'),
                          child: t.body,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _exportStatus(AppLocalizations l, ExportInfo e) => e.written
      ? l.exportStatusWritten
      : e.failed
      ? l.exportStatusFailed
      : l.exportStatusPending;

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    _Action action,
    JobProgressView? view,
    List<ExportInfo> exports,
  ) async {
    final job = view?.job;
    switch (action) {
      case _Action.review:
        RecordingReviewRoute(recordingId: _id).go(context);
      case _Action.reExtract:
        await _rerun(context, ref, job, PipelineStepId.extract);
      case _Action.reExport:
        await _rerun(context, ref, job, PipelineStepId.render);
      case _Action.changeProfile:
        final choices = await ref.read(profileChoicesProvider.future);
        if (!context.mounted) return;
        final pick = await showProfilePicker(
          context,
          choices: choices,
          selectedId: header.profileId,
          includeAuto: false,
        );
        final profile = pick?.id;
        if (profile == null || !context.mounted) return;
        await ref
            .read(recordingsRepositoryProvider)
            .updateFields(_id, RecordingsCompanion(profileId: Value(profile)));
        if (!context.mounted) return;
        await _rerun(
          context,
          ref,
          job,
          PipelineStepId.extract,
          profileId: profile,
        );
      case _Action.delete:
        await _delete(context, ref, exports);
    }
  }

  Future<void> _rerun(
    BuildContext context,
    WidgetRef ref,
    JobSnapshot? job,
    PipelineStepId from, {
    String? profileId,
  }) async {
    if (job != null && job.state.isActive) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.recordingBusy)));
      return;
    }
    await runJobCommand(
      context,
      ref,
      (c) => job == null
          ? c.enqueue(_id, userInitiated: true, profileId: profileId)
          : c.rerun(job.id, from, profileId: profileId),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    List<ExportInfo> exports,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final written = exports.where((e) => e.written).toList();
    final choice = await showDialog<_DeleteChoice>(
      context: context,
      builder: (_) => _DeleteDialog(
        folders: [
          for (final e in written)
            if (e.targetName.isEmpty)
              l10n.vaultFolderDefaultName
            else
              e.targetName,
        ],
      ),
    );
    if (choice == null) return;
    final deleter = await ref.read(recordingDeleterProvider.future);
    final result = await deleter.delete(
      _id,
      deleteExportedNotes: choice.deleteNotes,
    );
    final report = result.valueOrNull;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          report == null
              ? l10n.recordingDeleteFailed
              : choice.deleteNotes && report.notesKept > 0
              ? l10n.recordingDeletedNotesKept(report.notesKept)
              : l10n.recordingDeleted,
        ),
      ),
    );
    if (report != null && context.mounted) const LibraryRoute().go(context);
  }
}

const String _actionItemsKey = 'action_items';

EdgeInsets get _tabPadding =>
    const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xl);

/// Summary tab: processing status, extracted fields and export history.
class _SummaryTab extends StatelessWidget {
  const _SummaryTab({
    required this.header,
    required this.view,
    required this.extraction,
    required this.exports,
  });

  final RecordingHeader header;
  final JobProgressView? view;
  final ExtractionView? extraction;
  final List<ExportInfo> exports;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final fields = extraction == null
        ? const <ExtractionField>[]
        : summarizeExtraction(extraction!.data)
              .where((f) => f.key != _actionItemsKey)
              .toList();
    return ListView(
      padding: _tabPadding,
      children: [
        if (view != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: ConnectedProcessingStatusCard(view: view!),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(l10n.processingNotProcessed),
          ),
        SectionHeader(l10n.recordingExtracted),
        if (extraction == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(l10n.recordingNoExtraction),
          )
        else ...[
          if (!extraction!.valid)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                l10n.recordingExtractionInvalid,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          if (fields.isNotEmpty)
            GroupedCard(
              children: [
                for (final f in fields)
                  ListTile(
                    title: Text(humanizeFieldName(f.key)),
                    subtitle: Text(
                      f.values.isEmpty ? '—' : f.values.join('\n'),
                    ),
                  ),
              ],
            ),
        ],
        SectionHeader(l10n.recordingExports),
        if (exports.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(l10n.recordingNoExports),
          )
        else
          GroupedCard(
            children: [
              for (final e in exports)
                ListTile(
                  leading: Icon(
                    e.written
                        ? Icons.check_circle_outline
                        : e.failed
                        ? Icons.error_outline
                        : Icons.schedule,
                  ),
                  title: Text(
                    e.targetName.isEmpty
                        ? l10n.vaultFolderDefaultName
                        : e.targetName,
                  ),
                  subtitle: Text(
                    '${e.relPath}\n'
                    '${_Detail._exportStatus(l10n, e)} · '
                    '${LibraryTexts.date(l10n, e.updatedAt)}',
                  ),
                  isThreeLine: true,
                ),
            ],
          ),
      ],
    );
  }
}

/// Transcript tab: the first lines and a button for the full transcript.
class _TranscriptTab extends ConsumerWidget {
  const _TranscriptTab({required this.recordingId, required this.lines});

  final String recordingId;
  final List<TranscriptLine>? lines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final all = lines;
    return ListView(
      padding: _tabPadding,
      children: [
        if (all == null || all.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(l10n.recordingNoTranscript),
          )
        else ...[
          for (final line in all.take(kTranscriptPreviewLines))
            TranscriptLineTile(line: line),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: TextButton(
                key: const ValueKey('recording-open-transcript'),
                onPressed: () => ref
                    .read(transcriptNavigatorProvider)
                    .open(context, recordingId),
                child: Text(l10n.recordingShowTranscript(all.length)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Action items extracted from this recording.
class _ActionItemsTab extends StatelessWidget {
  const _ActionItemsTab({required this.fields});

  final List<ExtractionField> fields;

  @override
  Widget build(BuildContext context) {
    final values = [for (final f in fields) ...f.values];
    return ListView(
      padding: _tabPadding,
      children: [
        if (values.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(context.l10n.recordingNoActionItems),
          )
        else
          GroupedCard(
            children: [
              for (final v in values)
                ListTile(
                  leading: const Icon(Icons.radio_button_unchecked),
                  title: Text(v),
                ),
            ],
          ),
      ],
    );
  }
}

/// A section a feature adds to the recording hub (Mind map MAP-02, Ask
/// ASK-04).
class RecordingHubSlot {
  const RecordingHubSlot({
    required this.id,
    required this.label,
    required this.builder,
  });

  final String id;
  final String Function(AppLocalizations l10n) label;
  final Widget Function(BuildContext context, String recordingId) builder;
}

/// Extra hub sections, appended after Action items: the mind map (MAP-02)
/// and, while `ask.enabled` is on, Ask about this recording (ASK-04).
final recordingHubSlotsProvider = Provider<List<RecordingHubSlot>>(
  (ref) => [
    RecordingHubSlot(
      id: 'mind-map',
      label: (l10n) => l10n.recordingTabMindMap,
      builder: (context, recordingId) => MindMapTab(recordingId: recordingId),
    ),
    if (ref.watch(askEnabledProvider))
      RecordingHubSlot(
        id: 'ask',
        label: (l10n) => l10n.recordingTabAsk,
        builder: (context, recordingId) => AskPanel(recordingId: recordingId),
      ),
  ],
);

enum _Action { review, reExtract, changeProfile, reExport, delete }

class _DeleteChoice {
  const _DeleteChoice({required this.deleteNotes});

  final bool deleteNotes;
}

/// Confirms the deletion and asks whether the exported note goes too
/// (default: keep it — notes in the vault are the user's files).
class _DeleteDialog extends StatefulWidget {
  const _DeleteDialog({required this.folders});

  final List<String> folders;

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  // PRODUCT-DECISION: the exported note is kept unless the user ticks the
  // box (vault notes may have been edited by the user since export).
  bool _deleteNotes = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.recordingDeleteTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.recordingDeleteBody),
          if (widget.folders.isNotEmpty)
            CheckboxListTile(
              key: const ValueKey('recording-delete-notes'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _deleteNotes,
              onChanged: (v) => setState(() => _deleteNotes = v ?? false),
              title: Text(
                l10n.recordingDeleteNotes(widget.folders.toSet().join(', ')),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('recording-delete-confirm'),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () =>
              Navigator.of(context)
                  .pop(_DeleteChoice(deleteNotes: _deleteNotes)),
          child: Text(l10n.recordingDelete),
        ),
      ],
    );
  }
}
