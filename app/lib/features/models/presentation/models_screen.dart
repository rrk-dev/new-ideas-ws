import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/core/widgets/status_message.dart';
import 'package:vaultvoice/features/licensing/data/licensing_providers.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/licensing/domain/feature_access.dart';
import 'package:vaultvoice/features/licensing/domain/paywall.dart';
import 'package:vaultvoice/features/licensing/presentation/feature_gate.dart';
import 'package:vaultvoice/features/models/data/download_providers.dart';
import 'package:vaultvoice/features/models/data/model_import_providers.dart';
import 'package:vaultvoice/features/models/data/model_importer.dart';
import 'package:vaultvoice/features/models/data/model_management_providers.dart';
import 'package:vaultvoice/features/models/data/model_state_providers.dart';
import 'package:vaultvoice/features/models/domain/download_state.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';
import 'package:vaultvoice/features/models/domain/model_management.dart';
import 'package:vaultvoice/features/models/presentation/model_download_actions.dart';
import 'package:vaultvoice/features/models/presentation/model_import_tile.dart';
import 'package:vaultvoice/features/models/presentation/model_texts.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

/// Settings › Models (MDL-03): installed and available models by type with
/// size, plan badge, device fit and status; download / pause / delete /
/// use-this-model; storage totals; update notice; offline import.
class ModelsScreen extends ConsumerWidget {
  const ModelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final entries = ref.watch(modelEntriesProvider);
    final offline = ref.watch(networkDisabledProvider).value ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsModels),
        actions: [
          if (!offline)
            IconButton(
              key: const ValueKey('models-check-updates'),
              tooltip: l10n.modelsCheckUpdates,
              icon: const Icon(Icons.refresh),
              onPressed: () => _checkUpdates(context, ref),
            ),
        ],
      ),
      body: entries.when(
        loading: () => Center(
          child: CircularProgressIndicator(semanticsLabel: l10n.commonLoading),
        ),
        error: (_, _) => StatusMessage(
          icon: Icons.error_outline,
          message: l10n.modelsLoadFailed,
          actionLabel: l10n.commonTryAgain,
          onAction: () => ref.invalidate(modelEntriesProvider),
        ),
        data: (list) => _ModelList(entries: list, offline: offline),
      ),
    );
  }

  Future<void> _checkUpdates(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final result = await ref.read(activeCatalogProvider.notifier).refresh();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.isOk ? l10n.modelsCatalogChecked : l10n.modelsCatalogFailed,
        ),
      ),
    );
  }
}

class _ModelList extends ConsumerWidget {
  const _ModelList({required this.entries, required this.offline});

  final List<ModelEntry> entries;
  final bool offline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final updates = entries.where((e) => e.updateAvailable).length;
    final progress =
        ref.watch(modelDownloadProgressProvider).value ??
        const <String, DownloadProgress>{};
    final types = [
      for (final t in ModelType.values)
        if (entries.any((e) => e.model.type == t)) t,
    ];
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        const _StorageCard(),
        if (offline)
          _Notice(
            key: const ValueKey('models-offline'),
            icon: Icons.cloud_off_outlined,
            text: l10n.modelsOfflineNotice,
          )
        else if (updates > 0)
          _Notice(
            key: const ValueKey('models-updates'),
            icon: Icons.system_update_alt,
            text: l10n.modelsUpdatesAvailable(updates),
          ),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(l10n.modelsEmpty),
          ),
        for (final type in types) ...[
          _SectionHeader(ModelTexts.type(l10n, type)),
          for (final e in entries)
            if (e.model.type == type)
              _ModelCard(
                entry: e,
                entries: entries,
                progress: progress[e.model.id],
                offline: offline,
              ),
        ],
        _SectionHeader(l10n.modelsImportSection),
        const ModelImportTile(),
        const _CustomModelsToggle(),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.lg,
      AppSpacing.md,
      AppSpacing.sm,
    ),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, color: scheme.onSecondaryContainer),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: scheme.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StorageCard extends ConsumerWidget {
  const _StorageCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final usage = ref.watch(storageUsageProvider).value;
    String size(int? bytes) => bytes == null ? '–' : formatBytes(l10n, bytes);
    Widget row(String label, int? bytes) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(size(bytes)),
        ],
      ),
    );
    return Card(
      key: const ValueKey('models-storage'),
      margin: const EdgeInsets.all(AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.modelsStorageTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            row(l10n.modelsStorageModels, usage?.modelBytes),
            row(l10n.modelsStorageAudio, usage?.audioBytes),
            row(l10n.modelsStorageTranscripts, usage?.transcriptBytes),
          ],
        ),
      ),
    );
  }
}

