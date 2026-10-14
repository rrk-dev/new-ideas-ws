import 'package:flutter/material.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';

/// First-run recording-consent explainer and the "never records calls"
/// statement (SEC-07 / SEC-09). APP-01 only places it in the flow; SEC-07
/// owns the wording (pending product/legal review) and may replace this
/// widget's body without touching onboarding.
class RecordingConsentExplainer extends StatelessWidget {
  const RecordingConsentExplainer({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    Widget point(IconData icon, String text) => Padding(
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        point(Icons.groups_outlined, l10n.consentExplainerAsk),
        point(Icons.gavel_outlined, l10n.consentExplainerLaws),
        point(Icons.fact_check_outlined, l10n.consentExplainerConfirm),
        Semantics(
          container: true,
          child: point(Icons.phone_disabled_outlined, l10n.consentNeverCalls),
        ),
      ],
    );
  }
}
