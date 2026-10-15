import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/core/widgets/status_message.dart';
import 'package:vaultvoice/features/export/data/export_outbox.dart';
import 'package:vaultvoice/features/export/data/routing_providers.dart';
import 'package:vaultvoice/features/export/domain/pending_export.dart';

/// Settings → Pending exports (EXP-06): notes whose vault write is still
/// outstanding, with re-grant / change destination / retry actions. Titles
/// and folder names are user content: shown, never logged.
class PendingExportsScreen extends ConsumerStatefulWidget {
  const PendingExportsScreen({super.key});

  @override
  ConsumerState<PendingExportsScreen> createState() =>
      _PendingExportsScreenState();
}

class _PendingExportsScreenState extends ConsumerState<PendingExportsScreen> {
  bool _busy = false;

  Future<void> _act(
    Future<Result<Object?>> Function(ExportOutbox o) action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.pendingActionFailed;
    setState(() => _busy = true);
    var ok = false;
    try {
      ok = (await action(ref.read(exportOutboxProvider))).isOk;
    } on Object {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) messenger.showSnackBar(SnackBar(content: Text(failed)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final pending = ref.watch(pendingExportsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsPendingExports)),
      body: pending.when(
        loading: () => Center(
          child: CircularProgressIndicator(semanticsLabel: l.commonLoading),
        ),
        error: (_, _) => StatusMessage(
          icon: Icons.error_outline,
          message: l.pendingExportsLoadFailed,
          actionLabel: l.commonTryAgain,
          onAction: () => ref.invalidate(pendingExportsProvider),
        ),
        data: (items) => items.isEmpty
            ? StatusMessage(
                icon: Icons.cloud_done_outlined,
                message: l.pendingExportsEmpty,
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  Text(l.pendingExportsSafe),
                  const SizedBox(height: AppSpacing.md),
                  for (final p in items)
                    _PendingCard(
                      key: ValueKey('pending-${p.recordingId}-${p.targetId}'),
                      item: p,
                      busy: _busy,
                      onAction: _act,
                    ),
                ],
              ),
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.item,
    required this.busy,
    required this.onAction,
    super.key,
  });

  final PendingExport item;
  final bool busy;
  final Future<void> Function(
    Future<Result<Object?>> Function(ExportOutbox o) action,
  )
  onAction;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final folder = item.targetName;
    final reason = switch (item.reason) {
      PendingReason.noDestination => l.pendingReasonNoDestination,
      PendingReason.accessRevoked =>
        folder == null
            ? l.pendingReasonRevokedAny
            : l.pendingReasonRevoked(folder),
      PendingReason.retrying => l.pendingReasonRetrying(
        folder ?? l.vaultFolderDefaultName,
      ),
      PendingReason.failed => l.pendingReasonFailed(
        folder ?? l.vaultFolderDefaultName,
      ),
    };
    final target = item.targetId;
    Widget action(
      String key,
      String label,
      Future<Result<Object?>> Function(ExportOutbox) run,
    ) => TextButton(
      key: ValueKey('pending-$key-${item.recordingId}'),
      onPressed: busy ? null : () => onAction(run),
      child: Text(label),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title.isEmpty ? l.pendingUntitled : item.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(reason),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                if (item.reason == PendingReason.noDestination) ...[
                  action(
                    'choose',
                    l.pendingActionChooseFolder,
                    (o) => o.addFolder(),
                  ),
                  action(
                    'device',
                    l.pendingActionSaveOnDevice,
                    (o) => o.saveOnDevice(),
                  ),
                ] else ...[
                  if (target != null &&
                      item.reason == PendingReason.accessRevoked)
                    action(
                      'regrant',
                      l.pendingActionRegrant,
                      (o) => o.regrant(target),
                    ),
                  if (item.reason != PendingReason.accessRevoked ||
                      target == null)
                    action('retry', l.pendingActionRetry, (o) => o.retry(item)),
                  if (target != null)
                    action(
                      'change',
                      l.pendingActionChange,
                      (o) => o.regrant(target, sameFolder: false),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
