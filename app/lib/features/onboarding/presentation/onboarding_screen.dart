import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/routing/app_routes.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/features/models/data/model_import_providers.dart';
import 'package:vaultvoice/features/models/data/model_state_providers.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';
import 'package:vaultvoice/features/models/presentation/model_download_actions.dart';
import 'package:vaultvoice/features/onboarding/data/onboarding_providers.dart';
import 'package:vaultvoice/features/onboarding/data/onboarding_readiness_providers.dart';
import 'package:vaultvoice/features/onboarding/domain/onboarding_keys.dart';
import 'package:vaultvoice/features/onboarding/domain/onboarding_readiness.dart';
import 'package:vaultvoice/features/onboarding/presentation/onboarding_models_step.dart';
import 'package:vaultvoice/features/onboarding/presentation/permission_priming.dart';
import 'package:vaultvoice/features/onboarding/presentation/recording_consent_explainer.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_providers.dart';
import 'package:vaultvoice/features/recording/data/recording_providers.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';
import 'package:vaultvoice/features/settings/presentation/vault_settings_screens.dart';

/// First-launch flow (APP-01): privacy explainer → recording consent
/// (SEC-07 placement, "never records calls") → permission priming →
/// recommended models with download progress → default vault folder →
/// optional first recording.
///
/// Readiness gate: the flow only completes once models (speech + language),
/// a notes destination, microphone access and enough disk space are in
/// place (`OnboardingReadiness`). A step with something missing shows what
/// and a Fix button; Continue stays disabled until it is fixed. The
/// microphone is explained first and only requested when the user taps the
/// Fix/Allow button (SEC-09: never at launch); nothing here records. On a
/// relaunch with `onboarding.completed` already set, the router sends the
/// user back here when the check now fails and this screen opens on the
/// first failing step.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with WidgetsBindingObserver {
  OnboardingStep _step = OnboardingStep.privacy;
  bool _micDenied = false;
  bool _consentChecked = false;

  /// Result of the notification prompt (null = not asked in this flow).
  bool? _notificationsGranted;
  VaultFolderPick? _folder;
  bool _busy = false;
  bool _completedBefore = false;

  static const List<OnboardingStep> _steps = OnboardingStep.values;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_resumeAtFailingStep());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from the OS Settings: the microphone may have been allowed there.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(onboardingReadinessProvider);
    }
  }

  /// Relaunch after completion: open on the first step that fails the check.
  Future<void> _resumeAtFailingStep() async {
    try {
      if (!await ref.read(onboardingStoreProvider).isCompleted()) return;
      if (mounted) setState(() => _completedBefore = true);
      final readiness = await ref.read(onboardingReadinessProvider.future);
      final step = readiness.firstMissingStep;
      if (mounted && step != null && _step == OnboardingStep.privacy) {
        _go(step);
      }
    } on Object {
      // Stay on the first page; the gate still blocks on every step.
    }
  }

  OnboardingReadiness? get _readiness =>
      ref.watch(onboardingReadinessProvider).value;

  List<ReadinessItem> _missingFor(OnboardingStep step) =>
      _readiness?.missingFor(step) ?? const [];

  /// Gated steps stay blocked while the check is loading or failed.
  bool _stepReady(OnboardingStep step) =>
      _readiness != null && _missingFor(step).isEmpty;

  Future<void> _fixMicrophone() => _guard(() async {
    final go = await primeMicrophonePermission(context, ref);
    if (!go || !mounted) return;
    final granted = await ref.read(pcmMicSourceProvider).hasPermission();
    if (mounted) setState(() => _micDenied = !granted);
    ref.invalidate(onboardingReadinessProvider);
  });

  Future<void> _keepInApp() => _guard(() async {
    await ref.read(onboardingStoreProvider).chooseNotesInApp();
    ref.invalidate(onboardingReadinessProvider);
    _next();
  });

  Future<void> _fixModels(List<CatalogModel> missing) async {
    await startModelDownloads(context, ref, missing);
    ref.invalidate(onboardingReadinessProvider);
  }

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
    // Re-check right now: nothing may have been revoked since the steps.
    ref.invalidate(onboardingReadinessProvider);
    final OnboardingReadiness readiness;
    try {
      readiness = await ref.read(onboardingReadinessProvider.future);
    } on Object {
      return;
    }
    if (!mounted) return;
    final step = readiness.firstMissingStep;
    if (step != null) {
      _go(step);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.readinessBlocked)));
      return;
    }
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
          actions: [
            if (_completedBefore)
              IconButton(
                key: const ValueKey('onboarding-open-library'),
                tooltip: l10n.tabLibrary,
                icon: const Icon(Icons.library_books_outlined),
                onPressed: () => const LibraryRoute().go(context),
              ),
          ],
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [_page(context), _gate(context)],
                  ),
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

  /// What is missing on the current step, each with a Fix button.
  Widget _gate(BuildContext context) {
    final l10n = context.l10n;
    final gated = const {
      OnboardingStep.permissions,
      OnboardingStep.models,
      OnboardingStep.folder,
    }.contains(_step);
    if (!gated) return const SizedBox.shrink();
    final async = ref.watch(onboardingReadinessProvider);
    final readiness = async.value;
    if (readiness == null) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: async.hasError
            ? _FixCard(
                message: l10n.readinessError,
                label: l10n.readinessRetry,
                fixKey: const ValueKey('onboarding-fix-retry'),
                onFix: () => ref.invalidate(onboardingReadinessProvider),
              )
            : Center(
                child: CircularProgressIndicator(
                  semanticsLabel: l10n.readinessChecking,
                ),
              ),
      );
    }
    final cards = <Widget>[];
    var modelFixShown = false;
    for (final item in readiness.missingFor(_step)) {
      switch (item) {
        case ReadinessItem.microphone:
          cards.add(
            _micDenied
                ? PermissionDeniedNotice.microphone(
                    key: const ValueKey('onboarding-mic-denied'),
                  )
                : _FixCard(
                    message: l10n.readinessMicMissing,
                    label: l10n.readinessFixMic,
                    fixKey: const ValueKey('onboarding-fix-microphone'),
                    onFix: _busy ? null : _fixMicrophone,
                  ),
          );
        case ReadinessItem.sttModel || ReadinessItem.llmModel:
          final stt = item == ReadinessItem.sttModel;
          final offer = !modelFixShown;
          modelFixShown = true;
          cards.add(
            _FixCard(
              message: stt
                  ? l10n.readinessSttMissing
                  : l10n.readinessLlmMissing,
              label: offer ? l10n.readinessFixModels : null,
              fixKey: ValueKey('onboarding-fix-${item.name}'),
              onFix: offer ? _downloadMissingModels : null,
            ),
          );
        case ReadinessItem.diskSpace:
          cards.add(
            _FixCard(
              message: l10n.readinessSpaceMissing(
                formatBytes(l10n, readiness.requiredBytes),
                formatBytes(l10n, readiness.freeBytes ?? 0),
              ),
              label: l10n.readinessFixSpace,
              fixKey: const ValueKey('onboarding-fix-diskSpace'),
              onFix: () => ref.invalidate(onboardingReadinessProvider),
            ),
          );
        case ReadinessItem.notesFolder:
          cards.add(
            _FixCard(
              message: l10n.readinessFolderMissing,
              label: l10n.readinessFixFolder,
              fixKey: const ValueKey('onboarding-fix-notesFolder'),
              onFix: _busy ? null : _pickFolder,
            ),
          );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final c in cards)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: c,
          ),
      ],
    );
  }

  Future<void> _downloadMissingModels() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final bundle = await ref.read(recommendedModelBundleProvider.future);
    final installed = ref.read(installedModelsProvider).value ?? const [];
    final offline = ref.read(networkDisabledProvider).value ?? false;
    final missing = [
      for (final m in bundle?.models ?? const <CatalogModel>[])
        if (!installed.any((i) => i.type == m.type)) m,
    ];
    if (offline || missing.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.readinessFixModelsUnavailable)),
      );
      return;
    }
    if (!mounted) return;
    await _fixModels(missing);
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
      OnboardingStep.permissions => [
        primary(
          l10n.commonContinue,
          _stepReady(OnboardingStep.permissions) ? _next : null,
        ),
      ],
      OnboardingStep.models => [
        primary(
          l10n.commonContinue,
          _stepReady(OnboardingStep.models) ? _next : null,
        ),
      ],
      OnboardingStep.folder => [
        if (!_stepReady(OnboardingStep.folder))
          TextButton(
            key: const ValueKey('onboarding-keep-in-app'),
            onPressed: _busy ? null : _keepInApp,
            child: Text(l10n.onboardingFolderKeepInApp),
          )
        else
          primary(l10n.commonContinue, _next),
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

/// A missing requirement: message plus an optional Fix button.
class _FixCard extends StatelessWidget {
  const _FixCard({
    required this.message,
    required this.label,
    required this.fixKey,
    required this.onFix,
  });

  final String message;
  final String? label;
  final Key fixKey;
  final VoidCallback? onFix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, color: scheme.onErrorContainer),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
            if (label != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton(
                  key: fixKey,
                  onPressed: onFix,
                  child: Text(label!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
