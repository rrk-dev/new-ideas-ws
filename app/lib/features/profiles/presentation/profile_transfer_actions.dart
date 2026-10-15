import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/app_info.dart';
import 'package:vaultvoice/core/diagnostics/diagnostics_providers.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/features/profiles/data/profile_transfer_providers.dart';
import 'package:vaultvoice/features/profiles/data/profile_transfer_service.dart';
import 'package:vaultvoice/features/profiles/domain/profile_bundle.dart';

void _snack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

/// "Import profile" (PRF-08): pick a `.vvprofile`, verify, confirm, install.
Future<void> importProfileBundle(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final bytes = await ref.read(profileBundlePickerProvider).pick();
  if (bytes == null || !context.mounted) return;
  final service = await ref.read(profileTransferServiceProvider.future);
  final check = await service.inspect(bytes);
  if (!context.mounted) return;
  switch (check) {
    case ImportRefused(:final reason, :final bundle):
      _snack(context, switch (reason) {
        ImportRefusal.invalidBundle => switch (bundle) {
          BundleRejection.untrustedKey ||
          BundleRejection.unsignedManaged => l.profilesImportUntrusted,
          BundleRejection.badSignature ||
          BundleRejection.hashMismatch => l.profilesImportTampered,
          _ => l.profilesImportInvalid,
        },
        ImportRefusal.idTaken => l.profilesImportIdTaken,
        ImportRefusal.olderVersion => l.profilesImportOlder,
        ImportRefusal.alreadyInstalled => l.profilesImportSame,
        ImportRefusal.notEntitled => l.profilesImportNotEntitled,
      });
    case final ImportReady ready:
      final profile = ready.bundle.profile;
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(l.profilesImportTitle(profile.name)),
          content: Text(
            [
              if (ready.installedVersion case final v?)
                l.profilesImportUpdate(v, profile.version)
              else
                l.profilesImportNew,
              if (ready.bundle.managed) l.profilesImportManaged,
            ].join('\n\n'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(l.profileEditorCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(l.profilesImportConfirm),
            ),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
      final installed = await service.install(ready);
      if (!context.mounted) return;
      switch (installed) {
        case Ok(:final value):
          _snack(context, l.profilesImported);
          await context.push('/profiles/${value.id}');
        case Err():
          _snack(context, l.profilesImportFailed);
      }
  }
}

/// "Export profile" (PRF-08): bundle → app cache file → OS share sheet.
Future<void> exportProfileBundle(
  BuildContext context,
  WidgetRef ref,
  String profileId,
) async {
  final l = context.l10n;
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  final service = await ref.read(profileTransferServiceProvider.future);
  final bytes = await service.export(profileId, createdBy: kAppName);
  if (bytes case Err()) {
    if (context.mounted) _snack(context, l.profileEditorExportFailed);
    return;
  }
  final dir = await ref.read(profileExportDirProvider.future);
  final file = File(p.join(dir.path, '$profileId.$kBundleExtension'));
  await file.writeAsBytes(bytes.valueOrNull!, flush: true);
  await ref
      .read(shareServiceProvider)
      .shareFile(file.path, mimeType: kBundleMime, origin: origin);
}
