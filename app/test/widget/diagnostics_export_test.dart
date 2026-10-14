import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/diagnostics/diagnostics_providers.dart';
import 'package:vaultvoice/core/flavor.dart';
import 'package:vaultvoice/core/flavor_provider.dart';
import 'package:vaultvoice/core/logging/logger.dart';
import 'package:vaultvoice/core/logging/redaction.dart';
import 'package:vaultvoice/core/logging/rotating_file_sink.dart';
import 'package:vaultvoice/core/platform/app_paths.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';
import 'package:vaultvoice/features/settings/presentation/settings_screen.dart';

import '../fakes/fake_settings_store.dart';
import '../fakes/fake_share_service.dart';
import '../helpers/sensitive_samples.dart';

void main() {
  late Directory dir;
  late FakeShareService share;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('vv_diag_ui_');
    share = FakeShareService();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  /// Lets real file IO complete (it does not advance under fake async),
  /// then renders the result.
  Future<void> settleIo(WidgetTester t, {bool Function()? until}) async {
    for (var i = 0; i < 100 && !(until?.call() ?? i >= 10); i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  bool dialogShown() => find.byType(AlertDialog).evaluate().isNotEmpty;

  Future<void> pump(WidgetTester t) async {
    final paths = AppPaths(
      root: Directory('${dir.path}/vv'),
      temp: Directory('${dir.path}/tmp'),
    );
    final sink = RotatingFileSink(paths.logs);
    Logger(sinks: [sink])
      ..info('job', 'job started', fields: {'job': LogId('job-1')})
      ..info('stt', 'segment', fields: {'text': const Sensitive(transcript)});
    await sink.close();
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          flavorProvider.overrideWithValue(Flavor.prod),
          appPathsProvider.overrideWithValue(paths),
          logFileSinkProvider.overrideWithValue(sink),
          shareServiceProvider.overrideWithValue(share),
          // APP-03: the rest of the Settings screen without a database.
          settingsStoreProvider.overrideWithValue(FakeSettingsStore()),
          vaultTargetsProvider.overrideWith((ref) => Stream.value(const [])),
          routingRulesProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    // APP-03 added sections above the diagnostics tile.
    await t.scrollUntilVisible(find.text('Export diagnostics'), 300);
    await t.pumpAndSettle();
  }

  testWidgets('[FND-07/AC2] Export diagnostics previews the contents and '
      'shares only after the user confirms', (t) async {
    await pump(t);
    expect(find.text('Export diagnostics'), findsOneWidget);

    await t.tap(find.text('Export diagnostics'));
    await settleIo(t, until: dialogShown);

    // Preview lists every file of the zip.
    expect(find.byType(AlertDialog), findsOneWidget);
    for (final name in [
      'logs/vv.log',
      'device.json',
      'metrics.jsonl',
      'manifest.json',
    ]) {
      expect(find.text(name), findsOneWidget);
    }
    await t.tap(find.text('logs/vv.log'));
    await t.pump(const Duration(seconds: 1));
    final preview = t
        .widgetList<SelectableText>(find.byType(SelectableText))
        .map((w) => w.data)
        .join();
    expect(preview, contains('job started'));
    expectNoSentinel(preview);
    expect(share.shared, isEmpty, reason: 'nothing shared before confirm');

    await t.tap(find.text('Share'));
    await settleIo(t, until: () => share.shared.isNotEmpty);
    expect(find.text('Could not export diagnostics.'), findsNothing);
    expect(share.shared, hasLength(1));
    expect(share.shared.single.mimeType, 'application/zip');
    expect(File(share.shared.single.path).existsSync(), isTrue);
  });

  testWidgets('[FND-07/AC2] cancelling the preview shares nothing', (t) async {
    await pump(t);
    await t.tap(find.text('Export diagnostics'));
    await settleIo(t, until: dialogShown);
    await t.tap(find.text('Cancel'));
    await settleIo(t);
    expect(find.byType(AlertDialog), findsNothing);
    expect(share.shared, isEmpty);
    expect(Directory('${dir.path}/tmp').existsSync(), isFalse);
  });
}
