import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';

/// Bundled privacy policy (SEC-06). Read from the asset, so it works offline
/// and never opens a browser or network connection.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key, this.bundle});

  static const assetPath = 'assets/legal/privacy_policy.md';

  /// Test seam; defaults to [rootBundle].
  final AssetBundle? bundle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacyPolicyTitle)),
      body: FutureBuilder<String>(
        future: (bundle ?? rootBundle).loadString(assetPath),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text(l10n.privacyPolicyLoadFailed));
          }
          final text = snap.data;
          if (text == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return Markdown(
            key: const ValueKey('privacy-policy-text'),
            data: text,
            padding: const EdgeInsets.all(AppSpacing.lg),
          );
        },
      ),
    );
  }
}
