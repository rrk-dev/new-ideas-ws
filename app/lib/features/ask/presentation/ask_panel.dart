import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/routing/app_routes.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/core/widgets/lumen_card.dart';
import 'package:vaultvoice/core/widgets/primary_action_button.dart';
import 'package:vaultvoice/core/widgets/status_message.dart';
import 'package:vaultvoice/features/ask/data/ask_providers.dart';
import 'package:vaultvoice/features/ask/domain/ask_availability.dart';
import 'package:vaultvoice/features/ask/domain/ask_models.dart';
import 'package:vaultvoice/features/ask/domain/ask_service.dart';
import 'package:vaultvoice/features/ask/presentation/ask_chat.dart';
import 'package:vaultvoice/features/library/data/library_providers.dart';
import 'package:vaultvoice/features/library/presentation/transcript_navigation.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/licensing/domain/paywall.dart';
import 'package:vaultvoice/features/licensing/presentation/feature_gate.dart';
import 'package:vaultvoice/features/models/data/model_state_providers.dart';
import 'package:vaultvoice/features/models/presentation/model_download_actions.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_providers.dart';

/// Ask across the whole library ([recordingId] null) or about one recording.
/// Used by the Ask screen and by the recording hub's Ask tab.
///
/// States (ADR-ASK-02 + human decisions 2026-10-17): locked (`FeatureGate`),
/// device too low, 3B missing (download), no recordings, ready.
class AskPanel extends ConsumerWidget {
  const AskPanel({this.recordingId, super.key});

  final String? recordingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return FeatureGate(
      feature: Feature.askNotes,
      locked: (context) => StatusMessage(
        icon: Icons.lock_outline,
        message: l10n.askLocked,
        actionLabel: l10n.paywallTitle,
        onAction: () =>
            ensureFeature(ref, Feature.askNotes, from: PaywallEntryPoint.ask),
      ),
      enabled: (context) {
        final availability = ref.watch(askAvailabilityStateProvider);
        return switch (availability) {
          AsyncData(value: AskAvailability.deviceTooLow) => StatusMessage(
            icon: Icons.phone_iphone,
            message: l10n.askUnavailableDevice,
          ),
          AsyncData(value: AskAvailability.needsModel) => const _NeedsModel(),
          AsyncData() => _Chat(recordingId: recordingId),
          AsyncError() => StatusMessage(
            icon: Icons.error_outline,
            message: l10n.askError,
          ),
          _ => const Center(child: CircularProgressIndicator()),
        };
      },
    );
  }
}

class _NeedsModel extends ConsumerWidget {
  const _NeedsModel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final entry = ref.watch(askModelEntryProvider).value;
    final size = entry == null
        ? l10n.askNeedsModelUnknownSize
        : formatBytes(l10n, entry.size);
    final downloading =
        ref.watch(modelDownloadProgressProvider).value?[kAskModelId] != null;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.download_for_offline_outlined, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.askNeedsModelTitle,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.askNeedsModelBody(size), textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            if (downloading) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.askNeedsModelDownloading),
            ] else if (entry != null)
              PrimaryActionButton(
                key: const ValueKey('ask-download-model'),
                label: l10n.askNeedsModelDownload(size),
                icon: Icons.download,
                onPressed: () => startModelDownload(context, ref, entry),
              ),
            TextButton(
              key: const ValueKey('ask-open-models'),
              onPressed: () => const ModelsSettingsRoute().push<void>(context),
              child: Text(l10n.askNeedsModelOpenModels),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chat extends ConsumerStatefulWidget {
  const _Chat({required this.recordingId});

  final String? recordingId;

  @override
  ConsumerState<_Chat> createState() => _ChatState();
}

class _ChatState extends ConsumerState<_Chat> {
  final TextEditingController _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    unawaited(ref.read(askChatProvider(widget.recordingId).notifier).ask(text));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final chat = ref.watch(askChatProvider(widget.recordingId));
    final notifier = ref.read(askChatProvider(widget.recordingId).notifier);
    final empty =
        widget.recordingId == null &&
        (ref.watch(libraryItemsProvider).value?.isEmpty ?? false);
    final processing =
        chat.busy &&
        (ref
                .watch(processingViewsProvider)
                .value
                ?.any((v) => v.job.state.isActive) ??
            false);
    return Column(
      children: [
        Expanded(
          child: empty
              ? StatusMessage(
                  icon: Icons.mic_none,
                  message: l10n.askNoRecordings,
                )
              : chat.turns.isEmpty
              ? _Intro(recordingId: widget.recordingId)
              : ListView(
                  key: const ValueKey('ask-turns'),
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  children: [
                    for (final turn in chat.turns.reversed)
                      _TurnView(turn: turn, onRetry: notifier.ask),
                  ],
                ),
        ),
        if (processing)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              l10n.askProcessingNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (chat.busy)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              0,
            ),
            child: Row(
              children: [
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(l10n.askWorking)),
                TextButton(
                  key: const ValueKey('ask-cancel'),
                  onPressed: notifier.cancel,
                  child: Text(l10n.askCancel),
                ),
              ],
            ),
          ),
        if (!empty)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('ask-input'),
                      controller: _input,
                      enabled: !chat.busy,
                      textInputAction: TextInputAction.send,
                      maxLength: 400,
                      maxLines: null,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: l10n.askInputHint,
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.filled(
                    key: const ValueKey('ask-send'),
                    tooltip: l10n.askSend,
                    icon: const Icon(Icons.send),
                    onPressed: chat.busy ? null : _send,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.recordingId});

  final String? recordingId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return StatusMessage(
      icon: Icons.question_answer_outlined,
      message:
          '${recordingId == null ? l10n.askTitle : l10n.askRecordingTitle}'
          '\n${l10n.askDisclaimer}',
    );
  }
}

