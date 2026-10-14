import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/features/recording/data/recording_providers.dart';
import 'package:vaultvoice/features/recording/data/recording_recovery.dart';

/// Asks once per recovered recording (AUD-07):
/// "Recovered recording from <time> — process now?" with **Later** and
/// **Process now** (queues it at the front of the pipeline). Wraps the
/// launch screen; recovery itself runs in [recoveredRecordingsProvider].
class RecoveredRecordingsPrompt extends ConsumerStatefulWidget {
  const RecoveredRecordingsPrompt({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<RecoveredRecordingsPrompt> createState() =>
      _RecoveredRecordingsPromptState();
}

class _RecoveredRecordingsPromptState
    extends ConsumerState<RecoveredRecordingsPrompt> {
  /// Recording ids already asked about in this process.
  static final _asked = <String>{};

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  Future<void> _run() async {
    List<RecoveredRecording> recovered;
    try {
      recovered = await ref.read(recoveredRecordingsProvider.future);
    } on Object {
      return; // Storage unavailable: nothing to offer.
    }
    for (final r in recovered) {
      if (!mounted) return;
      if (!_asked.add(r.recordingId)) continue;
      final process = await showDialog<bool>(
        context: context,
        builder: (context) => _RecoveredDialog(recording: r),
      );
      if (process ?? false) {
        await ref.read(recoveredRecordingProcessorProvider)(r.recordingId);
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Prompt text, e.g. `Recovered recording from Oct 13, 2026 9:41 AM — process
/// now?`.
String recoveredPromptText(BuildContext context, DateTime startedAt) {
  final l = MaterialLocalizations.of(context);
  final local = startedAt.toLocal();
  final when =
      '${l.formatShortDate(local)} '
      '${l.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  return 'Recovered recording from $when — process now?';
}

class _RecoveredDialog extends StatelessWidget {
  const _RecoveredDialog({required this.recording});

  final RecoveredRecording recording;

  @override
  Widget build(BuildContext context) {
    final minutes = recording.duration.inMinutes;
    final seconds = recording.duration.inSeconds % 60;
    return AlertDialog(
      title: const Text('Recording recovered'),
      content: Text(
        '${recoveredPromptText(context, recording.startedAt)}\n'
        'Length: ${minutes}m ${seconds.toString().padLeft(2, '0')}s. '
        'The app was closed while recording; the audio captured up to '
        'then was kept.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Later'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Process now'),
        ),
      ],
    );
  }
}
