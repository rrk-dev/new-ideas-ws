import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/features/legal/domain/legal_documents.dart';
import 'package:vaultvoice/features/legal/presentation/legal_document_view.dart';

/// Bundled Terms of Use (LEG-01). Offline asset, like the privacy policy.
class TermsOfUseScreen extends StatelessWidget {
  const TermsOfUseScreen({super.key, this.bundle});

  static const String assetPath = kTermsAsset;

  /// Test seam; defaults to [rootBundle].
  final AssetBundle? bundle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.termsOfUseTitle)),
      body: LegalDocumentView(
        asset: assetPath,
        bundle: bundle,
        loadFailedText: l10n.termsOfUseLoadFailed,
        markdownKey: const ValueKey('terms-of-use-text'),
      ),
    );
  }
}
