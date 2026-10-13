import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/features/models/data/model_import_providers.dart';

/// Settings entry: install a model from local files with no network
/// (MDL-04). MDL-03's model screen can reuse it.
class ModelImportTile extends ConsumerStatefulWidget {
  const ModelImportTile({super.key});

  @override
  ConsumerState<ModelImportTile> createState() => _ModelImportTileState();
}

class _ModelImportTileState extends ConsumerState<ModelImportTile> {
  bool _busy = false;

  /// On iOS/Android the picker hands back app-private copies (safe to move
  /// or delete); elsewhere it returns the user's original files.
  static bool get _pickerReturnsCopies => Platform.isAndroid || Platform.isIOS;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.file_open_outlined),
    title: const Text('Import model from file'),
    subtitle: const Text(
      'Select the model file with its signed manifest (.json and .sig). '
      'Works without a network connection.',
    ),
    trailing: _busy
        ? const SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : null,
    enabled: !_busy,
    onTap: _import,
  );

  Future<void> _import() async {
    final messenger = ScaffoldMessenger.of(context);
    final files = await ref.read(modelFilePickerProvider).pick();
    if (files.isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      final importer = await ref.read(modelImporterProvider.future);
      final unsigned = !files.any(
        (f) => p.basename(f.path).toLowerCase().endsWith('.sig'),
      );
      if (unsigned && await importer.customModelsEnabled()) {
        if (!mounted || !await _confirmCustom()) return;
      }
      final result = await importer.importPicked(
        files,
        moveSource: _pickerReturnsCopies,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.isOk ? 'Model installed' : _message(result.failureOrNull!),
          ),
        ),
      );
    } finally {
      if (_pickerReturnsCopies) {
        for (final f in files) {
          // Picker copies that were not moved into the models folder.
          if (f.existsSync()) await _deleteQuietly(f);
        }
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmCustom() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unsigned custom model'),
          content: const Text(
            'This file is not a VaultVoice-signed model. Only import GGUF '
            'files from a source you trust: a malformed or malicious model '
            'file can crash the app. Its license is your responsibility.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Import anyway'),
            ),
          ],
        ),
      ) ??
      false;

  static String _message(Failure f) => switch (f) {
    ModelImportFailure(reason: ModelImportRejection.unknownModel) =>
      'Not a signed VaultVoice model. Select the model file together with '
          'its .json and .sig files.',
    ModelImportFailure(reason: ModelImportRejection.missingFiles) =>
      'Select exactly one model file plus its .json and .sig files.',
    ModelImportFailure(reason: ModelImportRejection.entitlementRequired) =>
      'Custom models require VaultVoice Pro.',
    ModelImportFailure(reason: ModelImportRejection.invalidGguf) =>
      'This file is not a valid GGUF model.',
    ModelImportFailure() => 'The manifest is not a single-model manifest.',
    CatalogFailure() => 'The manifest signature is not valid.',
    ModelIntegrityFailure() =>
      'The model file does not match its manifest (size or checksum).',
    ModelDownloadFailure(block: ModelDownloadBlock.insufficientSpace) =>
      'Not enough free space.',
    _ => 'Import failed.',
  };

  static Future<void> _deleteQuietly(File f) async {
    try {
      await f.delete();
    } on FileSystemException {
      // Best effort: cache files are cleared by the OS too.
    }
  }
}
