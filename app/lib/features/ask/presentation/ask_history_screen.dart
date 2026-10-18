import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/routing/app_routes.dart';
import 'package:vaultvoice/core/widgets/status_message.dart';
import 'package:vaultvoice/features/ask/data/ask_providers.dart';
import 'package:vaultvoice/features/ask/domain/ask_history.dart';
import 'package:vaultvoice/features/ask/presentation/ask_chat.dart';

/// Saved chats (30-day expiry): open, delete one, or clear everything.
class AskHistoryScreen extends ConsumerWidget {
  const AskHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final threads = ref.watch(askThreadsProvider);
    final saving = ref.watch(askSaveHistoryEnabledProvider);
    final list = threads.value ?? const <AskThread>[];
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.askHistoryTitle),
        actions: [
          TextButton(
            key: const ValueKey('ask-clear-all'),
            onPressed: list.isEmpty ? null : () => _clearAll(context, ref),
            child: Text(l10n.askHistoryClearAll),
          ),
        ],
      ),
      body: Column(
        children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.schedule),
            title: Text(
              saving ? l10n.askHistoryExpiryNote : l10n.askHistoryDisabled,
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? StatusMessage(
                    icon: Icons.history,
                    message: l10n.askHistoryEmpty,
                  )
                : ListView(
                    children: [
                      for (final t in list)
                        ListTile(
                          key: ValueKey('ask-thread-${t.id}'),
                          title: Text(
                            t.turns.isEmpty ? '' : t.turns.first.question,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(l10n.askHistoryTurns(t.turns.length)),
                          onTap: () => _open(context, ref, t),
                          trailing: IconButton(
                            key: ValueKey('ask-delete-${t.id}'),
                            tooltip: l10n.askHistoryDelete,
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(context, ref, t),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, WidgetRef ref, AskThread thread) {
    ref.read(askChatProvider(thread.recordingId).notifier).load(thread);
    AskRoute(recording: thread.recordingId).go(context);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    AskThread thread,
  ) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref
        .read(askHistoryStoreProvider)
        .deleteThread(thread.id);
    ref.invalidate(askThreadsProvider);
    if (result is Ok) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.askHistoryDeleted)));
    }
  }

  Future<void> _clearAll(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.askHistoryClearTitle),
        content: Text(l10n.askHistoryClearBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            key: const ValueKey('ask-clear-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.askHistoryClearConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(askHistoryStoreProvider).clearAll();
    ref.invalidate(askThreadsProvider);
    messenger.showSnackBar(SnackBar(content: Text(l10n.askHistoryCleared)));
  }
}
