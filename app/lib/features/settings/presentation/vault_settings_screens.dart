import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/core/utils/ids.dart';
import 'package:vaultvoice/core/widgets/status_message.dart';
import 'package:vaultvoice/features/export/data/export_providers.dart';
import 'package:vaultvoice/features/export/domain/vault_folder.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

VaultTargetKind _kindOf(VaultPlatform p) => switch (p) {
  VaultPlatform.androidSaf => VaultTargetKind.saf,
  VaultPlatform.iosBookmark => VaultTargetKind.bookmark,
  VaultPlatform.appLocal => VaultTargetKind.appLocal,
};

VaultPlatform _platformOf(VaultTargetKind k) => switch (k) {
  VaultTargetKind.saf => VaultPlatform.androidSaf,
  VaultTargetKind.bookmark => VaultPlatform.iosBookmark,
  VaultTargetKind.appLocal => VaultPlatform.appLocal,
};

/// Vault folders notes are written to (Settings → Export). Adding opens the
/// system folder picker (EXP-03 SAF / EXP-04 bookmarks); removing releases
/// the OS grant. Folder names are user content: shown, never logged.
class VaultFoldersScreen extends ConsumerWidget {
  const VaultFoldersScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    void fail() => messenger.showSnackBar(
      SnackBar(content: Text(l10n.vaultFoldersAddFailed)),
    );
    try {
      final picked = await ref.read(vaultFolderAccessProvider).pick();
      switch (picked) {
        case Err():
          fail();
        case Ok(value: null):
          return; // cancelled
        case Ok(value: final VaultFolder folder):
          final saved = await ref
              .read(vaultRepositoryProvider)
              .upsertTarget(
                VaultTargetsCompanion.insert(
                  id: newUuidV4(),
                  platform: _platformOf(folder.kind),
                  displayName:
                      folder.displayName ?? l10n.vaultFolderDefaultName,
                  handle: folder.handle,
                  createdAt: ref.read(clockProvider).now(),
                ),
              );
          if (!saved.isOk) fail();
      }
    } on Object {
      fail();
    }
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    VaultTargetInfo target,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.vaultFoldersRemoveTitle),
        content: Text(context.l10n.vaultFoldersRemoveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.vaultFoldersRemove),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(vaultFolderAccessProvider)
          .release(
            VaultFolder(kind: _kindOf(target.platform), handle: target.handle),
          );
    } on Object {
      // No platform grant to release (e.g. app-local): still remove the row.
    }
    await ref.read(vaultRepositoryProvider).deleteTarget(target.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targets = ref.watch(vaultTargetsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsVaultFolders)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.create_new_folder_outlined),
        label: Text(context.l10n.vaultFoldersAdd),
      ),
      body: targets.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            semanticsLabel: context.l10n.commonLoading,
          ),
        ),
        error: (_, _) => StatusMessage(
          icon: Icons.error_outline,
          message: context.l10n.vaultFoldersLoadFailed,
          actionLabel: context.l10n.commonTryAgain,
          onAction: () => ref.invalidate(vaultTargetsProvider),
        ),
        data: (rows) => rows.isEmpty
            ? StatusMessage(
                icon: Icons.folder_open,
                message: context.l10n.vaultFoldersEmpty,
              )
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: AppSpacing.xl * 3),
                itemCount: rows.length,
                itemBuilder: (context, i) {
                  final t = rows[i];
                  return ListTile(
                    key: ValueKey('vault-${t.id}'),
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(t.name),
                    trailing: IconButton(
                      tooltip: context.l10n.vaultFoldersRemoveTooltip(t.name),
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _remove(context, ref, t),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// Routing rules, in evaluation order (Settings → Export). Read-only here;
/// the rule editor belongs to EXP-05.
class RoutingRulesScreen extends ConsumerWidget {
  const RoutingRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(routingRulesProvider);
    final names = {
      for (final t
          in ref.watch(vaultTargetsProvider).value ?? <VaultTargetInfo>[])
        t.id: t.name,
    };
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsRoutingRules)),
      body: rules.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            semanticsLabel: context.l10n.commonLoading,
          ),
        ),
        error: (_, _) => StatusMessage(
          icon: Icons.error_outline,
          message: context.l10n.routingRulesLoadFailed,
          actionLabel: context.l10n.commonTryAgain,
          onAction: () => ref.invalidate(routingRulesProvider),
        ),
        data: (rows) => rows.isEmpty
            ? StatusMessage(
                icon: Icons.alt_route,
                message: context.l10n.routingRulesEmpty,
              )
            : ListView.builder(
                itemCount: rows.length,
                itemBuilder: (context, i) {
                  final r = rows[i];
                  final target =
                      names[r.targetId] ?? context.l10n.vaultFolderDefaultName;
                  return ListTile(
                    key: ValueKey('rule-${r.id}'),
                    leading: CircleAvatar(child: Text('${i + 1}')),
                    title: Text(target),
                    subtitle: r.subPath.isEmpty ? null : Text(r.subPath),
                  );
                },
              ),
      ),
    );
  }
}
