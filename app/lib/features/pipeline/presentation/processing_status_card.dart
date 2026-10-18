import 'package:flutter/material.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
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
    this.missingModel,
    this.onDownloadModel,
    this.onUseInstalledModel,
    this.onChooseModel,
    this.onAcceptProfile,
    this.onChooseProfile,
    super.key,
  });

  /// What a job waiting for a model needs (named in the status line).
  final MissingModel? missingModel;

  /// Starts downloading [MissingModel.name].
  final VoidCallback? onDownloadModel;

  /// Switches to the installed [MissingModel.installedName].
  final VoidCallback? onUseInstalledModel;

  /// Opens the models screen.
  final VoidCallback? onChooseModel;

  /// A job waiting for a profile: continue with the suggested one.
  final VoidCallback? onAcceptProfile;

  /// A job waiting for a profile: pick another one.
  final VoidCallback? onChooseProfile;

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
    final l10n = context.l10n;
    final job = view.job;
    final title = view.recordingTitle.isEmpty
        ? l10n.untitledRecording
        : view.recordingTitle;
    final status = jobStatusLabel(l10n, job, missingModel: missingModel);
    final percent = (view.overallProgress() * 100).round();
    final showProgress = !job.state.isTerminal;
    final detail = <String>[
      if (showProgress) l10n.jobPercent(percent),
      if (job.state.isActive || job.state.isResting) etaLabel(l10n, view.eta),
      if (view.queuePosition case final p?) l10n.jobQueuePosition(p),
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
                  container: true,
                  label: l10n.jobProgressSemantics(status, percent),
                  value: l10n.jobPercent(percent),
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
              if (job.state == JobState.waiting &&
                  job.waitingReason == WaitingReason.profileChoice)
                _ProfileActions(
                  onAccept: onAcceptProfile,
                  onChoose: onChooseProfile,
                ),
              if (job.state == JobState.waiting &&
                  job.waitingReason == WaitingReason.modelMissing)
                _ModelActions(
                  model: missingModel,
                  onDownload: onDownloadModel,
                  onUseInstalled: onUseInstalledModel,
                  onChoose: onChooseModel,
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
        TextButton(
          onPressed: onProcessNow,
          child: Text(context.l10n.jobProcessNow),
        ),
      if (!state.isTerminal && onCancel != null)
        TextButton(onPressed: onCancel, child: Text(context.l10n.commonCancel)),
      if ((state == JobState.failed || state == JobState.cancelled) &&
          onRetry != null)
        FilledButton.tonal(
          onPressed: onRetry,
          child: Text(context.l10n.commonRetry),
        ),
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

class _ProfileActions extends StatelessWidget {
  const _ProfileActions({this.onAccept, this.onChoose});

  final VoidCallback? onAccept;
  final VoidCallback? onChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            if (onChoose != null)
              TextButton(
                key: const ValueKey('job-profile-choose'),
                onPressed: onChoose,
                child: Text(l10n.jobProfileChoose),
              ),
            if (onAccept != null)
              FilledButton.tonal(
                key: const ValueKey('job-profile-accept'),
                onPressed: onAccept,
                child: Text(l10n.jobProfileUseSuggested),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModelActions extends StatelessWidget {
  const _ModelActions({
    required this.model,
    this.onDownload,
    this.onUseInstalled,
    this.onChoose,
  });

  final MissingModel? model;
  final VoidCallback? onDownload;
  final VoidCallback? onUseInstalled;
  final VoidCallback? onChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final m = model;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            if (m?.installedName != null && onUseInstalled != null)
              FilledButton.tonal(
                key: const ValueKey('job-model-use'),
                onPressed: onUseInstalled,
                child: Text(l10n.jobModelUse(m!.installedName!)),
              ),
            if (m?.name != null && onDownload != null)
              FilledButton.tonal(
                key: const ValueKey('job-model-download'),
                onPressed: onDownload,
                child: Text(l10n.jobModelDownload(m!.name!)),
              ),
            if (onChoose != null)
              TextButton(
                key: const ValueKey('job-model-choose'),
                onPressed: onChoose,
                child: Text(l10n.jobModelChoose),
              ),
          ],
        ),
      ),
    );
  }
}
