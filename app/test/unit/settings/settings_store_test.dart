import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/app_info.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/licenses/bundled_licenses.dart';
import 'package:vaultvoice/features/settings/data/drift_settings_store.dart';
import 'package:vaultvoice/features/settings/domain/setting_definitions.dart';
import 'package:vaultvoice/features/settings/domain/settings_ports.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

import '../../db/db_test_utils.dart';
import '../../helpers/settings_values.dart';
import '../../helpers/test_container.dart';

class _Managed implements ManagedSettingsSource {
  _Managed(this.s);

  final ManagedSettings s;

  @override
  Stream<ManagedSettings> watch() => Stream.value(s);
}

/// Reads an auto-dispose provider's current value while subscribed.
Future<SettingState> state(ProviderContainer c, String key) {
  final sub = c.listen(settingStateProvider(key).future, (_, _) {});
  addTearDown(sub.close);
  return sub.read();
}

void main() {
  test('[APP-03/AC1] every setting round-trips through the settings table '
      'and survives a restart', () async {
    final db = memoryDb();
    final c1 = createContainer(
      overrides: [vaultVoiceDatabaseProvider.overrideWithValue(db)],
    );
    for (final def in AppSettings.all) {
      final s = await state(c1, def.key);
      expect(s.value, def.defaultValue, reason: '${def.key} default');
      expectOk(await c1.read(settingsWriterProvider).set(def, otherValue(def)));
    }
    c1.dispose();
    // "Restart": a new container on the same database.
    final c2 = createContainer(
      overrides: [vaultVoiceDatabaseProvider.overrideWithValue(db)],
    );
    for (final def in AppSettings.all) {
      final s = await state(c2, def.key);
      expect(s.value, otherValue(def), reason: def.key);
      expect(s.managed, isFalse);
      final raw = await db.settingsRepository.get(def.key);
      expect(raw.valueOrNull, otherValue(def));
    }
  });

  test('[APP-03/AC1] managed values override stored ones and are reported '
      'as managed', () async {
    final db = memoryDb();
    await DriftSettingsStore(db.settingsRepository)
        .set(AppSettings.appLock.key, false);
    final c = createContainer(
      overrides: [
        vaultVoiceDatabaseProvider.overrideWithValue(db),
        managedSettingsSourceProvider.overrideWithValue(
          _Managed(
            ManagedSettings(
              values: {AppSettings.appLock.key: true},
              locked: {AppSettings.collisionMode.key},
            ),
          ),
        ),
      ],
    );
    final lock = await state(c, AppSettings.appLock.key);
    expect(lock.value, true);
    expect(lock.managed, isTrue);
    final collision = await state(c, AppSettings.collisionMode.key);
    expect(collision.value, 'suffix');
    expect(collision.managed, isTrue);
    expect(
      (await c
              .read(settingsWriterProvider)
              .set(AppSettings.collisionMode, 'skip'))
          .isOk,
      isFalse,
    );
  });

  test('definitions decode garbage to defaults and validate patterns', () {
    for (final def in AppSettings.all) {
      expect(def.decode({'x': 1}), def.defaultValue);
      expect(def.accepts(def.defaultValue), isTrue, reason: def.key);
    }
    expect(validateFilenamePattern('{{date:YYYY-MM-DD}}/{{slug}}.md'), isNull);
    expect(validateFilenamePattern('  '), PatternError.empty);
    expect(validateFilenamePattern('/abs.md'), PatternError.unsafe);
    expect(validateFilenamePattern('a/../b.md'), PatternError.unsafe);
    expect(validateFilenamePattern(r'a\b.md'), PatternError.unsafe);
    expect(validateFilenamePattern('{{slug.md'), PatternError.unbalanced);
    expect(validateFilenamePattern('x' * 201), PatternError.tooLong);
    expect(AppSettings.byKey('nope'), isNull);
    expect(
      {for (final d in AppSettings.all) d.key}.length,
      AppSettings.all.length,
      reason: 'keys are unique',
    );
  });

  test('kAppVersion matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1);
    expect(kAppVersion, version);
  });

  test('bundled native/model licenses are registered once', () async {
    registerBundledLicenses();
    registerBundledLicenses();
    final entries = await LicenseRegistry.licenses.toList();
    for (final l in kBundledLicenses) {
      final matching = entries.where(
        (e) => e.packages.toList().join() == l.packages.join(),
      );
      expect(matching, hasLength(1), reason: l.packages.join());
    }
  });
}
