import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/routing/app_routes.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/features/pipeline/domain/job_progress.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_providers.dart';

/// Counts for the global queue indicator.
class QueueSummary {
  const QueueSummary({
    required this.inPipeline,
    required this.failed,
    this.running,
  });

  factory QueueSummary.of(List<JobProgressView> views) {
    JobProgressView? running;
    var inPipeline = 0;
    var failed = 0;
    for (final v in views) {
      if (isInPipeline(v.job)) inPipeline++;
      if (v.job.state == JobState.failed) failed++;
      if (running == null && v.job.state.isActive) running = v;
    }
    return QueueSummary(
      inPipeline: inPipeline,
      failed: failed,
      running: running,
    );
  }

  final int inPipeline;
  final int failed;
  final JobProgressView? running;

  bool get isEmpty => inPipeline == 0 && failed == 0;

  String label(AppLocalizations l) => [
    if (inPipeline > 0) l.queueProcessing(inPipeline),
    if (failed > 0) l.queueNeedsAttention(failed),
  ].join(' · ');
}

/// Global queue indicator above the tab bar; hidden when nothing is being
/// processed. Tap opens the processing queue.
class ProcessingQueueIndicator extends ConsumerWidget {
  const ProcessingQueueIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final views = ref.watch(processingViewsProvider).value;
    if (views == null) return const SizedBox.shrink();
    final summary = QueueSummary.of(views);
    if (summary.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final running = summary.running;
    final label = summary.label(context.l10n);
    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: InkWell(
        onTap: () => const ProcessingQueueRoute().push<void>(context),
        child: Semantics(
          button: true,
          label: context.l10n.queueIndicatorSemantics(label),
          excludeSemantics: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kMinTapTarget),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        summary.failed > 0
                            ? Icons.error_outline
                            : Icons.autorenew,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ],
                  ),
                ),
                if (running != null)
                  LinearProgressIndicator(
                    value: running.overallProgress(),
                    minHeight: 2,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
