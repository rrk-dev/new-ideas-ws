import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/errors/result.dart';
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
    void fail() => messenger.showSnackBar(
      const SnackBar(content: Text('Could not add the folder.')),
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
                  displayName: folder.displayName ?? 'Vault folder',
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
        title: const Text('Remove this folder?'),
        content: const Text(
          'Notes already written stay in the folder. Routing rules that '
          'use it are removed too.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
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
      appBar: AppBar(title: const Text('Vault folders')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('Add folder'),
      ),
      body: targets.when(
        loading: () => const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Loading'),
        ),
        error: (_, _) => StatusMessage(
          icon: Icons.error_outline,
          message: 'Could not load your vault folders.',
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(vaultTargetsProvider),
        ),
        data: (rows) => rows.isEmpty
            ? const StatusMessage(
                icon: Icons.folder_open,
                message:
                    'No vault folders yet. Notes are saved in the app’s own '
                    'folder until you add one.',
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
                      tooltip: 'Remove ${t.name}',
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
      appBar: AppBar(title: const Text('Routing rules')),
      body: rules.when(
        loading: () => const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Loading'),
        ),
        error: (_, _) => StatusMessage(
          icon: Icons.error_outline,
          message: 'Could not load routing rules.',
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(routingRulesProvider),
        ),
        data: (rows) => rows.isEmpty
            ? const StatusMessage(
                icon: Icons.alt_route,
                message:
                    'No routing rules. Every note goes to your first vault '
                    'folder.',
              )
            : ListView.builder(
                itemCount: rows.length,
                itemBuilder: (context, i) {
                  final r = rows[i];
                  final target = names[r.targetId] ?? 'Vault folder';
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
