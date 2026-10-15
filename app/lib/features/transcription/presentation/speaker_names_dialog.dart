import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';

/// STT-05: name the speakers of one recording ("Speaker 2" → "Priya").
/// Names are stored per recording only (no voiceprints) and flow into the
/// exported note.
class SpeakerNamesDialog extends ConsumerStatefulWidget {
  const SpeakerNamesDialog({required this.recordingId, super.key});

  final String recordingId;

  @override
  ConsumerState<SpeakerNamesDialog> createState() => _SpeakerNamesDialogState();
}

class _SpeakerNamesDialogState extends ConsumerState<SpeakerNamesDialog> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save(Map<String, String?> original) async {
    final repo = ref.read(recordingsRepositoryProvider);
    for (final e in _controllers.entries) {
      if (e.value.text.trim() == (original[e.key] ?? '')) continue;
      await repo.renameSpeaker(widget.recordingId, e.key, e.value.text);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final repo = ref.watch(recordingsRepositoryProvider);
    return StreamBuilder(
      stream: repo.watchSpeakers(widget.recordingId),
      builder: (context, snap) {
        final rows = snap.data ?? const [];
        final original = {for (final r in rows) r.label: r.displayName};
        for (final r in rows) {
          _controllers.putIfAbsent(
            r.label,
            () => TextEditingController(text: r.displayName ?? ''),
          );
        }
        return AlertDialog(
          title: Text(l.transcriptSpeakers),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final r in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: _controllers[r.label],
                      decoration: InputDecoration(
                        labelText: l.transcriptSpeakerNameHint(r.label),
                      ),
                    ),
                  ),
                Text(l.transcriptSpeakersNote),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l.commonCancel),
            ),
            FilledButton(
              onPressed: rows.isEmpty ? null : () => unawaited(_save(original)),
              child: Text(l.commonSave),
            ),
          ],
        );
      },
    );
  }
}
