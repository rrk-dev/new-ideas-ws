import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/routing/app_routes.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/features/pipeline/domain/job_progress.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/presentation/job_commands.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_providers.dart';
import 'package:vaultvoice/features/pipeline/presentation/recording_status_screen.dart';

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
      appBar: AppBar(title: const Text('Processing queue')),
      body: views.when(
        loading: () => const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Loading'),
        ),
        error: (_, _) => StatusMessage(
          icon: Icons.error_outline,
          message: 'Could not load the processing queue.',
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(processingViewsProvider),
        ),
        data: (all) {
          final items = queueViews(all);
          if (items.isEmpty) {
            return const StatusMessage(
              icon: Icons.check_circle_outline,
              message: 'Nothing is being processed right now.',
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
