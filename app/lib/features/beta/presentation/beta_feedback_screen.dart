import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/diagnostics/diagnostics_bundle.dart';
import 'package:vaultvoice/core/diagnostics/diagnostics_providers.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/features/beta/data/beta_feedback_sender.dart';
import 'package:vaultvoice/features/beta/domain/beta_feedback.dart';
import 'package:vaultvoice/features/settings/presentation/diagnostics_export.dart';

/// Prepares the FND-07 bundle. Read only after the tester opts in.
final betaDiagnosticsPrepareProvider =
    Provider<Future<DiagnosticsBundle> Function()>((ref) {
      return ref.watch(diagnosticsExporterProvider).prepare;
    });

/// Writes that bundle to the app-private diagnostics directory.
final betaDiagnosticsZipProvider =
    Provider<Future<String> Function(DiagnosticsBundle)>((ref) {
      final directory = ref.watch(diagnosticsExporterProvider).exportDirectory;
      return (bundle) async => (await bundle.writeZip(directory)).path;
    });

/// Settings → Send beta feedback (REL-04).
///
/// Share opens the OS sheet (Mail uses the subject). Diagnostics are the
/// FND-07 zip and only after the preview dialog. Nothing is uploaded.
class BetaFeedbackScreen extends ConsumerStatefulWidget {
  const BetaFeedbackScreen({super.key});

  @override
  ConsumerState<BetaFeedbackScreen> createState() => _BetaFeedbackScreenState();
}

class _BetaFeedbackScreenState extends ConsumerState<BetaFeedbackScreen> {
  final _message = TextEditingController();
  int? _score;
  bool _includeDiagnostics = false;
  bool _busy = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final draft = BetaFeedbackDraft(
      message: _message.text,
      subject: l10n.betaFeedbackEmailSubject,
      satisfactionOutOfFive: _score,
      satisfactionLine: _score == null
          ? null
          : l10n.betaFeedbackSatisfactionLine(_score!),
      diagnosticsNote: _includeDiagnostics
          ? l10n.betaFeedbackDiagnosticsNote
          : null,
    );
    if (!draft.hasMessage || !draft.satisfactionValid) return;

    setState(() => _busy = true);
    try {
      DiagnosticsBundle? bundle;
      if (_includeDiagnostics) {
        bundle = await ref.read(betaDiagnosticsPrepareProvider)();
        if (!mounted) return;
        setState(() => _busy = false);
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => DiagnosticsPreviewDialog(bundle: bundle!),
        );
        if (confirmed != true || !mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.betaFeedbackDismissed)),
          );
          return;
        }
        setState(() => _busy = true);
      }
      final box = context.findRenderObject() as RenderBox?;
      final origin = box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size;
      final outcome =
          await BetaFeedbackSender(
            share: ref.read(shareServiceProvider),
            logger: ref.read(loggerProvider),
          ).send(
            draft,
            diagnostics: bundle,
            zipPath: bundle == null
                ? null
                : ref.read(betaDiagnosticsZipProvider),
            origin: origin,
          );
      if (!mounted) return;
      final text = switch (outcome) {
        BetaFeedbackOutcome.shared => l10n.betaFeedbackShared,
        BetaFeedbackOutcome.dismissed => l10n.betaFeedbackDismissed,
        BetaFeedbackOutcome.unavailable => l10n.betaFeedbackUnavailable,
      };
      messenger.showSnackBar(SnackBar(content: Text(text)));
    } on Object catch (e) {
      logBetaFeedbackFailure(ref.read(loggerProvider), e);
      messenger.showSnackBar(SnackBar(content: Text(l10n.betaFeedbackFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canShare = _message.text.trim().isNotEmpty && !_busy;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.betaFeedbackTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(l10n.betaFeedbackIntro),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey('beta-feedback-message'),
            controller: _message,
            minLines: 4,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.betaFeedbackMessageLabel,
              hintText: l10n.betaFeedbackMessageHint,
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.betaFeedbackSatisfaction,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(l10n.betaFeedbackSatisfactionHelp),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (var n = 1; n <= 5; n++)
                _ScoreButton(
                  score: n,
                  selected: _score == n,
                  label: l10n.betaFeedbackScore(n),
                  onPressed: _busy
                      ? null
                      : () => setState(() => _score = _score == n ? null : n),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          CheckboxListTile(
            key: const ValueKey('beta-feedback-diagnostics'),
            contentPadding: EdgeInsets.zero,
            value: _includeDiagnostics,
            onChanged: _busy
                ? null
                : (v) => setState(() => _includeDiagnostics = v ?? false),
            title: Text(l10n.betaFeedbackIncludeDiagnostics),
            subtitle: Text(l10n.betaFeedbackIncludeDiagnosticsSubtitle),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              key: const ValueKey('beta-feedback-share'),
              onPressed: canShare ? _share : null,
              child: _busy
                  ? const SizedBox.square(
                      dimension: AppSpacing.lg,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.betaFeedbackShare),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreButton extends StatelessWidget {
  const _ScoreButton({
    required this.score,
    required this.selected,
    required this.label,
    required this.onPressed,
  });

  final int score;
  final bool selected;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final child = Text('$score');
    final style = OutlinedButton.styleFrom(
      minimumSize: const Size(kMinTapTarget, kMinTapTarget),
    );
    if (selected) {
      return FilledButton(
        style: FilledButton.styleFrom(
          minimumSize: const Size(kMinTapTarget, kMinTapTarget),
        ),
        onPressed: onPressed,
        child: Semantics(label: label, excludeSemantics: true, child: child),
      );
    }
    return OutlinedButton(
      style: style,
      onPressed: onPressed,
      child: Semantics(label: label, excludeSemantics: true, child: child),
    );
  }
}
