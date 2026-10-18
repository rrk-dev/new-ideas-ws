import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/diagnostics/diagnostics_providers.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/platform/share_service.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/core/widgets/lumen_card.dart';
import 'package:vaultvoice/core/widgets/primary_action_button.dart';
import 'package:vaultvoice/core/widgets/status_message.dart';
import 'package:vaultvoice/features/library/data/library_providers.dart';
import 'package:vaultvoice/features/library/presentation/transcript_navigation.dart';
import 'package:vaultvoice/features/mindmap/data/mind_map_providers.dart';
import 'package:vaultvoice/features/mindmap/domain/mind_map.dart';
import 'package:vaultvoice/features/mindmap/domain/mind_map_markdown.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/presentation/job_commands.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_providers.dart';
import 'package:vaultvoice/features/pipeline/presentation/recording_status_screen.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';

/// Milliseconds of an `hh:mm:ss` evidence stamp; null when malformed.
int? mindMapStampMs(String? t) {
  if (t == null) return null;
  final p = t.split(':');
  if (p.length != 3) return null;
  final v = p.map(int.tryParse).toList();
  if (v.any((e) => e == null)) return null;
  return ((v[0]! * 60 + v[1]!) * 60 + v[2]!) * 1000;
}

/// The "Mind map" tab of the recording hub (MAP-02): pannable, zoomable,
/// collapsible tree with an evidence panel and Generate / Export actions.
class MindMapTab extends ConsumerWidget {
  const MindMapTab({required this.recordingId, super.key});

  final String recordingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final map = ref.watch(recordingMindMapProvider(recordingId)).value;
    final requested =
        ref.watch(mindMapRequestedProvider(recordingId)).value ?? false;
    final views = ref.watch(processingViewsProvider).value;
    final job = views == null ? null : currentViewFor(views, recordingId)?.job;
    final active = job != null && job.state.isActive;
    final lines = ref.watch(recordingTranscriptProvider(recordingId)).value;

    if (map != null) {
      return _MapView(
        recordingId: recordingId,
        root: map,
        busy: active,
        onRegenerate: () => _generate(context, ref, job),
      );
    }
    if (active && (requested || job.state == JobState.mapping)) {
      return StatusMessage(
        icon: Icons.account_tree_outlined,
        message: l10n.mindMapGenerating,
      );
    }
    if (requested) {
      return StatusMessage(
        icon: Icons.error_outline,
        message: l10n.mindMapFailed,
        actionLabel: l10n.mindMapRetry,
        onAction: () => _generate(context, ref, job),
      );
    }
    if (lines == null || lines.isEmpty) {
      return StatusMessage(
        icon: Icons.account_tree_outlined,
        message: l10n.mindMapNeedsTranscript,
      );
    }
    return StatusMessage(
      icon: Icons.account_tree_outlined,
      message: l10n.mindMapNone,
      actionLabel: l10n.mindMapGenerate,
      onAction: active ? null : () => _generate(context, ref, job),
    );
  }

  Future<void> _generate(
    BuildContext context,
    WidgetRef ref,
    JobSnapshot? job,
  ) async {
    await ref
        .read(settingsRepositoryProvider)
        .set(SettingKeys.mindMapRequestFor(recordingId), true);
    if (!context.mounted) return;
    await runJobCommand(
      context,
      ref,
      (c) => job == null
          ? c.enqueue(recordingId, userInitiated: true)
          : c.rerun(job.id, PipelineStepId.mindMap),
    );
  }
}

class _MapView extends ConsumerStatefulWidget {
  const _MapView({
    required this.recordingId,
    required this.root,
    required this.busy,
    required this.onRegenerate,
  });

  final String recordingId;
  final MindMapNode root;
  final bool busy;
  final VoidCallback onRegenerate;

  @override
  ConsumerState<_MapView> createState() => _MapViewState();
}

class _MapViewState extends ConsumerState<_MapView> {
  final Set<String> _collapsed = {};
  MindMapNode? _selected;

  void _toggle(MindMapNode n) {
    setState(() {
      if (!_collapsed.remove(n.id)) _collapsed.add(n.id);
    });
  }

