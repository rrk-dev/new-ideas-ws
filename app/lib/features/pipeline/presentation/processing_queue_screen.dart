import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/routing/app_routes.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/core/widgets/status_message.dart';
import 'package:vaultvoice/features/pipeline/domain/job_progress.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/presentation/job_commands.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_providers.dart';

/// Jobs shown in the queue: everything still in the pipeline plus failures
/// the user has not dealt with yet.
List<JobProgressView> queueViews(List<JobProgressView> all) => [
  for (final v in all)
    if (isInPipeline(v.job) || v.job.state == JobState.failed) v,
];

/// Every recording being processed (target of the global queue indicator).
class ProcessingQueueScreen extends ConsumerWidget {
  const ProcessingQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final views = ref.watch(processingViewsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.processingQueueTitle)),
      body: views.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            semanticsLabel: context.l10n.commonLoading,
          ),
        ),
        error: (_, _) => StatusMessage(
          icon: Icons.error_outline,
          message: context.l10n.processingQueueLoadFailed,
          actionLabel: context.l10n.commonTryAgain,
          onAction: () => ref.invalidate(processingViewsProvider),
        ),
        data: (all) {
          final items = queueViews(all);
          if (items.isEmpty) {
            return StatusMessage(
              icon: Icons.check_circle_outline,
              message: context.l10n.processingQueueEmpty,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: items.length,
            itemBuilder: (context, i) => ConnectedProcessingStatusCard(
              key: ValueKey(items[i].job.id),
              view: items[i],
              onTap: () =>
                  RecordingStatusRoute(recordingId: items[i].job.recordingId)
                      .push<void>(context),
            ),
          );
        },
      ),
    );
  }
}
