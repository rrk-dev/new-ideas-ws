import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/features/legal/data/legal_providers.dart';
import 'package:vaultvoice/features/legal/domain/legal_documents.dart';
import 'package:vaultvoice/features/legal/presentation/legal_document_view.dart';

/// Covers the whole app with the acceptance screen until the user has
/// accepted the current [kLegalVersion] (LEG-01). The app below stays mounted
/// but is not painted, not hit-testable and excluded from semantics. Nothing
/// here touches the network, and the OS permission dialogs are unaffected.
class LegalGate extends ConsumerWidget {
  const LegalGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final required = ref.watch(legalAcceptanceRequiredProvider).value ?? false;
    return Stack(
      fit: StackFit.expand,
      children: [
        Visibility(
          visible: !required,
          maintainState: true,
          maintainAnimation: true,
          child: ExcludeSemantics(excluding: required, child: child),
        ),
        if (required) const LegalAcceptanceScreen(),
      ],
    );
  }
}

/// First-run (and new-version) acceptance: age 21+ and Terms + Privacy, each
/// confirmed by an explicit tap. The documents open in place because the gate
/// sits above the app's navigator.
class LegalAcceptanceScreen extends ConsumerStatefulWidget {
  const LegalAcceptanceScreen({super.key});

  @override
  ConsumerState<LegalAcceptanceScreen> createState() =>
      _LegalAcceptanceScreenState();
}

class _LegalAcceptanceScreenState extends ConsumerState<LegalAcceptanceScreen> {
  bool _age = false;
  bool _agree = false;
  bool _busy = false;
  bool _failed = false;
  String? _reading;

  Future<void> _accept() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    final result = await ref.read(legalStoreProvider).accept();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failed = !result.isOk;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final reading = _reading;
    if (reading != null) {
      final terms = reading == kTermsAsset;
      return Scaffold(
        key: const ValueKey('legal-reader'),
        appBar: AppBar(
          leading: BackButton(onPressed: () => setState(() => _reading = null)),
          title: Text(terms ? l10n.termsOfUseTitle : l10n.privacyPolicyTitle),
        ),
        body: LegalDocumentView(
          asset: reading,
          loadFailedText: terms
              ? l10n.termsOfUseLoadFailed
              : l10n.privacyPolicyLoadFailed,
          markdownKey: ValueKey(terms ? 'legal-terms' : 'legal-privacy'),
        ),
      );
    }
    return Scaffold(
      key: const ValueKey('legal-gate'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(l10n.legalGateTitle, style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.legalGateIntro),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.legalRecordingResponsibility),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              children: [
                TextButton(
                  key: const ValueKey('legal-read-terms'),
                  onPressed: () => setState(() => _reading = kTermsAsset),
                  child: Text(l10n.legalReadTerms),
                ),
                TextButton(
                  key: const ValueKey('legal-read-privacy'),
                  onPressed: () => setState(() => _reading = kPrivacyAsset),
                  child: Text(l10n.legalReadPrivacy),
                ),
              ],
            ),
            CheckboxListTile(
              key: const ValueKey('legal-age'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _age,
              onChanged: (v) => setState(() => _age = v ?? false),
              title: Text(l10n.legalAgeConfirm),
            ),
            CheckboxListTile(
              key: const ValueKey('legal-agree'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _agree,
              onChanged: (v) => setState(() => _agree = v ?? false),
              title: Text(l10n.legalAgreeConfirm),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_failed)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  l10n.legalSaveFailed,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            FilledButton(
              key: const ValueKey('legal-accept'),
              onPressed: _age && _agree && !_busy ? _accept : null,
              child: Text(l10n.legalAgreeButton),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.legalDeclineHint, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
