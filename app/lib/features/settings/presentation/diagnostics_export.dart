import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/diagnostics/diagnostics_bundle.dart';
import 'package:vaultvoice/core/diagnostics/diagnostics_providers.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/logging/redaction.dart';
import 'package:vaultvoice/core/platform/share_service.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';

/// Settings entry: "Export diagnostics" → preview → OS share sheet.
///
/// Strictly user-initiated; nothing is shared until the user taps Share in
/// the preview and picks a destination in the system sheet.
class DiagnosticsExportTile extends ConsumerStatefulWidget {
  const DiagnosticsExportTile({super.key});

  @override
  ConsumerState<DiagnosticsExportTile> createState() =>
      _DiagnosticsExportTileState();
}

class _DiagnosticsExportTileState extends ConsumerState<DiagnosticsExportTile> {
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final logger = ref.read(loggerProvider);
    try {
      final exporter = ref.read(diagnosticsExporterProvider);
      final bundle = await exporter.prepare();
      if (!mounted) return;
      setState(() => _busy = false);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => DiagnosticsPreviewDialog(bundle: bundle),
      );
      if (confirmed != true || !mounted) return;
      setState(() => _busy = true);
      final box = context.findRenderObject() as RenderBox?;
      final origin = box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size;
      final outcome = await exporter.share(bundle, origin: origin);
      if (outcome == ShareOutcome.unavailable) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.diagnosticsShareUnavailable)),
        );
      }
    } on Object catch (e) {
      logger.error(
        'diagnostics',
        'diagnostics export failed',
        fields: {'type': LogId(e.runtimeType.toString())},
      );
      messenger.showSnackBar(SnackBar(content: Text(l10n.diagnosticsFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.bug_report_outlined),
    title: Text(context.l10n.diagnosticsTitle),
    subtitle: Text(context.l10n.diagnosticsSubtitle),
    trailing: _busy
        ? const SizedBox.square(
            dimension: AppSpacing.lg,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.ios_share),
    enabled: !_busy,
    onTap: _export,
  );
}

/// Shows exactly what the diagnostics zip contains before it is shared.
/// Pops `true` when the user taps Share.
class DiagnosticsPreviewDialog extends StatelessWidget {
  const DiagnosticsPreviewDialog({required this.bundle, super.key});

  final DiagnosticsBundle bundle;

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(context.l10n.diagnosticsTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              context.l10n.diagnosticsPreviewSummary(
                bundle.entries.length,
                formatBytes(bundle.totalBytes),
              ),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final entry in bundle.entries)
              ExpansionTile(
                key: ValueKey(entry.name),
                tilePadding: EdgeInsets.zero,
                title: Text(entry.name),
                subtitle: Text(formatBytes(entry.bytes.length)),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: SelectableText(
                      entry.preview,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(context.l10n.diagnosticsShare),
        ),
      ],
    );
  }
}