class _TurnView extends StatelessWidget {
  const _TurnView({required this.turn, required this.onRetry});

  final AskChatTurn turn;
  final void Function(String question) onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final answer = turn.answer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Semantics(
            label: l10n.askQuestionSemantics(turn.question),
            excludeSemantics: true,
            child: LumenCard(
              tonal: true,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(turn.question),
            ),
          ),
        ),
        if (turn.issue case final issue?)
          LumenCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Text(switch (issue) {
                    AskIssue.cancelled => l10n.askCancelled,
                    AskIssue.modelMissing => l10n.askNeedsModelTitle,
                    AskIssue.deviceTooLow => l10n.askUnavailableDevice,
                    AskIssue.memory || AskIssue.failed => l10n.askError,
                  }),
                ),
                if (issue == AskIssue.memory || issue == AskIssue.failed)
                  TextButton(
                    key: const ValueKey('ask-retry'),
                    onPressed: () => onRetry(turn.question),
                    child: Text(l10n.askRetry),
                  ),
              ],
            ),
          )
        else if (answer != null)
          AskAnswerCard(answer: answer),
        const SizedBox(height: AppSpacing.xs),
        if (turn.pending) const SizedBox.shrink(),
        Padding(
          padding: EdgeInsets.zero,
          child: Divider(height: 1, color: theme.dividerColor),
        ),
      ],
    );
  }
}

/// One answer: text, its sources as tappable chips (recording + time), and
/// the standing "answers can be wrong" note. A refusal shows only the
/// not-found text.
class AskAnswerCard extends ConsumerWidget {
  const AskAnswerCard({required this.answer, super.key});

  final AskAnswer answer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final found = answer.outcome == AskOutcome.answered;
    final retrievalOnly = answer.outcome == AskOutcome.retrievalOnly;
    final passages = answer.passages.take(5).toList();
    return LumenCard(
      key: const ValueKey('ask-answer'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: l10n.askAnswerSemantics(
              found ? answer.answer : l10n.askNotFound,
            ),
            excludeSemantics: true,
            child: Text(
              retrievalOnly
                  ? l10n.askBusyPassages
                  : found
                  ? answer.answer
                  : l10n.askNotFound,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          if (found && answer.citations.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.askSourcesTitle, style: theme.textTheme.labelLarge),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final c in answer.citations)
                  AskCitationChip(
                    recordingId: c.recordingId,
                    tMs: c.tMs,
                    time: c.timestamp,
                  ),
              ],
            ),
          ],
          if (retrievalOnly)
            for (final p in passages)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.sm,
                  children: [
                    AskCitationChip(
                      recordingId: p.recordingId,
                      tMs: p.tMs,
                      time: formatAskTimestamp(p.tMs),
                    ),
                    Text(p.text, maxLines: 3, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
          if (found) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.askDisclaimer,
              key: const ValueKey('ask-disclaimer'),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// A cited source: opens the recording at the cited time through the
/// `TranscriptNavigator` (ASK-04 AC2).
class AskCitationChip extends ConsumerWidget {
  const AskCitationChip({
    required this.recordingId,
    required this.tMs,
    required this.time,
    super.key,
  });

  final String recordingId;
  final int tMs;
  final String time;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final title = ref.watch(recordingHeaderProvider(recordingId)).value?.title;
    final label = (title == null || title.trim().isEmpty)
        ? time
        : l10n.askCitationLabel(title, time);
    return Semantics(
      button: true,
      hint: l10n.askCitationHint(time),
      child: ActionChip(
        key: ValueKey('ask-citation-$recordingId-$time'),
        avatar: const Icon(Icons.play_circle_outline, size: AppSizes.iconSm),
        label: Text(label, overflow: TextOverflow.ellipsis),
        materialTapTargetSize: MaterialTapTargetSize.padded,
        onPressed: () => ref
            .read(transcriptNavigatorProvider)
            .open(context, recordingId, atMs: tMs),
      ),
    );
  }
}
