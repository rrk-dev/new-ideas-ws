import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/diagnostics/diagnostics_providers.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/logging/logger.dart';
import 'package:vaultvoice/core/logging/redaction.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/core/routing/app_routes.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/core/utils/ids.dart';
import 'package:vaultvoice/core/widgets/status_message.dart';
import 'package:vaultvoice/features/export/data/export_providers.dart';
import 'package:vaultvoice/features/export/data/routing_providers.dart';
import 'package:vaultvoice/features/export/domain/routing_rule.dart';
import 'package:vaultvoice/features/export/domain/vault_folder.dart';
import 'package:vaultvoice/features/export/presentation/routing_rule_editor_screen.dart'
    show kNewRuleId;
import 'package:vaultvoice/features/licensing/data/licensing_providers.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/licensing/domain/paywall.dart';
import 'package:vaultvoice/features/licensing/presentation/feature_gate.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';
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

/// Outcome of [pickAndSaveVaultFolder].
sealed class VaultFolderPick {
  const VaultFolderPick();
}

/// The folder was granted and saved as a vault target.
final class VaultFolderPicked extends VaultFolderPick {
  const VaultFolderPicked(this.name);

  /// Folder name for the UI (user content: shown, never logged).
  final String name;
}

final class VaultFolderPickCancelled extends VaultFolderPick {
  const VaultFolderPickCancelled();
}

/// Picker unavailable, access refused or the row could not be saved.
final class VaultFolderPickFailed extends VaultFolderPick {
  const VaultFolderPickFailed();
}

/// Opens the system folder picker (EXP-03 SAF / EXP-04 bookmarks) and saves
/// the granted folder as a vault target. Shared by Settings → Vault folders
/// and onboarding (APP-01).
Future<VaultFolderPick> pickAndSaveVaultFolder(
  WidgetRef ref,
  AppLocalizations l10n,
) async {
  try {
    final picked = await ref.read(vaultFolderAccessProvider).pick();
    switch (picked) {
      case Err(:final failure):
        // Failure messages are content-free (type + reason, never a path).
        ref
            .read(loggerProvider)
            .failure('vault', failure, level: LogLevel.warning);
        return const VaultFolderPickFailed();
      case Ok(value: null):
        return const VaultFolderPickCancelled();
      case Ok(value: final VaultFolder folder):
        final name = folder.displayName ?? l10n.vaultFolderDefaultName;
        final id = newUuidV4();
        final saved = await ref
            .read(vaultRepositoryProvider)
            .upsertTarget(
              VaultTargetsCompanion.insert(
                id: id,
                platform: _platformOf(folder.kind),
                displayName: name,
                handle: folder.handle,
                createdAt: ref.read(clockProvider).now(),
              ),
            );
        if (saved case Err(:final failure)) {
          ref
              .read(loggerProvider)
              .failure('vault', failure, level: LogLevel.warning);
          return const VaultFolderPickFailed();
        }
        // The folder the user just chose is where notes go by default.
        await ref
            .read(settingsStoreProvider)
            .set(SettingKeys.exportDefaultTarget, id);
        return VaultFolderPicked(name);
    }
  } on Object catch (e) {
    ref
        .read(loggerProvider)
        .warning(
          'vault',
          'folder pick threw',
          fields: {'type': LogId(e.runtimeType.toString())},
        );
    return const VaultFolderPickFailed();
  }
}

