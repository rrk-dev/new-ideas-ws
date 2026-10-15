import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/features/recording/data/audio_import_providers.dart';
import 'package:vaultvoice/features/recording/data/pigeon_audio_decoder.dart';
import 'package:vaultvoice/features/recording/domain/audio_import.dart';

/// The rights/consent attestation every import requires (SEC-09, AUD-06).
/// Import stays disabled until the box is ticked. Returns true on Import.
class ImportAttestationDialog extends StatefulWidget {
  const ImportAttestationDialog({super.key});

  @override
  State<ImportAttestationDialog> createState() =>
      _ImportAttestationDialogState();
}

class _ImportAttestationDialogState extends State<ImportAttestationDialog> {
  bool _attested = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.importAttestationTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.importAttestationBody),
          CheckboxListTile(
            key: const ValueKey('import-attest'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _attested,
            onChanged: (v) => setState(() => _attested = v ?? false),
            title: Text(l10n.importAttestationCheckbox),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('import-confirm'),
          onPressed: _attested ? () => Navigator.of(context).pop(true) : null,
          child: Text(l10n.importAction),
        ),
      ],
    );
  }
}

/// User-facing text for an [ImportOutcome].
String importOutcomeText(AppLocalizations l10n, ImportOutcome outcome) =>
    switch (outcome) {
      ImportDone() => l10n.importDone,
      ImportUnsupported(:final format?) => l10n.importUnsupportedFormat(
        format.id,
      ),
      ImportUnsupported() => l10n.importUnsupportedUnknown,
      ImportNoAudio() => l10n.importNoAudio,
      ImportFailed() => l10n.importFailed,
    };

/// Pick-or-share → (unsupported? say so) → attestation → import → snackbar.
/// [deleteSource]: [path] is a private copy the app owns (share inbox).
Future<ImportOutcome?> runAudioImport(
  BuildContext context,
  WidgetRef ref, {
  required String path,
  String? extension,
  DateTime? sourceDate,
  bool deleteSource = false,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = context.l10n;
  final service = await ref.read(audioImportServiceProvider.future);
  void show(String text) {
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  final ext = extension ?? p.extension(path);
  final unsupported = service.unsupportedFormat(ext);
  if (unsupported != null) {
    if (deleteSource) _deleteQuietly(path);
    final outcome = ImportUnsupported(unsupported);
    show(importOutcomeText(l10n, outcome));
    return outcome;
  }
  if (!context.mounted) return null;
  final attested = await showDialog<bool>(
    context: context,
    builder: (_) => const ImportAttestationDialog(),
  );
  if (attested != true) {
    if (deleteSource) _deleteQuietly(path);
    return null;
  }
  show(l10n.importInProgress);
  final outcome = await service.importFile(
    path,
    attestedAt: ref.read(clockProvider).now(),
    extension: extension,
    sourceDate: sourceDate,
    deleteSource: deleteSource,
  );
  show(importOutcomeText(l10n, outcome));
  return outcome;
}

void _deleteQuietly(String path) {
  try {
    final f = File(path);
    if (f.existsSync()) f.deleteSync();
  } on FileSystemException {
    // OS cache dir: cleaned eventually.
  }
}

/// App-bar action: pick an audio file and import it.
class ImportAudioButton extends ConsumerWidget {
  const ImportAudioButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    key: const ValueKey('import-audio'),
    tooltip: context.l10n.importAudioTooltip,
    icon: const Icon(Icons.file_open_outlined),
    onPressed: () async {
      final path = await ref.read(audioFilePickerProvider).pick();
      if (path == null || !context.mounted) return;
      await runAudioImport(context, ref, path: path, deleteSource: true);
    },
  );
}

/// Offers files shared into the app (share sheet / "Open in") for import,
/// one after the other, each behind the attestation. Wraps the Record tab.
class SharedAudioImportListener extends ConsumerStatefulWidget {
  const SharedAudioImportListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SharedAudioImportListener> createState() =>
      _SharedAudioImportListenerState();
}

class _SharedAudioImportListenerState
    extends ConsumerState<SharedAudioImportListener> {
  StreamSubscription<void>? _sub;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final inbox = ref.read(sharedAudioInboxProvider);
    _sub = inbox.changes.listen((_) => unawaited(_drain(inbox)));
    unawaited(_drain(inbox));
  }

  Future<void> _drain(SharedAudioInbox inbox) async {
    if (_busy) return;
    _busy = true;
    try {
      while (mounted) {
        final files = await inbox.take();
        if (files.isEmpty) break;
        for (final f in files) {
          if (!mounted) return;
          await runAudioImport(
            context,
            ref,
            path: f.path,
            extension: f.extension,
            sourceDate: f.sourceDate,
            deleteSource: true,
          );
        }
      }
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
