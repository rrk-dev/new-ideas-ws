import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/diagnostics/diagnostics_bundle.dart';
import 'package:vaultvoice/core/diagnostics/diagnostics_providers.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/features/beta/presentation/beta_feedback_screen.dart';

import '../fakes/fake_share_service.dart';

void main() {
  final en = lookupAppLocalizations(kFallbackLocale);

  Future<FakeShareService> pump(WidgetTester t) async {
    final share = FakeShareService();
    await t.pumpWidget(
      ProviderScope(
        overrides: [shareServiceProvider.overrideWithValue(share)],
        child: const MaterialApp(home: BetaFeedbackScreen()),
      ),
    );
    return share;
  }

  testWidgets('share stays disabled until there is a message', (t) async {
    await pump(t);
    final button = t.widget<FilledButton>(
      find.byKey(const ValueKey('beta-feedback-share')),
    );
    expect(button.onPressed, isNull);
    expect(find.text(en.betaFeedbackTitle), findsOneWidget);
    expect(find.text(en.betaFeedbackIncludeDiagnostics), findsOneWidget);
  });

  testWidgets('share sends the note and optional score without a zip', (
    t,
  ) async {
    final share = await pump(t);
    await t.enterText(
      find.byKey(const ValueKey('beta-feedback-message')),
      'The sample note was hard to find.',
    );
    await t.pump();
    await t.tap(find.widgetWithText(OutlinedButton, '4'));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('beta-feedback-share')));
    await t.pumpAndSettle();
    expect(share.payloads, hasLength(1));
    expect(share.payloads.single.path, isNull);
    expect(share.payloads.single.subject, en.betaFeedbackEmailSubject);
    expect(share.payloads.single.text, contains('hard to find'));
    expect(share.payloads.single.text, contains('4/5'));
    expect(find.text(en.betaFeedbackShared), findsOneWidget);
  });

  testWidgets('diagnostics are previewed and skipped when the tester cancels', (
    t,
  ) async {
    final share = FakeShareService();
    final bundle = DiagnosticsBundle([
      DiagnosticsEntry(
        'logs/vv.log',
        Uint8List.fromList(utf8.encode('{"msg":"app start"}')),
      ),
    ], createdAt: DateTime.utc(2026, 10, 14));
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          shareServiceProvider.overrideWithValue(share),
          betaDiagnosticsPrepareProvider.overrideWithValue(() async => bundle),
          betaDiagnosticsZipProvider.overrideWithValue(
            (b) async => '/tmp/should-not-be-used.zip',
          ),
        ],
        child: const MaterialApp(home: BetaFeedbackScreen()),
      ),
    );
    await t.enterText(
      find.byKey(const ValueKey('beta-feedback-message')),
      'Logs only, please.',
    );
    await t.pump();
    await t.tap(find.byKey(const ValueKey('beta-feedback-diagnostics')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('beta-feedback-share')));
    await t.pumpAndSettle();
    expect(find.text('logs/vv.log'), findsOneWidget);
    await t.tap(find.text(en.commonCancel));
    await t.pumpAndSettle();
    expect(share.payloads, isEmpty);
    expect(find.text(en.betaFeedbackDismissed), findsOneWidget);
  });

  testWidgets('confirming the diagnostics preview attaches the zip', (t) async {
    final share = FakeShareService();
    final bundle = DiagnosticsBundle([
      DiagnosticsEntry(
        'device.json',
        Uint8List.fromList(utf8.encode('{"os":"test"}')),
      ),
    ], createdAt: DateTime.utc(2026, 10, 14));
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          shareServiceProvider.overrideWithValue(share),
          betaDiagnosticsPrepareProvider.overrideWithValue(() async => bundle),
          betaDiagnosticsZipProvider.overrideWithValue((b) async {
            expect(b['device.json'], isNotNull);
            return '/tmp/vaultvoice-diagnostics-test.zip';
          }),
        ],
        child: const MaterialApp(home: BetaFeedbackScreen()),
      ),
    );
    await t.enterText(
      find.byKey(const ValueKey('beta-feedback-message')),
      'Logs only, please.',
    );
    await t.pump();
    await t.tap(find.byKey(const ValueKey('beta-feedback-diagnostics')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('beta-feedback-share')));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, en.diagnosticsShare).last);
    await t.pumpAndSettle();
    expect(share.payloads, hasLength(1));
    expect(share.payloads.single.path, '/tmp/vaultvoice-diagnostics-test.zip');
    expect(
      share.payloads.single.text,
      contains(en.betaFeedbackDiagnosticsNote),
    );
    expect(share.payloads.single.text, isNot(contains('{"os":"test"}')));
  });
}
