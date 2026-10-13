import 'package:flutter/material.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/features/pipeline/domain/job_progress.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_texts.dart';

/// Per-recording progress: step, percentage, ETA and the actions that make
/// sense in the job's state (APP-04).
class ProcessingStatusCard extends StatelessWidget {
  const ProcessingStatusCard({
    required this.view,
    this.onTap,
    this.onCancel,
    this.onRetry,
    this.onProcessNow,
    super.key,
  });

  final JobProgressView view;
  final VoidCallback? onTap;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final VoidCallback? onProcessNow;

  static IconData iconFor(JobState state) => switch (state) {
    JobState.done => Icons.check_circle_outline,
    JobState.failed => Icons.error_outline,
    JobState.cancelled => Icons.cancel_outlined,
    JobState.paused => Icons.pause_circle_outline,
    JobState.waiting => Icons.hourglass_empty,
    JobState.queued ||
    JobState.transcribed ||
    JobState.extracted ||
    JobState.rendered => Icons.schedule,
    _ => Icons.autorenew,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final job = view.job;
    final title = view.recordingTitle.isEmpty
        ? 'Untitled recording'
        : view.recordingTitle;
    final status = jobStatusLabel(job);
    final percent = (view.overallProgress() * 100).round();
    final showProgress = !job.state.isTerminal;
    final detail = <String>[
      if (showProgress) '$percent%',
      if (job.state.isActive || job.state.isResting) etaLabel(view.eta),
      if (view.queuePosition case final p?) 'Position $p in queue',
    ].join(' · ');
    final failed = job.state == JobState.failed;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    iconFor(job.state),
                    color: failed
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(status, style: theme.textTheme.bodyLarge),
              if (showProgress) ...[
                const SizedBox(height: AppSpacing.sm),
                Semantics(
                  label: '$status, $percent percent',
                  value: '$percent%',
                  child: LinearProgressIndicator(
                    value: view.overallProgress(),
                    minHeight: AppSpacing.xs,
                  ),
                ),
              ],
              if (detail.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(detail, style: theme.textTheme.bodyMedium),
              ],
              _Actions(
                state: job.state,
                onCancel: onCancel,
                onRetry: onRetry,
                onProcessNow: onProcessNow,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.state,
    this.onCancel,
    this.onRetry,
    this.onProcessNow,
  });

  final JobState state;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final VoidCallback? onProcessNow;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[
      if (state == JobState.queued && onProcessNow != null)
        TextButton(onPressed: onProcessNow, child: const Text('Process now')),
      if (!state.isTerminal && onCancel != null)
        TextButton(onPressed: onCancel, child: const Text('Cancel')),
      if ((state == JobState.failed || state == JobState.cancelled) &&
          onRetry != null)
        FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
    ];
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: buttons,
        ),
      ),
    );
  }
}
