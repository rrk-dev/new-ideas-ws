import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/routing/app_routes.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/features/onboarding/data/onboarding_providers.dart';
import 'package:vaultvoice/features/onboarding/domain/onboarding_keys.dart';
import 'package:vaultvoice/features/onboarding/presentation/onboarding_models_step.dart';
import 'package:vaultvoice/features/onboarding/presentation/permission_priming.dart';
import 'package:vaultvoice/features/onboarding/presentation/recording_consent_explainer.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_providers.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';
import 'package:vaultvoice/features/settings/presentation/vault_settings_screens.dart';

/// First-launch flow (APP-01): privacy explainer → recording consent
/// (SEC-07 placement, "never records calls") → permission priming →
/// recommended models with download progress → default vault folder →
/// optional first recording.
///
/// Nothing here opens the microphone or starts recording: the microphone is
/// only explained, the OS asks on the first Record tap. Every permission
/// can be declined and the flow still finishes.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  OnboardingStep _step = OnboardingStep.privacy;
  bool _consentChecked = false;

  /// Result of the notification prompt (null = not asked in this flow).
  bool? _notificationsGranted;
  VaultFolderPick? _folder;
  bool _busy = false;

  static const List<OnboardingStep> _steps = OnboardingStep.values;

  void _go(OnboardingStep step) => setState(() => _step = step);

  void _next() {
    final i = _steps.indexOf(_step);
    if (i < _steps.length - 1) _go(_steps[i + 1]);
  }

  void _back() {
    final i = _steps.indexOf(_step);
    if (i > 0) _go(_steps[i - 1]);
  }

  Future<void> _guard(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _acknowledgeConsent() => _guard(() async {
    await ref.read(onboardingStoreProvider).acknowledgeConsent();
    _next();
  });

  Future<void> _askNotifications() => _guard(() async {
    await ref
        .read(settingsStoreProvider)
        .set(SettingKeys.notificationsPermissionAsked, true);
    final granted = await ref
        .read(localNotificationsProvider)
        .requestPermission();
    if (mounted) setState(() => _notificationsGranted = granted);
  });

  Future<void> _pickFolder() => _guard(() async {
    final result = await pickAndSaveVaultFolder(ref, context.l10n);
    if (!mounted) return;
    if (result is! VaultFolderPickCancelled) setState(() => _folder = result);
  });

  Future<void> _finish({required bool record}) => _guard(() async {
    await ref.read(onboardingStoreProvider).complete();
    if (!mounted) return;
    if (record) {
      const RecordRoute().go(context);
    } else {
      const LibraryRoute().go(context);
    }
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final index = _steps.indexOf(_step);
    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: index == 0
              ? null
              : IconButton(
                  tooltip: l10n.onboardingBack,
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _busy ? null : _back,
                ),
          title: Text(l10n.onboardingStepOf(index + 1, _steps.length)),
        ),
        body: SafeArea(
          child: Column(
            children: [
              LinearProgressIndicator(
                value: (index + 1) / _steps.length,
                semanticsLabel: l10n.onboardingStepOf(index + 1, _steps.length),
              ),
              Expanded(
                child: SingleChildScrollView(
                  key: ValueKey('onboarding-${_step.name}'),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: _page(context),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: AppSpacing.sm,
                  overflowSpacing: AppSpacing.sm,
                  overflowAlignment: OverflowBarAlignment.end,
                  children: _actions(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _page(BuildContext context) {
    final l10n = context.l10n;
    return switch (_step) {
      OnboardingStep.privacy => _Page(
        icon: Icons.lock_outline,
        title: l10n.onboardingPrivacyTitle,
        children: [
          _Point(Icons.phone_iphone, l10n.onboardingPrivacyOnDevice),
          _Point(Icons.cloud_download_outlined, l10n.onboardingPrivacyNetwork),
          _Point(Icons.folder_outlined, l10n.onboardingPrivacyVault),
        ],
      ),
      OnboardingStep.consent => _Page(
        icon: Icons.record_voice_over_outlined,
        title: l10n.consentExplainerTitle,
        children: [
          const RecordingConsentExplainer(),
          CheckboxListTile(
            key: const ValueKey('onboarding-consent-check'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _consentChecked,
            onChanged: (v) => setState(() => _consentChecked = v ?? false),
            title: Text(l10n.consentExplainerAcknowledge),
          ),
        ],
      ),
      OnboardingStep.permissions => _Page(
        icon: Icons.verified_user_outlined,
        title: l10n.onboardingPermissionsTitle,
        children: [
          _Point(Icons.mic_none, l10n.onboardingPermissionMic),
          _Point(
            Icons.notifications_none,
            l10n.onboardingPermissionNotifications,
          ),
          if (_notificationsGranted == true)
            _Point(Icons.check_circle_outline, l10n.notificationsAllowed)
          else if (_notificationsGranted == false)
            PermissionDeniedNotice.notifications(
              key: const ValueKey('onboarding-notifications-denied'),
            )
          else
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                key: const ValueKey('onboarding-allow-notifications'),
                onPressed: _busy ? null : _askNotifications,
                icon: const Icon(Icons.notifications_active_outlined),
                label: Text(l10n.onboardingAllowNotifications),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          _Point(Icons.folder_outlined, l10n.onboardingPermissionFolder),
        ],
      ),
      OnboardingStep.models => const OnboardingModelsStep(),
      OnboardingStep.folder => _Page(
        icon: Icons.folder_special_outlined,
        title: l10n.onboardingFolderTitle,
        children: [
          Text(l10n.onboardingFolderBody),
          const SizedBox(height: AppSpacing.md),
          switch (_folder) {
            VaultFolderPicked(:final name) => _Point(
              Icons.check_circle_outline,
              l10n.onboardingFolderChosen(name),
            ),
            VaultFolderPickFailed() => _Point(
              Icons.error_outline,
              l10n.onboardingFolderFailed,
            ),
            _ => const SizedBox.shrink(),
          },
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.tonalIcon(
              key: const ValueKey('onboarding-choose-folder'),
              onPressed: _busy ? null : _pickFolder,
              icon: const Icon(Icons.create_new_folder_outlined),
              label: Text(
                _folder is VaultFolderPicked
                    ? l10n.onboardingFolderChooseAnother
                    : l10n.onboardingFolderChoose,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.onboardingFolderLater),
        ],
      ),
      OnboardingStep.ready => _Page(
        icon: Icons.celebration_outlined,
        title: l10n.onboardingReadyTitle,
        children: [Text(l10n.onboardingReadyBody)],
      ),
    };
  }

  List<Widget> _actions(BuildContext context) {
    final l10n = context.l10n;
    Widget primary(String label, VoidCallback? onPressed, {Key? key}) =>
        FilledButton(
          key: key ?? const ValueKey('onboarding-next'),
          onPressed: _busy ? null : onPressed,
          child: Text(label),
        );
    return switch (_step) {
      OnboardingStep.privacy => [primary(l10n.onboardingGetStarted, _next)],
      OnboardingStep.consent => [
        primary(
          l10n.commonContinue,
          _consentChecked ? _acknowledgeConsent : null,
        ),
      ],
      OnboardingStep.permissions => [primary(l10n.commonContinue, _next)],
      OnboardingStep.models => [primary(l10n.commonContinue, _next)],
      OnboardingStep.folder => [
        if (_folder is! VaultFolderPicked)
          TextButton(
            key: const ValueKey('onboarding-keep-in-app'),
            onPressed: _busy ? null : _next,
            child: Text(l10n.onboardingFolderKeepInApp),
          ),
        if (_folder is VaultFolderPicked) primary(l10n.commonContinue, _next),
      ],
      OnboardingStep.ready => [
        TextButton(
          key: const ValueKey('onboarding-explore'),
          onPressed: _busy ? null : () => _finish(record: false),
          child: Text(l10n.onboardingExplore),
        ),
        primary(
          l10n.onboardingFirstRecording,
          () => _finish(record: true),
          key: const ValueKey('onboarding-first-recording'),
        ),
      ],
    };
  }
}

class _Page extends StatelessWidget {
  const _Page({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 48, color: theme.colorScheme.primary),
        const SizedBox(height: AppSpacing.md),
        Semantics(
          header: true,
          child: Text(title, style: theme.textTheme.headlineSmall),
        ),
        const SizedBox(height: AppSpacing.lg),
        ...children,
      ],
    );
  }
}

/// Icon + paragraph row used on the onboarding pages.
class _Point extends StatelessWidget {
  const _Point(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
