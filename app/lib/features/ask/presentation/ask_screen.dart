import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/routing/app_routes.dart';
import 'package:vaultvoice/features/ask/presentation/ask_chat.dart';
import 'package:vaultvoice/features/ask/presentation/ask_panel.dart';

/// Ask across the library, or about one recording ([recordingId]).
class AskScreen extends ConsumerWidget {
  const AskScreen({this.recordingId, super.key});

  final String? recordingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.askTitle),
        actions: [
          IconButton(
            key: const ValueKey('ask-new-chat'),
            tooltip: l10n.askNewChat,
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: () =>
                ref.read(askChatProvider(recordingId).notifier).newChat(),
          ),
          IconButton(
            key: const ValueKey('ask-history'),
            tooltip: l10n.askHistoryTooltip,
            icon: const Icon(Icons.history),
            onPressed: () => const AskHistoryRoute().go(context),
          ),
        ],
      ),
      body: AskPanel(recordingId: recordingId),
    );
  }
}
