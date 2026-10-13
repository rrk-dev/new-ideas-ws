import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_providers.dart';
import 'package:vaultvoice/features/pipeline/domain/job_progress.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_client.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_status_card.dart';

/// Sends a command to the pipeline worker; a failure shows a snack bar.
Future<void> runJobCommand(
  BuildContext context,
  WidgetRef ref,
  Future<Result<void>> Function(PipelineClient client) command,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  var ok = false;
  try {
    final client = await ref.read(pipelineClientProvider.future);
    ok = (await command(client)).isOk;
  } on Object {
    ok = false;
  }
  if (ok) return;
  messenger?.showSnackBar(
    const SnackBar(content: Text('That did not work. Please try again.')),
  );
}

/// [ProcessingStatusCard] wired to the pipeline commands.
class ConnectedProcessingStatusCard extends ConsumerWidget {
  const ConnectedProcessingStatusCard({
    required this.view,
    this.onTap,
    super.key,
  });

  final JobProgressView view;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = view.job.id;
    final state = view.job.state;
    return ProcessingStatusCard(
      view: view,
      onTap: onTap,
      onCancel: state.isTerminal
          ? null
          : () => runJobCommand(context, ref, (c) => c.cancel(id)),
      onRetry: state == JobState.failed || state == JobState.cancelled
          ? () => runJobCommand(context, ref, (c) => c.retry(id))
          : null,
      onProcessNow: state == JobState.queued
          ? () => runJobCommand(context, ref, (c) => c.processNow(id))
          : null,
    );
  }
}