class _ModelCard extends ConsumerWidget {
  const _ModelCard({
    required this.entry,
    required this.entries,
    required this.progress,
    required this.offline,
  });

  final ModelEntry entry;
  final List<ModelEntry> entries;
  final DownloadProgress? progress;
  final bool offline;

  CatalogModel get _model => entry.model;

  bool get _running => switch (progress?.phase) {
    DownloadPhase.checking ||
    DownloadPhase.downloading ||
    DownloadPhase.retrying ||
    DownloadPhase.verifying ||
    DownloadPhase.installing => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final p = progress;
    final status = ModelTexts.progress(l10n, p);
    final badges = <String>[
      if (_model.tier == ModelTier.pro) l10n.modelBadgePro,
      if (_model.tier == ModelTier.enterprise) l10n.modelBadgeEnterprise,
      if (entry.active) l10n.modelBadgeActive,
      if (entry.recommended) l10n.modelBadgeRecommended,
      if (entry.updateAvailable) l10n.modelBadgeUpdate,
    ];
    return Card(
      key: ValueKey('model-${_model.id}'),
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(ModelTexts.icon(_model.type)),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    _model.displayName,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (entry.isInstalled)
                  Icon(
                    Icons.check_circle_outline,
                    semanticLabel: l10n.modelStatusInstalled,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.modelSizeVersion(
                formatBytes(l10n, _model.size),
                entry.installed?.version ?? _model.version,
              ),
            ),
            Text(
              entry.isInstalled
                  ? (status ?? l10n.modelStatusInstalled)
                  : (status ?? l10n.modelStatusNotDownloaded),
            ),
            if (_model.attribution case final attribution?)
              Text(
                attribution,
                key: ValueKey('model-attribution-${_model.id}'),
                style: theme.textTheme.bodySmall,
              ),
            if (_model.license.startsWith('Llama'))
              Text(
                l10n.modelLlamaUsePolicy,
                key: ValueKey('model-aup-${_model.id}'),
                style: theme.textTheme.bodySmall,
              ),
            if (!entry.compatible)
              Text(
                l10n.modelIncompatible(
                  formatBytes(l10n, _model.minRamMb * 1024 * 1024),
                ),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            if (entry.access == AccessLevel.readOnly) Text(l10n.modelNotOnPlan),
            if (badges.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final b in badges)
                      Chip(
                        label: Text(b),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            if (p != null && p.phase == DownloadPhase.downloading)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: LinearProgressIndicator(
                  value: p.fraction,
                  semanticsLabel: _model.displayName,
                  semanticsValue: l10n.jobPercent((p.fraction * 100).round()),
                ),
              ),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: AppSpacing.sm,
              overflowAlignment: OverflowBarAlignment.end,
              children: _actions(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final id = _model.id;
    Widget button(String key, String label, VoidCallback onPressed) =>
        TextButton(
          key: ValueKey('model-$key-$id'),
          onPressed: onPressed,
          child: Text(label),
        );
    if (_running) {
      return [
        button('pause', l10n.modelActionPause, () async {
          (await ref.read(modelDownloaderProvider.future)).pause(id);
        }),
        button('cancel', l10n.modelActionCancel, () async {
          await (await ref.read(modelDownloaderProvider.future)).cancel(id);
        }),
      ];
    }
    final download = !offline && (!entry.isInstalled || entry.updateAvailable);
    return [
      if (download && entry.access == AccessLevel.disabled)
        button('upgrade', l10n.modelRequiresPro, () => _upgrade(context, ref))
      else if (download)
        button(
          'download',
          entry.isInstalled
              ? l10n.modelActionUpdate
              : progress?.phase == DownloadPhase.failed
              ? l10n.commonRetry
              : progress?.phase == DownloadPhase.paused
              ? l10n.modelActionResume
              : l10n.modelActionDownload,
          () => startModelDownload(context, ref, _model),
        ),
      if (entry.usable && !entry.active && entry.model.type.hasChoice)
        button('use', l10n.modelActionUse, () => _use(context, ref)),
      if (entry.isInstalled)
        button('delete', l10n.modelActionDelete, () => _delete(context, ref)),
    ];
  }

  Future<void> _upgrade(BuildContext context, WidgetRef ref) async {
    final feature = _model.type == ModelType.llm
        ? Feature.largeLlm
        : Feature.highAccuracyStt;
    final ok = await ensureFeature(
      ref,
      feature,
      from: PaywallEntryPoint.modelPicker,
    );
    if (ok && context.mounted) await startModelDownload(context, ref, _model);
  }

  Future<void> _use(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final done = context.l10n.modelActivated(_model.displayName);
    final r = await ref
        .read(modelManagerProvider)
        .setActive(_model.type, _model.id);
    if (r.isOk) messenger.showSnackBar(SnackBar(content: Text(done)));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final plan = planDeletion(entry, entries);
    ModelEntry? replacement;
    switch (plan) {
      case DeleteBlocked():
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.modelDeleteBlockedTitle),
            content: Text(
              context.l10n.modelDeleteBlockedBody(
                ModelTexts.type(context.l10n, _model.type),
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.l10n.commonOk),
              ),
            ],
          ),
        );
        return;
      case DeleteWithReplacement(:final replacements):
        replacement = await showDialog<ModelEntry>(
          context: context,
          builder: (_) =>
              _ReplacementDialog(target: entry, replacements: replacements),
        );
        if (replacement == null) return;
      case DeleteFreely():
        if (!context.mounted) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.modelDeleteTitle(_model.displayName)),
            content: Text(
              context.l10n.modelDeleteBody(
                formatBytes(context.l10n, entry.installed!.size),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.l10n.commonCancel),
              ),
              FilledButton(
                key: const ValueKey('model-delete-confirm'),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(context.l10n.modelActionDelete),
              ),
            ],
          ),
        );
        if (ok != true) return;
    }
    final result = await ref
        .read(modelManagerProvider)
        .delete(entry, entries, replacement: replacement);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.isOk
              ? l10n.modelDeleted(_model.displayName)
              : l10n.modelDeleteFailed,
        ),
      ),
    );
  }
}

