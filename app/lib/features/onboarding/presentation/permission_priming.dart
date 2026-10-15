import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/platform/app_settings_launcher.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/features/onboarding/data/onboarding_providers.dart';

/// Microphone priming for the **first Record tap** (never at launch): the
/// Record button calls this before it opens the microphone, which is when
/// the OS asks. Shows the explanation once; returns whether to continue to
/// the OS prompt (false = the user chose "Not now", nothing is requested).
Future<bool> primeMicrophonePermission(
  BuildContext context,
  WidgetRef ref,
) async {
  final store = ref.read(onboardingStoreProvider);
  if (await store.micPrimed()) return true;
  if (!context.mounted) return false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.mic_none),
      title: Text(context.l10n.micPrimerTitle),
      content: Text(context.l10n.micPrimerBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.commonNotNow),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(context.l10n.commonContinue),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  await store.markMicPrimed();
  return true;
}

/// Recovery path after a denied permission: what still works, and a button
/// to this app's page in the OS Settings.
class PermissionDeniedNotice extends ConsumerWidget {
  const PermissionDeniedNotice({
    required this.icon,
    required this.message,
    super.key,
  });

  /// Microphone denied: recording is unavailable, everything else works.
  factory PermissionDeniedNotice.microphone({Key? key}) =>
      PermissionDeniedNotice(
        key: key,
        icon: Icons.mic_off_outlined,
        message: (l) => l.micDeniedBody,
      );

  /// Notifications denied: processing still runs, nothing is announced.
  factory PermissionDeniedNotice.notifications({Key? key}) =>
      PermissionDeniedNotice(
        key: key,
        icon: Icons.notifications_off_outlined,
        message: (l) => l.notificationsDeniedBody,
      );

  final IconData icon;
  final String Function(AppLocalizations l) message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: theme.colorScheme.onSecondaryContainer),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    message(context.l10n),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: OutlinedButton(
                onPressed: () => _open(context, ref),
                child: Text(context.l10n.permissionOpenSettings),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failed = context.l10n.permissionOpenSettingsFailed;
    final opened = await ref
        .read(appSettingsLauncherProvider)
        .openAppSettings();
    if (!opened) {
      messenger?.showSnackBar(SnackBar(content: Text(failed)));
    }
  }
}
