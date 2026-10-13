import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/features/pipeline/domain/job_progress.dart';
import 'package:vaultvoice/features/pipeline/presentation/job_commands.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_providers.dart';

/// The job that represents a recording's processing: the one still in the
/// pipeline, else the newest.
JobProgressView? currentViewFor(List<JobProgressView> views, String id) {
  JobProgressView? newest;
  for (final v in views) {
    if (v.job.recordingId != id) continue;
    if (isInPipeline(v.job)) return v;
    if (newest == null || v.job.createdAt.isAfter(newest.job.createdAt)) {
      newest = v;
    }
  }
  return newest;
}

/// Processing status of one recording (notification deep-link target).
class RecordingStatusScreen extends ConsumerWidget {
  const RecordingStatusScreen({required this.recordingId, super.key});

  final String recordingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final views = ref.watch(processingViewsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Processing')),
      body: views.when(
        loading: () => const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Loading'),
        ),
        error: (_, _) => StatusMessage(
          icon: Icons.error_outline,
          message: 'Could not load the processing status.',
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(processingViewsProvider),
        ),
        data: (all) {
          final view = currentViewFor(all, recordingId);
          if (view == null) {
            return const StatusMessage(
              icon: Icons.hourglass_empty,
              message: 'This recording has not been processed yet.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [ConnectedProcessingStatusCard(view: view)],
          );
        },
      ),
    );
  }
}

/// Centered icon + message (+ optional action) for empty and error states.
class StatusMessage extends StatelessWidget {
  const StatusMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.md),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
