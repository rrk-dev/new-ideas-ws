import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/app_info.dart';
import 'package:vaultvoice/core/crash/crash_providers.dart';
import 'package:vaultvoice/core/crash/crash_store.dart';
import 'package:vaultvoice/core/flavor_provider.dart';
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
      try {
        final outcome = await notifier.share(report, origin: origin);
        if (outcome == ShareOutcome.unavailable) {
          messenger?.showSnackBar(
            const SnackBar(content: Text('Sharing is not available.')),
          );
        }
      } on Object {
        messenger?.showSnackBar(
          const SnackBar(content: Text('Could not share the crash report.')),
        );
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
          ? '$kAppName closed unexpectedly'
          : '$kAppName hit an unexpected error',
    ),
    content: const Text(
      'A crash report was saved on this device. It contains only technical '
      'details (error type, code addresses, app and OS version) — no '
      'recordings, transcripts or notes. You can review it and send it to '
      'the developers, for example by email. Nothing is sent automatically.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('Not now'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(true),
        child: const Text('Review report'),
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
      title: const Text('Crash report'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              '${report.name} · '
              '${DiagnosticsPreviewDialog.formatBytes(content.length)}. '
              'This is the complete file. Nothing leaves this device unless '
              'you choose a destination in the share sheet.',
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
          child: const Text('Discard'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(CrashReportAction.share),
          child: const Text('Share'),
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
          title: const Text('Crash reports'),
          subtitle: Text(
            reports.isEmpty
                ? 'None saved. Reports stay on this device until you share '
                      'them.'
                : '${reports.length} saved on this device. Tap to review and '
                      'share.',
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
        title: const Text('Force native crash (dev)'),
        subtitle: const Text('Kills the app via SIGSEGV in libvv_native.'),
        onTap: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('Crash the app now?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(c).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(c).pop(true),
                  child: const Text('Crash'),
                ),
              ],
            ),
          );
          if (ok ?? false) ref.read(nativeCrashCaptureProvider).forceCrash();
        },
      ),
      ListTile(
        leading: const Icon(Icons.error_outline),
        title: const Text('Throw uncaught Dart error (dev)'),
        onTap: () =>
            unawaited(Future<void>(() => throw StateError('dev crash test'))),
      ),
    ],
  );
}
