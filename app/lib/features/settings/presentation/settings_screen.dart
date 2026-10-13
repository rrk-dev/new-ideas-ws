import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/app_info.dart';
import 'package:vaultvoice/core/db/connection.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/routing/app_routes.dart';
import 'package:vaultvoice/features/settings/domain/setting_definitions.dart';
import 'package:vaultvoice/features/settings/domain/settings_ports.dart';
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
    Widget header(SettingSection s) =>
        SettingsSectionHeader(SettingTexts.section(s));
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
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
            title: const Text('Models'),
            subtitle: const Text('Speech and language models on this device'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => const ModelsSettingsRoute().push<void>(context),
          ),
          header(SettingSection.export),
          const _VaultFoldersTile(),
          const _RoutingRulesTile(),
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
          const _DeleteAllDataTile(),
          header(SettingSection.license),
          const _LicenseTiles(),
          header(SettingSection.about),
          const ListTile(
            key: ValueKey('about-version'),
            leading: Icon(Icons.info_outline),
            title: Text('Version'),
            subtitle: Text('$kAppName $kAppVersion'),
          ),
          ListTile(
            key: const ValueKey('about-licenses'),
            leading: const Icon(Icons.description_outlined),
            title: const Text('Open-source & model licenses'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(
              context: context,
              applicationName: kAppName,
              applicationVersion: kAppVersion,
            ),
          ),
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
      title: const Text('Vault folders'),
      subtitle: Text(switch (n) {
        null => ' ',
        0 => 'The app’s own folder',
        1 => '1 folder',
        _ => '$n folders',
      }),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => const VaultFoldersRoute().push<void>(context),
    );
  }
}

class _RoutingRulesTile extends ConsumerWidget {
  const _RoutingRulesTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(routingRulesProvider).value?.length;
    return ListTile(
      key: const ValueKey('link-routing-rules'),
      leading: const Icon(Icons.alt_route),
      title: const Text('Routing rules'),
      subtitle: Text(switch (n) {
        null => ' ',
        0 => 'None',
        1 => '1 rule',
        _ => '$n rules',
      }),
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
    final status = encrypted
        ? 'On — the database is encrypted with a key kept in the device '
              'keychain.'
        : 'Not enabled in this build yet.';
    return ListTile(
      key: const ValueKey('privacy-encryption'),
      leading: Icon(encrypted ? Icons.lock_outline : Icons.lock_open),
      title: const Text('Encryption'),
      subtitle: Text(status),
      onTap: () => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Encryption'),
          content: Text(
            '$status\n\nRecordings, transcripts and notes never leave this '
            'device unless you export or share them. Notes exported to a '
            'vault folder are plain Markdown files, readable by any app '
            'with access to that folder.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all data?'),
        content: const Text(
          'Deletes every recording, transcript, note, profile and setting '
          'on this device. Notes already exported to your vault folders are '
          'kept. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final result = await ref.read(dataWiperProvider).deleteAllData();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.isOk
              ? 'All data deleted.'
              : 'Deleting all data is not available in this build yet.',
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
      title: Text('Delete all data', style: TextStyle(color: color)),
      onTap: () => _confirm(context, ref),
    );
  }
}

class _LicenseTiles extends ConsumerWidget {
  const _LicenseTiles();

  static String describe(LicenseSummary s) {
    final plan = switch (s.tier) {
      LicenseTier.free => 'Free',
      LicenseTier.pro => 'Pro',
      LicenseTier.enterprise => 'Enterprise',
    };
    final parts = [
      plan,
      ?s.organization,
      if (s.expiresAt case final e?)
        'until ${e.toLocal().toIso8601String().substring(0, 10)}',
      if (s.inGracePeriod) 'offline grace period',
    ];
    return parts.join(' · ');
  }

  Future<void> _report(BuildContext context, bool ok, String done) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? done : 'Not available in this build yet.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(licenseSummaryProvider).value;
    final port = ref.watch(licenseSettingsPortProvider);
    return Column(
      children: [
        ListTile(
          key: const ValueKey('license-status'),
          leading: const Icon(Icons.workspace_premium_outlined),
          title: const Text('Status'),
          subtitle: Text(summary == null ? ' ' : describe(summary)),
        ),
        ListTile(
          key: const ValueKey('license-restore'),
          leading: const Icon(Icons.restore),
          title: const Text('Restore purchases'),
          onTap: () async {
            final r = await port.restorePurchases();
            if (context.mounted) {
              await _report(context, r.isOk, 'Purchases restored.');
            }
          },
        ),
        ListTile(
          key: const ValueKey('license-enterprise'),
          leading: const Icon(Icons.business_outlined),
          title: const Text('Enter enterprise license'),
          onTap: () async {
            final text = await showDialog<String>(
              context: context,
              builder: (_) => const _EnterpriseLicenseDialog(),
            );
            if (text == null || text.isEmpty) return;
            final r = await port.installEnterpriseLicense(text);
            if (context.mounted) {
              await _report(context, r.isOk, 'Enterprise license installed.');
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
    title: const Text('Enterprise license'),
    content: TextField(
      key: const ValueKey('license-text-field'),
      controller: _controller,
      maxLines: 4,
      decoration: const InputDecoration(
        hintText: 'Paste the license from your administrator',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
        child: const Text('Install'),
      ),
    ],
  );
}