/// Vault folders notes are written to (Settings → Export). Adding opens the
/// system folder picker (EXP-03 SAF / EXP-04 bookmarks); removing releases
/// the OS grant. Folder names are user content: shown, never logged.
class VaultFoldersScreen extends ConsumerWidget {
  const VaultFoldersScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    // LIC-01: Free has one vault target; more need `multiTarget` (EXP-05).
    final count = ref.read(vaultTargetsProvider).value?.length ?? 0;
    final max = ref.read(routingPolicyProvider).maxTargets;
    if (max != null &&
        count >= max &&
        !await ensureFeature(
          ref,
          Feature.multiTarget,
          from: PaywallEntryPoint.vaultTargets,
        )) {
      return;
    }
    // APP-01: the picker + save flow shared with onboarding.
    if (await pickAndSaveVaultFolder(ref, l10n) is VaultFolderPickFailed) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.vaultFoldersAddFailed)),
      );
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
    final defaultId = ref.watch(defaultVaultTargetIdProvider);
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
                  final max = ref.watch(routingPolicyProvider).maxTargets;
                  final disabled = max != null && i >= max;
                  final isDefault = t.id == defaultId;
                  return ListTile(
                    key: ValueKey('vault-${t.id}'),
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(t.name),
                    subtitle: disabled
                        ? Text(context.l10n.vaultTargetDisabled)
                        : isDefault
                        ? Text(context.l10n.vaultFoldersDefaultBadge)
                        : null,
                    onTap: () =>
                        VaultTargetOptionsRoute(targetId: t.id)
                            .push<void>(context),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isDefault && !disabled)
                          TextButton(
                            key: ValueKey('make-default-${t.id}'),
                            onPressed: () => ref
                                .read(settingsStoreProvider)
                                .set(SettingKeys.exportDefaultTarget, t.id),
                            child: Text(context.l10n.vaultFoldersMakeDefault),
                          ),
                        IconButton(
                          tooltip: context.l10n.vaultFoldersRemoveTooltip(
                            t.name,
                          ),
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _remove(context, ref, t),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// Routing rules, in evaluation order (Settings → Export): add, edit and
/// drag to reorder (EXP-05). Without `Feature.routingRules` the list is
/// read-only and the rules are not applied (LIC-01 downgrade rule).
class RoutingRulesScreen extends ConsumerWidget {
  const RoutingRulesScreen({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, String id) async {
    if (!await ensureFeature(
      ref,
      Feature.routingRules,
      from: PaywallEntryPoint.routingRules,
    )) {
      return;
    }
    if (context.mounted) {
      await RoutingRuleEditorRoute(ruleId: id).push<void>(context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final rules = ref.watch(routingRuleListProvider);
    final editable = ref.watch(featureProvider(Feature.routingRules));
    final names = {
      for (final t
          in ref.watch(vaultTargetsProvider).value ?? <VaultTargetInfo>[])
        t.id: t.name,
    };
    String summary(RoutingRule r) {
      final m = r.match;
      final conditions = [
        m.profileIds,
        m.tagsAny,
        m.keywordsAny,
        m.speakersAny,
        m.classificationAny,
      ].where((c) => c.isNotEmpty).length;
      return [
        if (conditions == 0)
          l.routingRuleEveryNote
        else
          l.routingRuleMatchesSome(conditions),
        if (r.subPath.isNotEmpty) r.subPath,
        if (r.mode == RuleMode.continueMatching) l.routingRuleContinues,
        if (!r.enabled) l.routingRuleOff,
      ].join(' · ');
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsRoutingRules)),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('rule-add'),
        onPressed: () => _open(context, ref, kNewRuleId),
        icon: const Icon(Icons.add),
        label: Text(l.routingRulesAdd),
      ),
      body: rules.when(
        loading: () => Center(
          child: CircularProgressIndicator(semanticsLabel: l.commonLoading),
        ),
        error: (_, _) => StatusMessage(
          icon: Icons.error_outline,
          message: l.routingRulesLoadFailed,
          actionLabel: l.commonTryAgain,
          onAction: () => ref.invalidate(routingRuleListProvider),
        ),
        data: (rows) => Column(
          children: [
            if (!editable)
              Padding(
                key: const ValueKey('rules-locked'),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(l.routingRulesLocked),
              ),
            Expanded(
              child: rows.isEmpty
                  ? StatusMessage(
                      icon: Icons.alt_route,
                      message: l.routingRulesEmpty,
                    )
                  : ReorderableListView.builder(
                      buildDefaultDragHandles: editable,
                      padding: const EdgeInsets.only(bottom: AppSpacing.xl * 3),
                      itemCount: rows.length,
                      onReorderItem: (from, to) {
                        if (!editable) return;
                        final list = [...rows];
                        final moved = list.removeAt(from);
                        list.insert(to, moved);
                        ref
                            .read(routingRulesStoreProvider)
                            .reorder(list)
                            .ignore();
                      },
                      itemBuilder: (context, i) {
                        final r = rows[i];
                        final target =
                            names[r.targetId] ?? l.vaultFolderDefaultName;
                        return ListTile(
                          key: ValueKey('rule-${r.id}'),
                          leading: CircleAvatar(child: Text('${i + 1}')),
                          title: Text(r.name ?? l.routingRuleTo(target)),
                          subtitle: Text(
                            r.name == null
                                ? summary(r)
                                : '${l.routingRuleTo(target)} · ${summary(r)}',
                          ),
                          onTap: () => _open(context, ref, r.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
