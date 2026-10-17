import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/features/models/data/model_import_providers.dart';
import 'package:vaultvoice/features/models/data/model_state_providers.dart';
import 'package:vaultvoice/features/models/domain/download_state.dart';
import 'package:vaultvoice/features/models/domain/installed_model.dart';
import 'package:vaultvoice/features/models/domain/model_bundle.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';
import 'package:vaultvoice/features/models/presentation/model_download_actions.dart';
import 'package:vaultvoice/features/models/presentation/model_import_tile.dart';
import 'package:vaultvoice/features/models/presentation/model_texts.dart';

/// Onboarding page: device capability check → recommended model bundle with
/// sizes → download with progress. The user can continue at any time;
/// downloads keep running and recordings made meanwhile are processed once
/// the models are installed (`ModelInstallWaker`).
class OnboardingModelsStep extends ConsumerWidget {
  const OnboardingModelsStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final bundle = ref.watch(recommendedModelBundleProvider);
    final installed = <String>{
      for (final r
          in ref.watch(installedModelsProvider).value ??
              const <InstalledModel>[])
        r.id,
    };
    final progress =
        ref.watch(modelDownloadProgressProvider).value ??
        const <String, DownloadProgress>{};
    final offline = ref.watch(networkDisabledProvider).value ?? false;

    final header = [
      Icon(
        Icons.memory,
        size: AppSizes.illustration,
        color: theme.colorScheme.primary,
      ),
      const SizedBox(height: AppSpacing.md),
      Semantics(
        header: true,
        child: Text(
          l10n.onboardingModelsTitle,
          style: theme.textTheme.headlineSmall,
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...header,
        ...bundle.when(
          loading: () => [
            Center(
              child: CircularProgressIndicator(
                semanticsLabel: l10n.onboardingModelsChecking,
              ),
            ),
          ],
          error: (_, _) => [Text(l10n.onboardingModelsUnavailable)],
          data: (b) => b == null || b.models.isEmpty
              ? [Text(l10n.onboardingModelsUnavailable)]
              : _bundle(context, ref, b, installed, progress, offline),
        ),
      ],
    );
  }

  List<Widget> _bundle(
    BuildContext context,
    WidgetRef ref,
    ModelBundle bundle,
    Set<String> installed,
    Map<String, DownloadProgress> progress,
    bool offline,
  ) {
    final l10n = context.l10n;
    final missing = [
      for (final m in bundle.models)
        if (!installed.contains(m.id)) m,
    ];
    final busy = missing.any((m) => _isRunning(progress[m.id]));
    final remaining = bundle.remainingBytes(installed);
    return [
      Text(
        bundle.deviceKnown
            ? l10n.onboardingModelsDevice(
                ModelTexts.tier(l10n, bundle.tier),
                formatBytes(l10n, bundle.totalRamBytes),
              )
            : l10n.onboardingModelsDeviceUnknown,
      ),
      const SizedBox(height: AppSpacing.md),
      for (final m in bundle.models)
        _ModelRow(
          model: m,
          installed: installed.contains(m.id),
          progress: progress[m.id],
          onRetry: offline
              ? null
              : () => startModelDownloads(context, ref, [m]),
        ),
      const SizedBox(height: AppSpacing.md),
      if (missing.isEmpty)
        Text(l10n.onboardingModelsReady)
      else if (offline) ...[
        Text(l10n.onboardingModelsOffline),
        const ModelImportTile(),
      ] else ...[
        Text(l10n.onboardingModelsTotal(formatBytes(l10n, remaining))),
        if (missing.any((m) => progress[m.id]?.phase == DownloadPhase.failed))
          const ModelImportTile(),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.tonalIcon(
            key: const ValueKey('onboarding-download-models'),
            onPressed: busy
                ? null
                : () => startModelDownloads(context, ref, missing),
            icon: const Icon(Icons.download),
            label: Text(
              l10n.onboardingModelsDownload(formatBytes(l10n, remaining)),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.onboardingModelsExplore),
      ],
    ];
  }

  static bool _isRunning(DownloadProgress? p) => switch (p?.phase) {
    DownloadPhase.checking ||
    DownloadPhase.downloading ||
    DownloadPhase.retrying ||
    DownloadPhase.verifying ||
    DownloadPhase.installing => true,
    _ => false,
  };
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({
    required this.model,
    required this.installed,
    required this.progress,
    this.onRetry,
  });

  final VoidCallback? onRetry;
  final CatalogModel model;
  final bool installed;
  final DownloadProgress? progress;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = progress;
    final status = installed
        ? l10n.modelStatusInstalled
        : ModelTexts.progress(l10n, p) ?? l10n.modelStatusNotDownloaded;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(ModelTexts.icon(model.type)),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    model.displayName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (installed) const Icon(Icons.check_circle_outline),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.modelSummary(
                ModelTexts.type(l10n, model.type),
                formatBytes(l10n, model.size),
              ),
            ),
            Text(
              status,
              style: !installed && p?.phase == DownloadPhase.failed
                  ? TextStyle(color: Theme.of(context).colorScheme.error)
                  : null,
            ),
            if (!installed &&
                p?.phase == DownloadPhase.failed &&
                onRetry != null)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  key: ValueKey('onboarding-retry-${model.id}'),
                  onPressed: onRetry,
                  child: Text(l10n.commonRetry),
                ),
              ),
            if (!installed && p != null && p.phase == DownloadPhase.downloading)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: LinearProgressIndicator(
                  value: p.fraction,
                  semanticsLabel: model.displayName,
                  semanticsValue: l10n.jobPercent((p.fraction * 100).round()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
