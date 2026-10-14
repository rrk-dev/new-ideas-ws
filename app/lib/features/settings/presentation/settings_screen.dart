import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/app_info.dart';
import 'package:vaultvoice/core/db/connection.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/routing/app_routes.dart';
import 'package:vaultvoice/features/extraction/presentation/llm_debug_screen.dart';
import 'package:vaultvoice/features/settings/domain/setting_definitions.dart';
import 'package:vaultvoice/features/settings/domain/settings_ports.dart';
import 'package:vaultvoice/features/settings/presentation/crash_reports.dart';
import 'package:vaultvoice/features/settings/presentation/diagnostics_export.dart';
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
    Widget header(SettingSection s) =>
        SettingsSectionHeader(SettingTexts.section(context.l10n, s));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          header(SettingSection.audio),
          const SettingTile(AppSettings.inputDevice),
          const SettingTile(AppSettings.agc),
          const SettingTile(AppSettings.noiseSuppression),
          const SettingTile(AppSettings.autoPauseOnSilence),
          const SettingTile(AppSettings.audioRetention),
          header(SettingSection.processing),
          const SettingTile(AppSettings.autoProcess),
          const SettingTile(AppSettings.chargeOnly),
          const SettingTile(AppSettings.diarizationDefault),
          ListTile(
            key: const ValueKey('link-models'),
            leading: const Icon(Icons.memory),
            title: Text(l10n.settingsModels),
            subtitle: Text(l10n.settingsModelsSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => const ModelsSettingsRoute().push<void>(context),
          ),
          header(SettingSection.export),
          const _VaultFoldersTile(),
          const _RoutingRulesTile(),
          const _PendingExportsTile(),
          const SettingTile(AppSettings.filenamePattern),
          const SettingTile(AppSettings.collisionMode),
          header(SettingSection.privacy),
          const SettingTile(AppSettings.appLock),
          const SettingTile(AppSettings.lockTimeout),
          const _EncryptionInfoTile(),
          const SettingTile(AppSettings.transcriptRetention),
          const SettingTile(AppSettings.notificationsEnabled),
          const SettingTile(AppSettings.notificationDetails),
          const DiagnosticsExportTile(),
          // REL-02 hook: saved crash reports (+ dev-only crash triggers).
          const CrashReportSettingsSection(),
          const _DeleteAllDataTile(),
          header(SettingSection.license),
          const _LicenseTiles(),
          header(SettingSection.about),
          ListTile(
            key: const ValueKey('about-version'),
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.aboutVersion),
            subtitle: const Text('$kAppName $kAppVersion'),
          ),
          ListTile(
            key: const ValueKey('about-licenses'),
            leading: const Icon(Icons.description_outlined),
            title: Text(l10n.aboutLicenses),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(
              context: context,
              applicationName: kAppName,
              applicationVersion: kAppVersion,
            ),
          ),
          // Dev flavor only (renders nothing in prod) — LLM-04.
          const LlmDebugTile(),
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

/// Truthful encryption status: on only when SEC-01's cipher is installed.
class _EncryptionInfoTile extends ConsumerWidget {
  const _EncryptionInfoTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final encrypted = ref.watch(databaseCipherProvider) is! PlaintextCipher;
    final l10n = context.l10n;
    final status = encrypted ? l10n.encryptionOn : l10n.encryptionOff;
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
        content: Text(
          result.isOk ? l10n.deleteAllDone : l10n.deleteAllUnavailable,
        ),
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
    return Column(
      children: [
        ListTile(
          key: const ValueKey('license-status'),
          leading: const Icon(Icons.workspace_premium_outlined),
          title: Text(l10n.licenseStatus),
          subtitle: Text(summary == null ? ' ' : describe(l10n, summary)),
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
