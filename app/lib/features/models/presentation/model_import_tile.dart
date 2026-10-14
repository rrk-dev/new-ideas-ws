import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
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
    title: Text(context.l10n.modelImportTitle),
    subtitle: Text(context.l10n.modelImportSubtitle),
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
    final l10n = context.l10n;
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
            result.isOk
                ? l10n.modelImportInstalled
                : _message(l10n, result.failureOrNull!),
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
          title: Text(context.l10n.modelImportUnsignedTitle),
          content: Text(context.l10n.modelImportUnsignedBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.modelImportAnyway),
            ),
          ],
        ),
      ) ??
      false;

  static String _message(AppLocalizations l, Failure f) => switch (f) {
    ModelImportFailure(reason: ModelImportRejection.unknownModel) =>
      l.modelImportErrorUnknownModel,
    ModelImportFailure(reason: ModelImportRejection.missingFiles) =>
      l.modelImportErrorMissingFiles,
    ModelImportFailure(reason: ModelImportRejection.entitlementRequired) =>
      l.modelImportErrorEntitlement,
    ModelImportFailure(reason: ModelImportRejection.invalidGguf) =>
      l.modelImportErrorInvalidGguf,
    ModelImportFailure() => l.modelImportErrorNotSingleModel,
    CatalogFailure() => l.modelImportErrorSignature,
    ModelIntegrityFailure() => l.modelImportErrorIntegrity,
    ModelDownloadFailure(block: ModelDownloadBlock.insufficientSpace) =>
      l.modelImportErrorNoSpace,
    _ => l.modelImportErrorGeneric,
  };

  static Future<void> _deleteQuietly(File f) async {
    try {
      await f.delete();
    } on FileSystemException {
      // Best effort: cache files are cleared by the OS too.
    }
  }
}
