import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/app.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/flavor.dart';
import 'package:vaultvoice/core/flavor_provider.dart';
import 'package:vaultvoice/core/routing/app_router.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_providers.dart';
import 'package:vaultvoice/features/profiles/data/custom_profile_providers.dart';
import 'package:vaultvoice/features/profiles/data/profile_providers.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/presentation/profile_editor_screen.dart';
import 'package:vaultvoice/features/profiles/presentation/profiles_screen.dart';
import 'package:vaultvoice/features/settings/domain/settings_ports.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

import '../db/db_test_utils.dart';
import '../fakes/fake_schema_grammar_converter.dart';
import '../fakes/fake_settings_store.dart';
import '../helpers/processing_fixtures.dart';

class _NoManaged implements ManagedSettingsSource {
  const _NoManaged();

  @override
  Stream<ManagedSettings> watch() =>
      Stream.value(const ManagedSettings(values: {}));
}

List<Override> _overrides(VaultVoiceDatabase db, {required bool pro}) => [
  flavorProvider.overrideWithValue(Flavor.prod),
  processingViewsProvider.overrideWith((ref) async => sampleQueue()),
  storagePathsProvider.overrideWith((ref) => Completer<StoragePaths>().future),
  settingsStoreProvider.overrideWithValue(FakeSettingsStore()),
  managedSettingsSourceProvider.overrideWithValue(const _NoManaged()),
  vaultTargetsProvider.overrideWith((ref) => Stream.value(const [])),
  vaultVoiceDatabaseProvider.overrideWithValue(db),
  profileAssetLoaderProvider.overrideWithValue(
    (key) async => File(key).readAsStringSync(),
  ),
  schemaGrammarConverterProvider.overrideWithValue(
    FakeSchemaGrammarConverter(),
  ),
  canEditProfilesProvider.overrideWithValue(pro),
];

Future<ProviderContainer> _pump(
  WidgetTester t,
  VaultVoiceDatabase db,
  String location, {
  bool pro = true,
}) async {
  final container = ProviderContainer(overrides: _overrides(db, pro: pro));
  addTearDown(container.dispose);
  container.read(appRouterProvider).go(location);
  t.view
    ..physicalSize = const Size(600, 2400)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.runAsync(
    () => t.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    ),
  );
  await _settle(t);
  return container;
}

/// Drift streams complete on real async; let them run, then settle frames.
Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 5; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await t.pump();
  }
  await t.pumpAndSettle();
}

Finder _fieldLabelled(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byType(TextField),
);

Future<void> _pickKind(WidgetTester t, int fieldIndex, String kind) async {
  final dropdown = find.byType(DropdownButtonFormField<FieldKindProxy>);
  expect(dropdown, findsNothing); // sanity: proxy type unused
  final types = find.text('Text');
  await t.ensureVisible(types.at(fieldIndex));
  await t.tap(types.at(fieldIndex));
  await t.pumpAndSettle();
  await t.tap(find.text(kind).last);
  await t.pumpAndSettle();
}

/// Marker type used only by the sanity check above.
class FieldKindProxy {}

void main() {
  testWidgets('[PRF-07/AC1] a user builds a 5-field profile in the editor '
      'and saves it without touching JSON', (t) async {
    final db = memoryDb();
    await _pump(t, db, '/profiles/new');
    expect(find.byType(ProfileEditorScreen), findsOneWidget);
    expect(find.textContaining('{'), findsNothing, reason: 'no raw JSON');

    await t.enterText(_fieldLabelled('Name'), 'Sprint Planning');
    for (var i = 0; i < 5; i++) {
      await t.ensureVisible(find.text('Add field'));
      await t.tap(find.text('Add field'));
      await t.pumpAndSettle();
    }
    final names = ['Sprint goal', 'Risks', 'Start date', 'Tasks', 'Points'];
    for (final (i, n) in names.indexed) {
      final f = _fieldLabelled('Field name').at(i);
      await t.ensureVisible(f);
      await t.enterText(f, n);
      await t.pump();
    }
    // Types: fields 1..4 (field 0 stays "Text"). Each pick removes one
    // "Text" label, so the next default field is always at index 1.
    await _pickKind(t, 1, 'List of text');
    await _pickKind(t, 1, 'Date');
    await _pickKind(t, 1, 'Checkbox list');
    await _pickKind(t, 1, 'Number');

    await t.tap(find.byTooltip('Save profile'));
    await _settle(t);

    final row = expectOk(
      await t.runAsync(
        () => db.profilesRepository.getProfile('sprint-planning'),
      ),
    );
    final profile = Profile.fromJson(row.definition);
    expect(profile.schema.properties.keys, [
      'sprint_goal',
      'risks',
      'start_date',
      'tasks',
      'points',
    ]);
    expect(
      profile.schema.toJson()['properties'],
      containsPair('points', {
        'type': ['number', 'null'],
      }),
    );
    final tpl = expectOk(
      await t.runAsync(
        () => db.profilesRepository.getTemplate('sprint-planning-default'),
      ),
    );
    expect(tpl.body, contains('{{#checkbox}}'));
    // Navigated to the saved profile.
    expect(find.text('Edit profile'), findsOneWidget);
  });

  testWidgets('field name problems are shown inline and block saving', (
    t,
  ) async {
    final db = memoryDb();
    await _pump(t, db, '/profiles/new');
    await t.tap(find.byTooltip('Save profile'));
    await t.pumpAndSettle();
    expect(find.text('Give the profile a name.'), findsOneWidget);
    expect(find.text('Add at least one field.'), findsOneWidget);
    expect(
      await t.runAsync(() => db.profilesRepository.watchProfiles().first),
      isEmpty,
    );
  });

  testWidgets('Free tier: built-ins listed, editing a built-in is read-only, '
      'the Pro hint is shown', (t) async {
    final db = memoryDb();
    await _pump(t, db, '/profiles', pro: false);
    expect(find.byType(ProfilesScreen), findsOneWidget);
    expect(find.text('Meeting Action Items'), findsOneWidget);
    expect(find.text('Custom profiles are a Pro feature.'), findsOneWidget);
    await t.tap(find.text('Meeting Action Items'));
    await _settle(t);
    expect(
      find.text('This profile is read-only. Duplicate it to make changes.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Save profile'), findsNothing);
  });
}
