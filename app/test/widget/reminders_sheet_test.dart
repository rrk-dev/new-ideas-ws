import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/l10n/gen/app_localizations.dart';
import 'package:vaultvoice/core/platform/app_settings_launcher.dart';
import 'package:vaultvoice/features/library/data/library_providers.dart';
import 'package:vaultvoice/features/library/presentation/action_items_screen.dart';
import 'package:vaultvoice/features/licensing/data/licensing_providers.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/licensing/domain/feature_matrix.dart';
import 'package:vaultvoice/features/licensing/domain/paywall.dart';
import 'package:vaultvoice/features/licensing/presentation/feature_gate.dart';
import 'package:vaultvoice/features/reminders/data/reminders_providers.dart';
import 'package:vaultvoice/features/reminders/domain/reminders_platform.dart';
import 'package:vaultvoice/features/reminders/presentation/reminders_sheet.dart';

import '../db/db_test_utils.dart';
import '../fakes/fake_reminders_platform.dart';

class _Launcher implements AppSettingsLauncher {
  int opened = 0;

  @override
  Future<bool> openAppSettings() async {
    opened++;
    return true;
  }
}

class _Paywall implements PaywallPresenter {
  int shown = 0;

  @override
  Future<void> show(PaywallRequest request) async => shown++;
}

/// The in-memory database answers on real timers, outside fake async.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
  }
}

final List<Override> _noItems = [
  actionItemsProvider(openOnly: true).overrideWith((ref) => Stream.value([])),
];

void main() {
  late VaultVoiceDatabase db;
  late FakeRemindersPlatform platform;
  late _Launcher launcher;

  setUp(() async {
    db = VaultVoiceDatabase(NativeDatabase.memory());
    platform = FakeRemindersPlatform();
    launcher = _Launcher();
    await seedRecording(db, 'r1');
    await db
        .into(db.extractions)
        .insert(
          ExtractionsCompanion.insert(
            id: 'e1',
            recordingId: 'r1',
            profileId: 'meeting',
            profileVersion: 1,
            modelId: 'llm',
            json: const {},
            valid: true,
            createdAt: t0,
          ),
        );
    await db
        .into(db.actionItems)
        .insert(
          ActionItemsCompanion.insert(
            recordingId: 'r1',
            extractionId: 'e1',
            body: 'Send the budget',
            dueIso: const Value('2026-11-03'),
          ),
        );
  });
  tearDown(() => db.close());

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    bool supported = true,
    bool enforce = false,
    _Paywall? paywall,
    List<Override> extra = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultVoiceDatabaseProvider.overrideWithValue(db),
          remindersSupportedProvider.overrideWithValue(supported),
          remindersPlatformProvider.overrideWithValue(platform),
          appSettingsLauncherProvider.overrideWithValue(launcher),
          if (enforce) ...[
            distributionModeProvider.overrideWithValue(
              DistributionMode.commercial,
            ),
            proTierEnforcedProvider.overrideWithValue(true),
          ],
          ...extra,
          if (paywall != null)
            paywallPresenterProvider.overrideWithValue(paywall),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ),
    );
    await settle(tester);
  }

  group('[TSK-02/AC3] denied or revoked permission', () {
    testWidgets('denied shows the recovery state and creates nothing', (
      tester,
    ) async {
      platform.access = ReminderAccess.denied;
      await pump(tester, const Scaffold(body: RemindersSheet()));
      expect(find.textContaining('Allow access in Settings'), findsOneWidget);
      expect(find.byKey(const ValueKey('reminders-add')), findsNothing);
      await tester.tap(find.text('Open Settings'));
      await settle(tester);
      expect(launcher.opened, 1);
      expect(platform.everCreated, isEmpty);
    });

    testWidgets('refusing the prompt ends in the recovery state', (
      tester,
    ) async {
      platform
        ..access = ReminderAccess.notDetermined
        ..promptAnswer = ReminderAccess.denied;
      await pump(tester, const Scaffold(body: RemindersSheet()));
      expect(find.textContaining('read and write your reminders'), findsOne);
      expect(platform.requestCount, 0);
      await tester.tap(find.byKey(const ValueKey('reminders-continue')));
      await settle(tester);
      expect(platform.requestCount, 1);
      expect(find.text('Open Settings'), findsOneWidget);
      expect(platform.everCreated, isEmpty);
    });

    testWidgets('access revoked while the sheet is open creates nothing', (
      tester,
    ) async {
      await pump(tester, const Scaffold(body: RemindersSheet()));
      platform.access = ReminderAccess.denied;
      await tester.tap(find.byKey(const ValueKey('reminders-add')));
      await settle(tester);
      expect(find.text('Open Settings'), findsOneWidget);
      expect(platform.everCreated, isEmpty);
    });
  });

  group('granted flow', () {
    testWidgets('select and add, then the item shows as added', (tester) async {
      await pump(tester, const Scaffold(body: RemindersSheet()));
      expect(find.text('Send the budget'), findsOneWidget);
      expect(find.textContaining('Due 2026-11-03'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reminders-add')));
      await settle(tester);
      expect(find.byKey(const ValueKey('reminders-result')), findsOneWidget);
      expect(find.text('1 added, 0 skipped, 0 failed.'), findsOneWidget);
      expect(platform.everCreated.single.title, 'Send the budget');
    });
  });

  group('[TSK-02/AC5] platform and gating', () {
    testWidgets('Android shows no Reminders action', (tester) async {
      await pump(
        tester,
        const ActionItemsScreen(),
        supported: false,
        extra: _noItems,
      );
      expect(
        find.byKey(const ValueKey('action-items-reminders')),
        findsNothing,
      );
    });

    testWidgets('iOS and macOS show the action', (tester) async {
      await pump(tester, const ActionItemsScreen(), extra: _noItems);
      expect(
        find.byKey(const ValueKey('action-items-reminders')),
        findsOneWidget,
      );
    });

    testWidgets('open when the Pro tier is not enforced', (tester) async {
      late WidgetRef ref;
      await pump(
        tester,
        Consumer(
          builder: (context, r, _) {
            ref = r;
            return const SizedBox();
          },
        ),
      );
      expect(
        await ensureFeature(
          ref,
          Feature.remindersExport,
          from: PaywallEntryPoint.reminders,
        ),
        isTrue,
      );
    });

    testWidgets('gated when the Pro tier is enforced on Free', (tester) async {
      late WidgetRef ref;
      final paywall = _Paywall();
      await pump(
        tester,
        Consumer(
          builder: (context, r, _) {
            ref = r;
            return const SizedBox();
          },
        ),
        enforce: true,
        paywall: paywall,
      );
      expect(
        await ensureFeature(
          ref,
          Feature.remindersExport,
          from: PaywallEntryPoint.reminders,
        ),
        isFalse,
      );
      expect(paywall.shown, 1);
    });
  });
}
