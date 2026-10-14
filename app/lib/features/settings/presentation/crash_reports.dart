import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/app_info.dart';
import 'package:vaultvoice/core/crash/crash_providers.dart';
import 'package:vaultvoice/core/crash/crash_store.dart';
import 'package:vaultvoice/core/flavor_provider.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/platform/share_service.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/features/settings/presentation/diagnostics_export.dart';

/// What the user chose in [CrashReportPreviewDialog].
enum CrashReportAction { share, discard }

/// On launch, offers crash reports saved by the previous run(s) once:
/// "share crash report?" → preview → OS share sheet (REL-02).
///
/// Mounted around the router (`MaterialApp.builder`); dialogs use
/// [navigatorKey] because this widget sits above the app's navigator.
class CrashReportGate extends ConsumerStatefulWidget {
  const CrashReportGate({
    required this.navigatorKey,
    required this.child,
    super.key,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  ConsumerState<CrashReportGate> createState() => _CrashReportGateState();
}

class _CrashReportGateState extends ConsumerState<CrashReportGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_offer()));
  }

  Future<void> _offer() async {
    final context = widget.navigatorKey.currentContext;
    if (context == null || !mounted) return;
    final unseen = [...ref.read(crashReportsProvider.notifier).takeUnseen()]
      ..sort((a, b) => a.kind.index.compareTo(b.kind.index)); // native first
    if (unseen.isEmpty) return;
    final review = await showDialog<bool>(
      context: context,
      builder: (_) => CrashReportPromptDialog(report: unseen.first),
    );
    if (review != true || !context.mounted) return;
    await reviewCrashReport(context, ref, unseen.first);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Preview → share/discard for one report. Nothing leaves the device unless
/// the user taps Share and then picks a destination in the system sheet.
Future<void> reviewCrashReport(
  BuildContext context,
  WidgetRef ref,
  CrashReport report,
) async {
  final String text;
  try {
    text = report.readText();
  } on Object {
    ref.read(crashReportsProvider.notifier).refresh();
    return;
  }
  if (!context.mounted) return;
  final action = await showDialog<CrashReportAction>(
    context: context,
    builder: (_) => CrashReportPreviewDialog(report: report, content: text),
  );
  if (!context.mounted) return;
  final notifier = ref.read(crashReportsProvider.notifier);
  switch (action) {
    case CrashReportAction.share:
      final box = context.findRenderObject() as RenderBox?;
      final origin = box == null || !box.hasSize
          ? null
          : box.localToGlobal(Offset.zero) & box.size;
      final messenger = ScaffoldMessenger.maybeOf(context);
      final l10n = context.l10n;
      try {
        final outcome = await notifier.share(report, origin: origin);
        if (outcome == ShareOutcome.unavailable) {
          messenger?.showSnackBar(
            SnackBar(content: Text(l10n.crashShareUnavailable)),
          );
        }
      } on Object {
        messenger?.showSnackBar(SnackBar(content: Text(l10n.crashShareFailed)));
      }
    case CrashReportAction.discard:
      notifier.discard(report);
    case null:
      break;
  }
}

/// "The app closed unexpectedly — share a crash report?" Pops `true` for
/// Review.
class CrashReportPromptDialog extends StatelessWidget {
  const CrashReportPromptDialog({required this.report, super.key});

  final CrashReport report;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      report.kind == CrashKind.native
          ? context.l10n.crashPromptTitleNative(kAppName)
          : context.l10n.crashPromptTitleDart(kAppName),
    ),
    content: Text(context.l10n.crashPromptBody),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: Text(context.l10n.crashPromptNotNow),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(true),
        child: Text(context.l10n.crashPromptReview),
      ),
    ],
  );
}

/// Shows the exact file that would be shared.
class CrashReportPreviewDialog extends StatelessWidget {
  const CrashReportPreviewDialog({
    required this.report,
    required this.content,
    super.key,
  });

  final CrashReport report;
  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(context.l10n.crashPreviewTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              context.l10n.crashPreviewInfo(
                report.name,
                DiagnosticsPreviewDialog.formatBytes(content.length),
              ),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: SelectableText(
                content,
                key: const ValueKey('crash-report-content'),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(CrashReportAction.discard),
          child: Text(context.l10n.crashPreviewDiscard),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(CrashReportAction.share),
          child: Text(context.l10n.crashPreviewShare),
        ),
      ],
    );
  }
}

/// Settings hook (REL-02): saved crash reports + dev-only crash triggers.
/// The Settings screen owner decides where to place it.
class CrashReportSettingsSection extends ConsumerWidget {
  const CrashReportSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(crashReportsProvider);
    final dev = ref.watch(flavorProvider).isDev;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.report_outlined),
          title: Text(context.l10n.crashSettingsTitle),
          subtitle: Text(
            reports.isEmpty
                ? context.l10n.crashSettingsNone
                : context.l10n.crashSettingsCount(reports.length),
          ),
          enabled: reports.isNotEmpty,
          onTap: reports.isEmpty
              ? null
              : () => reviewCrashReport(context, ref, reports.first),
        ),
        if (dev) const _DevCrashTiles(),
      ],
    );
  }
}

/// Dev flavor only: trigger crashes to verify capture on a device.
class _DevCrashTiles extends ConsumerWidget {
  const _DevCrashTiles();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      ListTile(
        leading: const Icon(Icons.dangerous_outlined),
        title: Text(context.l10n.crashDevForceNative),
        subtitle: Text(context.l10n.crashDevForceNativeSubtitle),
        onTap: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: Text(context.l10n.crashDevConfirmTitle),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(c).pop(false),
                  child: Text(context.l10n.commonCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(c).pop(true),
                  child: Text(context.l10n.crashDevConfirm),
                ),
              ],
            ),
          );
          if (ok ?? false) ref.read(nativeCrashCaptureProvider).forceCrash();
        },
      ),
      ListTile(
        leading: const Icon(Icons.error_outline),
        title: Text(context.l10n.crashDevThrowDart),
        onTap: () =>
            unawaited(Future<void>(() => throw StateError('dev crash test'))),
      ),
    ],
  );
}