extension on ModelType {
  bool get hasChoice => ActiveModelKeys.forType(this) != null;
}

/// Asks which installed model replaces the active one being deleted.
class _ReplacementDialog extends StatefulWidget {
  const _ReplacementDialog({required this.target, required this.replacements});

  final ModelEntry target;
  final List<ModelEntry> replacements;

  @override
  State<_ReplacementDialog> createState() => _ReplacementDialogState();
}

class _ReplacementDialogState extends State<_ReplacementDialog> {
  late ModelEntry _choice = widget.replacements.first;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.modelDeleteTitle(widget.target.model.displayName)),
      content: SingleChildScrollView(
        child: RadioGroup<String>(
          groupValue: _choice.model.id,
          onChanged: (id) => setState(
            () => _choice = widget.replacements.firstWhere(
              (r) => r.model.id == id,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.modelDeleteReplaceBody(widget.target.model.displayName),
              ),
              for (final r in widget.replacements)
                RadioListTile<String>(
                  key: ValueKey('model-replacement-${r.model.id}'),
                  contentPadding: EdgeInsets.zero,
                  value: r.model.id,
                  title: Text(r.model.displayName),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('model-delete-replace'),
          onPressed: () => Navigator.of(context).pop(_choice),
          child: Text(l10n.modelDeleteAndSwitch),
        ),
      ],
    );
  }
}

/// "Advanced: custom models" (MDL-04): only offered when the plan allows
/// unsigned custom GGUF files.
class _CustomModelsToggle extends ConsumerWidget {
  const _CustomModelsToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(featureProvider(Feature.sideloadCustomModel))) {
      return const SizedBox.shrink();
    }
    final on =
        ref.watch(storedSettingProvider(kAdvancedCustomModelKey)).value == true;
    return SwitchListTile(
      key: const ValueKey('models-advanced-custom'),
      secondary: const Icon(Icons.science_outlined),
      title: Text(context.l10n.modelsAdvancedCustom),
      subtitle: Text(context.l10n.modelsAdvancedCustomSubtitle),
      value: on,
      onChanged: (v) =>
          ref.read(settingsStoreProvider).set(kAdvancedCustomModelKey, v),
    );
  }
}
