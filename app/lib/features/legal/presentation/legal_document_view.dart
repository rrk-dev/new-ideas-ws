import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/features/legal/domain/legal_documents.dart';

/// A bundled legal document as Markdown. Read from the asset, so it works
/// offline and never opens a browser or a network connection. The draft
/// banner is hidden once the release flag is set.
class LegalDocumentView extends StatefulWidget {
  const LegalDocumentView({
    required this.asset,
    required this.loadFailedText,
    required this.markdownKey,
    this.bundle,
    this.released = kLegalReleaseApproved,
    super.key,
  });

  final String asset;
  final String loadFailedText;
  final Key markdownKey;

  /// Test seam; defaults to [rootBundle].
  final AssetBundle? bundle;
  final bool released;

  @override
  State<LegalDocumentView> createState() => _LegalDocumentViewState();
}

class _LegalDocumentViewState extends State<LegalDocumentView> {
  late final Future<String> _text = (widget.bundle ?? rootBundle).loadString(
    widget.asset,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _text,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text(widget.loadFailedText));
        final text = snap.data;
        if (text == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return Markdown(
          key: widget.markdownKey,
          data: legalDisplayText(text, released: widget.released),
          padding: const EdgeInsets.all(AppSpacing.lg),
        );
      },
    );
  }
}