  Future<void> _export() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    await runJobCommand(context, ref, (c) {
      final views = ref.read(processingViewsProvider).value;
      final job = views == null
          ? null
          : currentViewFor(views, widget.recordingId)?.job;
      return job == null
          ? c.enqueue(widget.recordingId, userInitiated: true)
          : c.rerun(job.id, PipelineStepId.render);
    });
    messenger.showSnackBar(SnackBar(content: Text(l10n.mindMapExportQueued)));
  }

  Future<void> _share() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await ref
        .read(shareServiceProvider)
        .shareText(mindMapStandaloneMarkdown(widget.root));
    if (outcome == ShareOutcome.unavailable) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.mindMapShareFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final root = widget.root;
    final selected = _selected;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              TextButton.icon(
                key: const ValueKey('mindmap-regenerate'),
                onPressed: widget.busy ? null : widget.onRegenerate,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.mindMapRegenerate),
              ),
              TextButton.icon(
                key: const ValueKey('mindmap-export'),
                onPressed: widget.busy ? null : _export,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(l10n.mindMapExport),
              ),
              TextButton.icon(
                key: const ValueKey('mindmap-share'),
                onPressed: _share,
                icon: const Icon(Icons.ios_share),
                label: Text(l10n.mindMapShare),
              ),
            ],
          ),
        ),
        Expanded(
          child: Semantics(
            container: true,
            label: l10n.mindMapSummary(root.count, root.label),
            child: InteractiveViewer(
              key: const ValueKey('mindmap-canvas'),
              constrained: false,
              minScale: 0.5,
              boundaryMargin: const EdgeInsets.all(AppSpacing.xl),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _rows(root, 0),
                ),
              ),
            ),
          ),
        ),
        if (selected != null)
          _EvidencePanel(recordingId: widget.recordingId, node: selected),
      ],
    );
  }

  List<Widget> _rows(MindMapNode n, int level) => [
    _NodeRow(
      node: n,
      level: level,
      collapsed: _collapsed.contains(n.id),
      selected: _selected?.id == n.id,
      onTap: () => setState(() => _selected = n),
      onToggle: n.children.isEmpty ? null : () => _toggle(n),
    ),
    if (!_collapsed.contains(n.id))
      for (final c in n.children) ..._rows(c, level + 1),
  ];
}

class _NodeRow extends StatelessWidget {
  const _NodeRow({
    required this.node,
    required this.level,
    required this.collapsed,
    required this.selected,
    required this.onTap,
    required this.onToggle,
  });

  final MindMapNode node;
  final int level;
  final bool collapsed;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(left: level * AppSpacing.lg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: kMinInteractiveDimension,
            child: onToggle == null
                ? null
                : IconButton(
                    tooltip: collapsed
                        ? l10n.mindMapExpand(node.label)
                        : l10n.mindMapCollapse(node.label),
                    onPressed: onToggle,
                    icon: Icon(
                      collapsed ? Icons.chevron_right : Icons.expand_more,
                    ),
                  ),
          ),
          Semantics(
            button: true,
            selected: selected,
            label: l10n.mindMapNodeSemantics(node.label, level + 1),
            excludeSemantics: true,
            onTap: onTap,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppSpacing.sm),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: kMinInteractiveDimension,
                  minWidth: kMinInteractiveDimension,
                  maxWidth: 280,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: 1,
                      child: Text(
                        node.label,
                        style: level == 0 ? text.titleMedium : text.bodyMedium,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidencePanel extends ConsumerWidget {
  const _EvidencePanel({required this.recordingId, required this.node});

  final String recordingId;
  final MindMapNode node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = node.t;
    final ms = mindMapStampMs(t);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: LumenCard(
        child: Column(
          key: const ValueKey('mindmap-evidence'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.mindMapEvidenceTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(node.label),
            const SizedBox(height: AppSpacing.sm),
            if (t == null || ms == null)
              Text(l10n.mindMapNoEvidence)
            else ...[
              Text(l10n.mindMapEvidenceAt(t)),
              const SizedBox(height: AppSpacing.sm),
              PrimaryActionButton(
                key: const ValueKey('mindmap-open-transcript'),
                label: l10n.mindMapOpenTranscript(t),
                onPressed: () => ref
                    .read(transcriptNavigatorProvider)
                    .open(context, recordingId, atMs: ms),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
