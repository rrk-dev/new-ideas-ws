import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/routing/app_routes.dart';
import 'package:vaultvoice/features/models/data/model_management_providers.dart';
import 'package:vaultvoice/features/models/domain/model_management.dart';
import 'package:vaultvoice/features/models/presentation/model_download_actions.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_providers.dart';
import 'package:vaultvoice/features/pipeline/domain/job_progress.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_client.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_status_card.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_texts.dart';
import 'package:vaultvoice/features/profiles/presentation/profile_picker.dart';
import 'package:vaultvoice/features/recording/data/recording_screen_providers.dart';

/// Sends a command to the pipeline worker; a failure shows a snack bar.
Future<void> runJobCommand(
  BuildContext context,
  WidgetRef ref,
  Future<Result<void>> Function(PipelineClient client) command,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final message = context.l10n.jobCommandFailed;
  var ok = false;
  try {
    final client = await ref.read(pipelineClientProvider.future);
    ok = (await command(client)).isOk;
  } on Object {
    ok = false;
  }
  if (ok) return;
  messenger?.showSnackBar(SnackBar(content: Text(message)));
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
    final waitingForModel =
        state == JobState.waiting &&
        view.job.waitingReason == WaitingReason.modelMissing;
    final waitingForProfile =
        state == JobState.waiting &&
        view.job.waitingReason == WaitingReason.profileChoice;
    final entries = waitingForModel
        ? ref.watch(modelEntriesProvider).value
        : null;
    final type = modelTypeForStep(view.job.step);
    final download = _firstOrNull(
      entries,
      (e) => e.model.type == type && !e.isInstalled && e.recommended,
    );
    final installed = _firstOrNull(
      entries,
      (e) => e.model.type == type && e.usable,
    );
    return ProcessingStatusCard(
      view: view,
      onTap: onTap,
      missingModel: waitingForModel
          ? MissingModel(
              type: type,
              name: download?.model.displayName,
              installedName: installed?.model.displayName,
            )
          : null,
      onDownloadModel: download == null
          ? null
          : () => startModelDownload(context, ref, download.model),
      onUseInstalledModel: installed == null
          ? null
          : () => ref
                .read(modelManagerProvider)
                .setActive(installed.model.type, installed.model.id),
      onChooseModel: waitingForModel
          ? () => const ModelsSettingsRoute().push<void>(context)
          : null,
      onAcceptProfile: waitingForProfile
          ? () => runJobCommand(context, ref, (c) => c.resolveWaiting(id))
          : null,
      onChooseProfile: waitingForProfile
          ? () => _chooseProfile(context, ref, id, view.job.recordingId)
          : null,
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

/// Picks a profile for a recording whose automatic choice was unsure and
/// re-runs from extraction with it.
Future<void> _chooseProfile(
  BuildContext context,
  WidgetRef ref,
  String jobId,
  String recordingId,
) async {
  final choices = await ref.read(profileChoicesProvider.future);
  if (!context.mounted) return;
  final pick = await showProfilePicker(
    context,
    choices: choices,
    selectedId: null,
    includeAuto: false,
  );
  final profile = pick?.id;
  if (profile == null || !context.mounted) return;
  await ref
      .read(recordingsRepositoryProvider)
      .updateFields(
        recordingId,
        RecordingsCompanion(profileId: Value(profile)),
      );
  if (!context.mounted) return;
  await runJobCommand(
    context,
    ref,
    (c) => c.rerun(jobId, PipelineStepId.extract, profileId: profile),
  );
}

ModelEntry? _firstOrNull(
  List<ModelEntry>? entries,
  bool Function(ModelEntry) test,
) {
  for (final e in entries ?? const <ModelEntry>[]) {
    if (test(e)) return e;
  }
  return null;
}
