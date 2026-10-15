import 'package:flutter/material.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';

/// Shown instead of the whole app when the CPU is below the supported
/// minimum (ARMv8.2-A + dotprod, decided 2026-10-14). Nothing else starts:
/// no recording, no models, no network — so the native engines can never hit
/// an illegal instruction on this phone.
class UnsupportedDeviceScreen extends StatelessWidget {
  const UnsupportedDeviceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.memory,
                    size: 64,
                    color: theme.colorScheme.error,
                    semanticLabel: l10n.unsupportedDeviceIconLabel,
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.unsupportedDeviceTitle,
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.unsupportedDeviceBody,
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.unsupportedDeviceDetail,
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
