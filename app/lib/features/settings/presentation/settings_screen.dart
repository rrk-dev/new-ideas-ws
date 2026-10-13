import 'package:flutter/material.dart';
import 'package:vaultvoice/features/extraction/presentation/llm_debug_screen.dart';
import 'package:vaultvoice/features/settings/presentation/diagnostics_export.dart';

/// Settings tab. Further sections are added by the features that own them.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: ListView(children: const [DiagnosticsExportTile(), LlmDebugTile()]),
  );
}
