import 'package:flutter/material.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';

/// Helper text for an [InputDecoration.helper] with a little extra space under
/// the field, so the text never touches the field border (keeps it legible and
/// lets contrast checks sample a clean background on every platform's font
/// metrics).
class FieldHelper extends StatelessWidget {
  const FieldHelper(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xs),
    child: Text(text),
  );
}
