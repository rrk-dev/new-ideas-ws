import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/app.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/features/device_support/data/device_support_providers.dart';
import 'package:vaultvoice/features/device_support/domain/device_support.dart';
import 'package:vaultvoice/features/device_support/presentation/unsupported_device_screen.dart';

import '../fakes/fake_device_capabilities.dart';

void main() {
  testWidgets('an unsupported CPU (mocked) shows only the "This device '
      'isn’t supported" screen at launch', (t) async {
    final caps = FakeDeviceCapabilities(supported: false);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          deviceSupportedProvider.overrideWithValue(isDeviceSupported(caps)),
        ],
        child: const App(),
      ),
    );
    await t.pumpAndSettle();
    final l10n = lookupAppLocalizations(kFallbackLocale);
    expect(find.byType(UnsupportedDeviceScreen), findsOneWidget);
    expect(find.text(l10n.unsupportedDeviceTitle), findsOneWidget);
    expect(find.text('This device isn’t supported'), findsOneWidget);
    // No app shell: no tabs, no record button.
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text(l10n.tabRecord), findsNothing);
  });
}
