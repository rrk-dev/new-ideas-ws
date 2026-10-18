import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/features/legal/domain/legal_documents.dart';
import 'package:vaultvoice/features/legal/presentation/legal_document_view.dart';

/// Bundled privacy policy (SEC-06, LEG-01). Read from the asset, so it works
/// offline and never opens a browser or network connection.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key, this.bundle});

  static const String assetPath = kPrivacyAsset;

  /// Test seam; defaults to [rootBundle].
  final AssetBundle? bundle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacyPolicyTitle)),
      body: LegalDocumentView(
        asset: assetPath,
        bundle: bundle,
        loadFailedText: l10n.privacyPolicyLoadFailed,
        markdownKey: const ValueKey('privacy-policy-text'),
      ),
    );
  }
}
