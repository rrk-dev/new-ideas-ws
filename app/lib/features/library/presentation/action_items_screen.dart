import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/core/routing/app_routes.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/core/widgets/status_message.dart';
import 'package:vaultvoice/features/library/data/library_providers.dart';
import 'package:vaultvoice/features/library/domain/recording_detail.dart';
import 'package:vaultvoice/features/library/presentation/library_texts.dart';
import 'package:vaultvoice/features/reminders/data/reminders_providers.dart';
import 'package:vaultvoice/features/reminders/presentation/reminders_sheet.dart';

/// Open tasks across all recordings (APP-02), from the `action_items` table
/// RenderStep fills. Ticking an item marks it done in the app (the exported
/// note is not rewritten).
class ActionItemsScreen extends ConsumerStatefulWidget {
  const ActionItemsScreen({super.key});

  @override
  ConsumerState<ActionItemsScreen> createState() => _ActionItemsScreenState();
}

class _ActionItemsScreenState extends ConsumerState<ActionItemsScreen> {
  bool _openOnly = true;

  Future<void> _toggle(ActionItemView item, bool done) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.actionItemUpdateFailed;
    final r = await ref
        .read(extractionsRepositoryProvider)
        .setActionItemDone(
          item.id,
          done: done,
          at: ref.read(clockProvider).now(),
        );
    if (!r.isOk) messenger.showSnackBar(SnackBar(content: Text(failed)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = ref.watch(actionItemsProvider(openOnly: _openOnly));
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.actionItemsTitle),
        actions: [
          if (ref.watch(remindersSupportedProvider))
            IconButton(
              key: const ValueKey('action-items-reminders'),
              tooltip: l10n.remindersAdd,
              icon: const Icon(Icons.add_task),
              onPressed: () => showRemindersSheet(context, ref),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SegmentedButton<bool>(
              key: const ValueKey('action-items-filter'),
              segments: [
                ButtonSegment(value: true, label: Text(l10n.actionItemsOpen)),
                ButtonSegment(value: false, label: Text(l10n.actionItemsAll)),
              ],
              selected: {_openOnly},
              onSelectionChanged: (s) => setState(() => _openOnly = s.first),
            ),
          ),
          Expanded(
            child: items.when(
              loading: () => Center(
                child: CircularProgressIndicator(
                  semanticsLabel: l10n.commonLoading,
                ),
              ),
              error: (_, _) => StatusMessage(
                icon: Icons.error_outline,
                message: l10n.actionItemsLoadFailed,
                actionLabel: l10n.commonTryAgain,
                onAction: () =>
                    ref.invalidate(actionItemsProvider(openOnly: _openOnly)),
              ),
              data: (list) => list.isEmpty
                  ? StatusMessage(
                      icon: Icons.task_alt,
                      message: _openOnly
                          ? l10n.actionItemsNoneOpen
                          : l10n.actionItemsNone,
                    )
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final a = list[i];
                        final details = [
                          ?a.owner,
                          ?a.due,
                          LibraryTexts.title(l10n, a.recordingTitle),
                        ].join(' · ');
                        return CheckboxListTile(
                          key: ValueKey('action-item-${a.id}'),
                          controlAffinity: ListTileControlAffinity.leading,
                          value: a.done,
                          onChanged: (v) => _toggle(a, v ?? false),
                          title: Text(
                            a.body,
                            style: a.done
                                ? const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                  )
                                : null,
                          ),
                          subtitle: Text(details),
                          secondary: IconButton(
                            tooltip: l10n.actionItemOpenRecording,
                            icon: const Icon(Icons.open_in_new),
                            onPressed: () =>
                                RecordingStatusRoute(recordingId: a.recordingId)
                                    .go(context),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
