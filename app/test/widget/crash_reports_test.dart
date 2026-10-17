import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/crash/crash_providers.dart';
import 'package:vaultvoice/core/crash/crash_store.dart';
import 'package:vaultvoice/core/crash/native_crash_capture.dart';
import 'package:vaultvoice/core/diagnostics/diagnostics_providers.dart';
import 'package:vaultvoice/core/flavor.dart';
import 'package:vaultvoice/core/flavor_provider.dart';
import 'package:vaultvoice/core/platform/app_paths.dart';
import 'package:vaultvoice/core/platform/share_service.dart';
import 'package:vaultvoice/features/settings/presentation/crash_reports.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';
import 'package:vaultvoice/features/settings/presentation/settings_screen.dart';

import '../fakes/fake_settings_store.dart';
import '../fakes/fake_share_service.dart';

const _report =
    '*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***\n'
    'VaultVoice native crash report v1\n'
    'signal 11 (SIGSEGV), code 1, fault addr 0x0000000000000000\n'
    'backtrace:\n'
    '    #00 pc 0000000000001f40  libvv_native.so (BuildId: ab)\n'
    'end of report\n';

class _CountingNative implements NativeCrashCapture {
  int forced = 0;

  @override
  bool install({required String reportPath, required String appBuild}) => true;

  @override
  void forceCrash() => forced++;
}

void main() {
  late Directory dir;
  late AppPaths paths;
  late CrashReportStore store;
  late FakeShareService share;
  late _CountingNative native;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('vv_crash_ui_');
    paths = AppPaths(
      root: Directory('${dir.path}/vv'),
      temp: Directory('${dir.path}/tmp'),
    );
    store = CrashReportStore(paths.crashReports)..ensureDirectory();
    share = FakeShareService();
    native = _CountingNative();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  /// The crash section sits in APP-03's Privacy section, below the fold.
  Future<void> scrollTo(WidgetTester t, Finder f) async {
    await t.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable));
    await t.pumpAndSettle();
  }

  CrashReport seedNative() {
    store.currentNativeFile.writeAsStringSync(_report);
    return store.harvestNative()!;
  }

  Future<void> pumpApp(
    WidgetTester t, {
    Flavor flavor = Flavor.prod,
    Widget home = const Scaffold(body: Text('home')),
  }) async {
    final key = GlobalKey<NavigatorState>();
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          flavorProvider.overrideWithValue(flavor),
          appPathsProvider.overrideWithValue(paths),
          crashReportStoreProvider.overrideWithValue(store),
          shareServiceProvider.overrideWithValue(share),
          nativeCrashCaptureProvider.overrideWithValue(native),
          // APP-03's Settings screen (integration wave 2) needs its stores.
          settingsStoreProvider.overrideWithValue(FakeSettingsStore()),
          vaultTargetsProvider.overrideWith((ref) => Stream.value(const [])),
          routingRulesProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp(
          navigatorKey: key,
          builder: (context, child) =>
              CrashReportGate(navigatorKey: key, child: child!),
          home: home,
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('no saved report → no prompt', (t) async {
    await pumpApp(t);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('next launch: prompt → preview of the exact file → share '
      'sheet; shared report is removed', (t) async {
    final report = seedNative();
    await pumpApp(t);

    expect(find.text('Lumen closed unexpectedly'), findsOneWidget);
    expect(find.textContaining('no recordings, transcripts'), findsOneWidget);
    expect(share.shared, isEmpty, reason: 'nothing is sent automatically');

    await t.tap(find.text('Review report'));
    await t.pumpAndSettle();
    final content = t.widget<SelectableText>(
      find.byKey(const ValueKey('crash-report-content')),
    );
    expect(content.data, _report, reason: 'preview shows the whole file');
    expect(share.shared, isEmpty);

    await t.tap(find.text('Share'));
    await t.pumpAndSettle();
    final sent = share.shared.single;
    expect(sent.mimeType, 'text/plain');
    expect(sent.subject, 'Lumen crash report');
    expect(sent.path, startsWith(paths.crashShare.path));
    expect(File(sent.path).readAsStringSync(), _report);
    expect(report.file.existsSync(), isFalse);
    expect(store.list(), isEmpty);
  });

  testWidgets('dismissed share sheet keeps the report', (t) async {
    share.outcome = ShareOutcome.dismissed;
    seedNative();
    await pumpApp(t);
    await t.tap(find.text('Review report'));
    await t.pumpAndSettle();
    await t.tap(find.text('Share'));
    await t.pumpAndSettle();
    expect(share.shared, hasLength(1));
    expect(store.list(), hasLength(1));
  });

  testWidgets('"Not now" offers each report only once; it stays in '
      'Settings', (t) async {
    seedNative();
    await pumpApp(t);
    await t.tap(find.text('Not now'));
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(store.unseen(), isEmpty);
    expect(store.list(), hasLength(1));

    // Relaunch: no second prompt; Settings lists the saved report.
    await t.pumpWidget(const SizedBox());
    await pumpApp(t, home: const SettingsScreen());
    expect(find.byType(AlertDialog), findsNothing);
    await scrollTo(t, find.text('Crash reports'));
    expect(find.text('Crash reports'), findsOneWidget);
    expect(find.textContaining('1 saved on this device'), findsOneWidget);

    await t.tap(find.text('Crash reports'));
    await t.pumpAndSettle();
    await t.tap(find.text('Discard'));
    await t.pumpAndSettle();
    expect(store.list(), isEmpty);
    expect(find.textContaining('None saved'), findsOneWidget);
    expect(share.shared, isEmpty);
  });

  testWidgets('Dart error report gets its own wording', (t) async {
    store.writeDart('*** VaultVoice Dart error report v1\nend of report\n');
    await pumpApp(t);
    expect(find.text('Lumen hit an unexpected error'), findsOneWidget);
  });

  testWidgets('forced-crash tiles exist only in the dev flavor', (t) async {
    await pumpApp(t, home: const SettingsScreen());
    expect(find.text('Force native crash (dev)'), findsNothing);

    await t.pumpWidget(const SizedBox());
    await pumpApp(t, flavor: Flavor.dev, home: const SettingsScreen());
    await scrollTo(t, find.text('Force native crash (dev)'));
    await t.tap(find.text('Force native crash (dev)'));
    await t.pumpAndSettle();
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(native.forced, 0);
    await t.tap(find.text('Force native crash (dev)'));
    await t.pumpAndSettle();
    await t.tap(find.text('Crash'));
    await t.pumpAndSettle();
    expect(native.forced, 1);
  });
}
