import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/app_info.dart';
import 'package:vaultvoice/core/branding/lumen_logo.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/routing/app_routes.dart';
import 'package:vaultvoice/core/security/security_providers.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/core/widgets/lumen_card.dart';
import 'package:vaultvoice/features/ask/data/ask_providers.dart';
import 'package:vaultvoice/features/extraction/presentation/llm_debug_screen.dart';
import 'package:vaultvoice/features/legal/presentation/terms_of_use_screen.dart';
import 'package:vaultvoice/features/licensing/data/licensing_providers.dart';
import 'package:vaultvoice/features/licensing/data/managed_config_applier.dart';
import 'package:vaultvoice/features/licensing/data/managed_config_providers.dart';
import 'package:vaultvoice/features/licensing/domain/feature_matrix.dart';
import 'package:vaultvoice/features/models/data/model_state_providers.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';
import 'package:vaultvoice/features/settings/domain/setting_definitions.dart';
import 'package:vaultvoice/features/settings/domain/settings_ports.dart';
import 'package:vaultvoice/features/settings/presentation/crash_reports.dart';
import 'package:vaultvoice/features/settings/presentation/diagnostics_export.dart';
import 'package:vaultvoice/features/settings/presentation/network_activity_screen.dart';
import 'package:vaultvoice/features/settings/presentation/privacy_policy_screen.dart';
import 'package:vaultvoice/features/settings/presentation/setting_texts.dart';
import 'package:vaultvoice/features/settings/presentation/setting_tiles.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

/// Settings tab (APP-03): every section of the task, persisted in the
/// `settings` table; managed (enterprise) values render read-only.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // Each section is a header plus one soft card holding its rows.
    List<Widget> section(SettingSection s, List<Widget> rows) => [
      SettingsSectionHeader(SettingTexts.section(context.l10n, s)),
      LumenCard(child: Column(children: rows)),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: [
          ...section(SettingSection.audio, [
            const SettingTile(AppSettings.inputDevice),
            const SettingTile(AppSettings.agc),
            const SettingTile(AppSettings.noiseSuppression),
            const SettingTile(AppSettings.softwareAgc),
            const SettingTile(AppSettings.rawCapture),
            const SettingTile(AppSettings.autoPauseOnSilence),
            const SettingTile(AppSettings.silenceAutoStop),
            const SettingTile(AppSettings.audioRetention),
          ]),
          ...section(SettingSection.processing, [
            const SettingTile(AppSettings.autoProcess),
            const SettingTile(AppSettings.chargeOnly),
            const SettingTile(AppSettings.diarizationDefault),
            const SettingTile(AppSettings.skipSilence),
            const SettingTile(AppSettings.mindMap),
            SettingTile(AppSettings.askEnabled),
            ListTile(
              key: const ValueKey('link-models'),
              leading: const Icon(Icons.memory),
              title: Text(l10n.settingsModels),
              subtitle: Text(l10n.settingsModelsSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => const ModelsSettingsRoute().push<void>(context),
            ),
          ]),
          ...section(SettingSection.export, [
            const _VaultFoldersTile(),
            const _RoutingRulesTile(),
            const _PendingExportsTile(),
            ListTile(
              key: const ValueKey('link-templates'),
              leading: const Icon(Icons.article_outlined),
              title: Text(l10n.settingsTemplates),
              subtitle: Text(l10n.settingsTemplatesSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => const TemplatesRoute().push<void>(context),
            ),
            ListTile(
              key: const ValueKey('link-review'),
              leading: const Icon(Icons.rate_review_outlined),
              title: Text(l10n.reviewSettingsTitle),
              subtitle: Text(l10n.reviewSettingsSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => const ReviewSettingsRoute().push<void>(context),
            ),
            const SettingTile(AppSettings.filenamePattern),
            const SettingTile(AppSettings.collisionMode),
          ]),
          ...section(SettingSection.privacy, [
            const SettingTile(AppSettings.appLock),
            const SettingTile(AppSettings.lockTimeout),
            const _EncryptionInfoTile(),
            const SettingTile(AppSettings.transcriptRetention),
            const SettingTile(AppSettings.askSaveHistory),
            if (ref.watch(askEnabledProvider))
              ListTile(
                key: const ValueKey('link-ask-history'),
                leading: const Icon(Icons.history),
                title: Text(l10n.askHistoryTitle),
                subtitle: Text(l10n.askHistoryExpiryNote),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => const AskHistoryRoute().push<void>(context),
              ),
            // SEC-02: offline mode + every request the app made.
            const SettingTile(AppSettings.offlineMode),
            const NetworkActivityTile(),
            const SettingTile(AppSettings.notificationsEnabled),
            const SettingTile(AppSettings.notificationDetails),
            const DiagnosticsExportTile(),
            // REL-02 hook: saved crash reports (+ dev-only crash triggers).
            const CrashReportSettingsSection(),
            const _DeleteAllDataTile(),
          ]),
          ...section(SettingSection.license, [const _LicenseTiles()]),
          ...section(SettingSection.about, [
            const Padding(
              key: ValueKey('about-logo'),
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: LumenWordmark(),
              ),
            ),
            ListTile(
              key: const ValueKey('about-version'),
              leading: const Icon(Icons.info_outline),
              title: Text(l10n.aboutVersion),
              subtitle: const Text('$kAppName $kAppVersion'),
            ),
            ListTile(
              key: const ValueKey('link-beta-feedback'),
              leading: const Icon(Icons.feedback_outlined),
              title: Text(l10n.betaFeedbackTitle),
              subtitle: Text(l10n.betaFeedbackSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => const BetaFeedbackRoute().push<void>(context),
            ),
            ListTile(
              key: const ValueKey('about-privacy-policy'),
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(l10n.aboutPrivacyPolicy),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PrivacyPolicyScreen(),
                ),
              ),
            ),
            ListTile(
              key: const ValueKey('about-terms-of-use'),
              leading: const Icon(Icons.gavel_outlined),
              title: Text(l10n.aboutTermsOfUse),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const TermsOfUseScreen(),
                ),
              ),
            ),
            ListTile(
              key: const ValueKey('about-licenses'),
              leading: const Icon(Icons.description_outlined),
              title: Text(l10n.aboutLicenses),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final legalese = await _modelAttributions(ref, l10n);
                if (!context.mounted) return;
                showLicensePage(
                  context: context,
                  applicationName: kAppName,
                  applicationVersion: kAppVersion,
                  applicationLegalese: legalese,
                );
              },
            ),
            // Dev flavor only (renders nothing in prod) — LLM-04.
            const LlmDebugTile(),
          ]),
        ],
      ),
    );
  }
}

