import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/app.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/flavor.dart';
import 'package:vaultvoice/core/flavor_provider.dart';
import 'package:vaultvoice/core/routing/app_router.dart';
import 'package:vaultvoice/features/onboarding/domain/onboarding_keys.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_providers.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

import '../fakes/fake_settings_store.dart';
import '../helpers/store_demo_data.dart';

Future<ProviderContainer> _pump(WidgetTester t, String location) async {
  t.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final container = ProviderContainer(
    overrides: [
      flavorProvider.overrideWithValue(Flavor.prod),
      settingsStoreProvider.overrideWithValue(
        FakeSettingsStore({OnboardingKeys.completed: true}),
      ),
      storagePathsProvider.overrideWith(
        (ref) => Completer<StoragePaths>().future,
      ),
      processingViewsProvider.overrideWith((ref) async => const []),
      ...storeDemoOverrides(),
    ],
  );
  addTearDown(container.dispose);
  container.read(appRouterProvider).go(location);
  await t.pumpWidget(
    UncontrolledProviderScope(container: container, child: const App()),
  );
  await t.pumpAndSettle();
  return container;
}

void main() {
  testWidgets(
    '[REL-05/AC1] store screenshots seed synthetic demo data and no people photos',
    (t) async {
      final c = await _pump(t, '/library');
      expect(find.text(kStoreDemoTitle), findsOneWidget);
      expect(find.text('Priya'), findsNothing);
      expect(find.text('Sam'), findsNothing);
      expect(
        find.byWidgetPredicate((w) => w is Image && w.image is NetworkImage),
        findsNothing,
      );

      c.read(appRouterProvider).go('/library/recordings/store-demo/text');
      await t.pumpAndSettle();
      expect(find.textContaining(kStoreDemoSpeakerA), findsWidgets);
      expect(find.textContaining(kStoreDemoSpeakerB), findsWidgets);
      expect(find.textContaining('Priya'), findsNothing);
    },
  );
}
