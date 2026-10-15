import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/features/recording/data/recording_screen_providers.dart';
import 'package:vaultvoice/features/recording/data/recording_session_service.dart';
import 'package:vaultvoice/features/recording/domain/recording_controller.dart';
import 'package:vaultvoice/features/recording/domain/recording_session.dart';

/// Profile (or Auto, PRF-06) and destination (or Auto = routing rules)
/// pickers, used before recording and in the details sheet afterwards.
class RecordingSetupPickers extends ConsumerWidget {
  const RecordingSetupPickers({
    required this.setup,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final RecordingSetup setup;
  final bool enabled;
  final ValueChanged<RecordingSetup> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profiles = ref.watch(profileChoicesProvider).value ?? const [];
    final targets = ref.watch(destinationChoicesProvider).value ?? const [];
    // A choice that disappeared (profile deleted) falls back to Auto.
    final profileId = profiles.any((p) => p.id == setup.profileId)
        ? setup.profileId
        : null;
    final targetId = targets.any((t) => t.id == setup.destinationId)
        ? setup.destinationId
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String?>(
          key: const ValueKey('record-profile'),
          initialValue: profileId,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.recordProfileLabel),
          items: [
            DropdownMenuItem(child: Text(l10n.recordAuto)),
            for (final p in profiles)
              DropdownMenuItem(value: p.id, child: Text(p.name)),
          ],
          onChanged: enabled
              ? (v) => onChanged(setup.copyWith(profileId: () => v))
              : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String?>(
          key: const ValueKey('record-destination'),
          initialValue: targetId,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.recordDestinationLabel),
          items: [
            DropdownMenuItem(child: Text(l10n.recordAuto)),
            for (final t in targets)
              DropdownMenuItem(value: t.id, child: Text(t.name)),
          ],
          onChanged: enabled
              ? (v) => onChanged(setup.copyWith(destinationId: () => v))
              : null,
        ),
      ],
    );
  }
}

/// After a recording stops: title, tags, and a last chance to change the
/// profile and destination. "Later" keeps everything as it is.
class RecordingDetailsSheet extends ConsumerStatefulWidget {
  const RecordingDetailsSheet({
    required this.recordingId,
    required this.initialSetup,
    this.stopCause,
    this.queued = false,
    super.key,
  });

  final String recordingId;

  /// Already queued for processing (auto-process on); otherwise the sheet
  /// offers "Process now".
  final bool queued;
  final RecordingSetup initialSetup;
  final StopCause? stopCause;

  @override
  ConsumerState<RecordingDetailsSheet> createState() =>
      _RecordingDetailsSheetState();
}

class _RecordingDetailsSheetState extends ConsumerState<RecordingDetailsSheet> {
  final _title = TextEditingController();
  final _tags = TextEditingController();
  late RecordingSetup _setup = widget.initialSetup;
  bool _saving = false;
  late bool _queued = widget.queued;

  @override
  void dispose() {
    _title.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref
        .read(recordingSessionServiceProvider)
        .saveDetails(
          widget.recordingId,
          title: _title.text,
          tags: RecordingSessionService.parseTags(_tags.text),
          setup: _setup,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final why = switch (widget.stopCause) {
      StopCause.silence => l10n.recordStoppedSilence,
      StopCause.maxDuration => l10n.recordStoppedMax,
      StopCause.lowStorage => l10n.recordStoppedStorage,
      StopCause.user || null => null,
    };
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.detailsTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (why != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(why, key: const ValueKey('details-stop-cause')),
            ],
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey('details-title'),
              controller: _title,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: l10n.detailsTitleField),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const ValueKey('details-tags'),
              controller: _tags,
              decoration: InputDecoration(
                labelText: l10n.detailsTagsField,
                helperText: l10n.detailsTagsHint,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            RecordingSetupPickers(
              setup: _setup,
              onChanged: (s) => setState(() => _setup = s),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_queued)
              Text(l10n.detailsQueued, key: const ValueKey('details-queued'))
            else
              OutlinedButton.icon(
                key: const ValueKey('details-process-now'),
                icon: const Icon(Icons.play_arrow),
                label: Text(l10n.detailsProcessNow),
                onPressed: () async {
                  final ok = await ref
                      .read(recordingSessionServiceProvider)
                      .processNow(widget.recordingId);
                  if (mounted) setState(() => _queued = ok);
                },
              ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: Text(l10n.detailsSkip),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  key: const ValueKey('details-save'),
                  onPressed: _saving ? null : _save,
                  child: Text(l10n.detailsSave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