class _VaultFoldersTile extends ConsumerWidget {
  const _VaultFoldersTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(vaultTargetsProvider).value?.length;
    return ListTile(
      key: const ValueKey('link-vault-folders'),
      leading: const Icon(Icons.folder_outlined),
      title: Text(context.l10n.settingsVaultFolders),
      subtitle: Text(
        n == null ? ' ' : context.l10n.settingsVaultFoldersCount(n),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => const VaultFoldersRoute().push<void>(context),
    );
  }
}

/// Attribution lines the model licenses require (e.g. "Built with Llama"),
/// taken from the catalog; null when the catalog is unavailable or has none.
Future<String?> _modelAttributions(WidgetRef ref, AppLocalizations l10n) async {
  try {
    final catalog = await ref.read(activeCatalogProvider.future);
    final lines = <String>{
      for (final m in catalog?.models ?? const <CatalogModel>[]) ?m.attribution,
    };
    if (lines.isEmpty) return null;
    return '${l10n.aboutModelAttributions}\n${lines.join('\n')}';
  } on Object {
    return null;
  }
}

class _PendingExportsTile extends StatelessWidget {
  const _PendingExportsTile();

  @override
  Widget build(BuildContext context) => ListTile(
    key: const ValueKey('link-pending-exports'),
    leading: const Icon(Icons.outbox_outlined),
    title: Text(context.l10n.settingsPendingExports),
    subtitle: Text(context.l10n.settingsPendingExportsSubtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => const PendingExportsRoute().push<void>(context),
  );
}

class _RoutingRulesTile extends ConsumerWidget {
  const _RoutingRulesTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(routingRulesProvider).value?.length;
    return ListTile(
      key: const ValueKey('link-routing-rules'),
      leading: const Icon(Icons.alt_route),
      title: Text(context.l10n.settingsRoutingRules),
      subtitle: Text(
        n == null ? ' ' : context.l10n.settingsRoutingRulesCount(n),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => const RoutingRulesRoute().push<void>(context),
    );
  }
}

/// Truthful encryption status (SEC-01): on only with the sqlite3mc cipher.
class _EncryptionInfoTile extends ConsumerWidget {
  const _EncryptionInfoTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(encryptionStatusProvider).state;
    final encrypted = state == EncryptionState.encrypted;
    final l10n = context.l10n;
    final status = switch (state) {
      EncryptionState.encrypted => l10n.encryptionOn,
      EncryptionState.unavailable => l10n.encryptionUnavailable,
      EncryptionState.off => l10n.encryptionOff,
    };
    return ListTile(
      key: const ValueKey('privacy-encryption'),
      leading: Icon(encrypted ? Icons.lock_outline : Icons.lock_open),
      title: Text(l10n.encryptionTitle),
      subtitle: Text(status),
      onTap: () => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.encryptionTitle),
          content: Text(l10n.encryptionDetails(status)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.commonOk),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteAllDataTile extends ConsumerWidget {
  const _DeleteAllDataTile();

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteAllConfirmTitle),
        content: Text(l10n.deleteAllConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.deleteAllConfirm),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final result = await ref.read(dataWiperProvider).deleteAllData();
    messenger.showSnackBar(
      SnackBar(
        content: Text(switch (result) {
          Ok() => l10n.deleteAllDone,
          Err(failure: UnsupportedFeatureFailure()) =>
            l10n.deleteAllUnavailable,
          Err() => l10n.deleteAllFailed,
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = Theme.of(context).colorScheme.error;
    return ListTile(
      key: const ValueKey('privacy-delete-all'),
      leading: Icon(Icons.delete_forever_outlined, color: color),
      title: Text(context.l10n.deleteAllTitle, style: TextStyle(color: color)),
      onTap: () => _confirm(context, ref),
    );
  }
}

class _LicenseTiles extends ConsumerWidget {
  const _LicenseTiles();

  static String describe(AppLocalizations l, LicenseSummary s) {
    final plan = switch (s.tier) {
      LicenseTier.free => l.licensePlanFree,
      LicenseTier.pro => l.licensePlanPro,
      LicenseTier.enterprise => l.licensePlanEnterprise,
    };
    final parts = [
      plan,
      ?s.organization,
      if (s.expiresAt case final e?)
        l.licenseUntil(e.toLocal().toIso8601String().substring(0, 10)),
      if (s.inGracePeriod) l.licenseGrace,
    ];
    return parts.join(' · ');
  }

  /// Content-free: states and counts only.
  static List<String> _managedLines(AppLocalizations l, ManagedApplyStatus s) {
    final lines = [
      switch (s.license) {
        ManagedLicenseState.installed => l.managedConfigLicenseInstalled,
        ManagedLicenseState.rejected => l.managedConfigLicenseRejected,
        ManagedLicenseState.none => null,
      },
      if (s.packsInstalled > 0) l.managedConfigPacksInstalled(s.packsInstalled),
      if (s.packsRejected > 0) l.managedConfigPacksRejected(s.packsRejected),
    ].nonNulls.toList();
    return lines.isEmpty ? [l.managedConfigNoIssues] : lines;
  }

  Future<void> _report(BuildContext context, bool ok, String done) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? done : context.l10n.commonNotAvailableYet)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(licenseSummaryProvider).value;
    final port = ref.watch(licenseSettingsPortProvider);
    final l10n = context.l10n;
    final managed = ref.watch(managedConfigProvider).value;
    final applied = ref.watch(managedConfigApplierProvider);
    return Column(
      children: [
        if (managed != null && !managed.isEmpty)
          ListTile(
            key: const ValueKey('managed-config-status'),
            leading: const Icon(Icons.lock_outline),
            title: Text(l10n.managedConfigTitle),
            subtitle: Text(_managedLines(l10n, applied).join('\n')),
          ),
        ListTile(
          key: const ValueKey('license-status'),
          leading: const Icon(Icons.workspace_premium_outlined),
          title: Text(l10n.licenseStatus),
          subtitle: Text(summary == null ? ' ' : describe(l10n, summary)),
        ),
        if (ref.watch(distributionModeProvider) ==
                DistributionMode.commercial &&
            ref.watch(proTierEnforcedProvider))
          ListTile(
            key: const ValueKey('license-upgrade'),
            leading: const Icon(Icons.workspace_premium),
            title: Text(l10n.paywallTitle),
            onTap: () => const ProRoute().push<void>(context),
          ),
        ListTile(
          key: const ValueKey('license-restore'),
          leading: const Icon(Icons.restore),
          title: Text(l10n.licenseRestore),
          onTap: () async {
            final r = await port.restorePurchases();
            if (context.mounted) {
              await _report(context, r.isOk, l10n.licenseRestored);
            }
          },
        ),
        ListTile(
          key: const ValueKey('license-enterprise'),
          leading: const Icon(Icons.business_outlined),
          title: Text(l10n.licenseEnterpriseEnter),
          onTap: () async {
            final text = await showDialog<String>(
              context: context,
              builder: (_) => const _EnterpriseLicenseDialog(),
            );
            if (text == null || text.isEmpty) return;
            final r = await port.installEnterpriseLicense(text);
            if (context.mounted) {
              await _report(context, r.isOk, l10n.licenseEnterpriseInstalled);
            }
          },
        ),
      ],
    );
  }
}

class _EnterpriseLicenseDialog extends StatefulWidget {
  const _EnterpriseLicenseDialog();

  @override
  State<_EnterpriseLicenseDialog> createState() =>
      _EnterpriseLicenseDialogState();
}

class _EnterpriseLicenseDialogState extends State<_EnterpriseLicenseDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.licenseEnterpriseTitle),
    content: TextField(
      key: const ValueKey('license-text-field'),
      controller: _controller,
      maxLines: 4,
      decoration: InputDecoration(hintText: context.l10n.licenseEnterpriseHint),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.l10n.commonCancel),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
        child: Text(context.l10n.licenseEnterpriseInstall),
      ),
    ],
  );
}
