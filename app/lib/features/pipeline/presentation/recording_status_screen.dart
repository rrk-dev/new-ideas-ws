import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/core/widgets/status_message.dart';
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
      appBar: AppBar(title: Text(context.l10n.processingTitle)),
      body: views.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            semanticsLabel: context.l10n.commonLoading,
          ),
        ),
        error: (_, _) => StatusMessage(
          icon: Icons.error_outline,
          message: context.l10n.processingStatusLoadFailed,
          actionLabel: context.l10n.commonTryAgain,
          onAction: () => ref.invalidate(processingViewsProvider),
        ),
        data: (all) {
          final view = currentViewFor(all, recordingId);
          if (view == null) {
            return StatusMessage(
              icon: Icons.hourglass_empty,
              message: context.l10n.processingNotProcessed,
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
