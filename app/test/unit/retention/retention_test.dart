import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/features/retention/data/recording_purger.dart';
import 'package:vaultvoice/features/retention/data/retention_providers.dart';
import 'package:vaultvoice/features/retention/data/retention_sweeper.dart';
import 'package:vaultvoice/features/retention/domain/retention_policy.dart';
import 'package:vaultvoice/features/settings/domain/setting_definitions.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';
import 'package:vaultvoice/features/settings/domain/settings_ports.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

import '../../db/db_test_utils.dart';
import '../../fakes/fake_clock.dart';
import '../../fakes/fake_settings_store.dart';
import '../../helpers/test_container.dart';
import 'retention_fixtures.dart';

class _Managed implements ManagedSettingsSource {
  _Managed(this.values);

  final Map<String, Object?> values;

  @override
  Stream<ManagedSettings> watch() =>
      Stream.value(ManagedSettings(values: values));
}

void main() {
  final created = DateTime.utc(2026, 9);

  group('RetentionPolicy', () {
    test('parses every option and fails safe on unknown ids', () {
      expect(
        RetentionPolicy.parse(RetentionOption.forever),
        isA<KeepForever>(),
      );
      expect(RetentionPolicy.parse('garbage'), isA<KeepForever>());
      expect(
        RetentionPolicy.parse(RetentionOption.afterExport),
        isA<DeleteAfterExport>(),
      );
      for (final (id, days) in [
        (RetentionOption.days7, 7),
        (RetentionOption.days30, 30),
        (RetentionOption.days90, 90),
      ]) {
        expect((RetentionPolicy.parse(id) as DeleteAfterDays).days, days);
      }
    });

    test('[SEC-04] due rules: after export / after N days / never', () {
      bool due(RetentionPolicy p, Duration age, {bool exported = false}) => p
          .isDue(createdAt: created, now: created.add(age), exported: exported);
      expect(due(const KeepForever(), const Duration(days: 9999)), isFalse);
      expect(due(const DeleteAfterExport(), Duration.zero), isFalse);
      expect(
        due(const DeleteAfterExport(), Duration.zero, exported: true),
        isTrue,
      );
      expect(due(const DeleteAfterDays(7), const Duration(days: 6)), isFalse);
      expect(due(const DeleteAfterDays(7), const Duration(days: 7)), isTrue);
    });
  });

  group('RetentionSweeper', () {
    late Directory tmp;
    late StoragePaths paths;
    late VaultVoiceDatabase db;
    late FakeClock clock;
    var policies = <String, String>{};

    setUp(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      tmp = Directory.systemTemp.createTempSync('vv_ret_');
      paths = StoragePaths(p.join(tmp.path, 'vv'));
      db = VaultVoiceDatabase(NativeDatabase.memory());
      clock = FakeClock(created.add(const Duration(days: 10)));
      policies = {};
    });
    tearDown(() async {
      await db.close();
      tmp.deleteSync(recursive: true);
    });

    Future<RetentionReport> sweep() async {
      final sweeper = RetentionSweeper(
        db: db,
        paths: paths,
        purger: RecordingPurger(db, paths),
        policyFor: (key) async =>
            RetentionPolicy.parse(policies[key] ?? RetentionOption.forever),
        clock: clock,
      );
      return expectOk<RetentionReport>(
        await sweeper.run(
          audioKey: SettingKeys.audioRetention,
          transcriptKey: SettingKeys.privacyTranscriptRetention,
        ),
      );
    }

    test('default (keep forever) deletes nothing', () async {
      await seedFullRecording(db, paths, 'r1', createdAt: created);
      final r = await sweep();
      expect(r.audioDeleted + r.transcriptsDeleted + r.recordingsDeleted, 0);
      expect((await rowsReferencing(db, 'r1'))['audio_chunks'], 2);
    });

    test(
      '[SEC-04] audio after export: only exported recordings lose audio',
      () async {
        policies[SettingKeys.audioRetention] = RetentionOption.afterExport;
        await seedFullRecording(db, paths, 'done', createdAt: created);
        await seedFullRecording(
          db,
          paths,
          'pending',
          createdAt: created,
          exported: false,
        );
        final r = await sweep();
        expect(r.audioDeleted, 1);
        expect((await rowsReferencing(db, 'done'))['audio_chunks'], 0);
        expect((await rowsReferencing(db, 'done'))['transcripts'], 1);
        expect(Directory(paths.audioDir('done')).existsSync(), isFalse);
        expect((await rowsReferencing(db, 'pending'))['audio_chunks'], 2);
        // Idempotent.
        expect((await sweep()).audioDeleted, 0);
      },
    );

    test(
      '[SEC-04] transcripts after N days; both due → whole recording',
      () async {
        policies[SettingKeys.privacyTranscriptRetention] =
            RetentionOption.days30;
        await seedFullRecording(db, paths, 'old', createdAt: created);
        await seedFullRecording(
          db,
          paths,
          'new',
          createdAt: clock.now().subtract(const Duration(days: 1)),
        );
        clock.advance(const Duration(days: 25)); // 'old' is 35 days old
        var r = await sweep();
        expect(r.transcriptsDeleted, 1);
        expect((await rowsReferencing(db, 'old'))['transcripts'], 0);
        expect((await rowsReferencing(db, 'old'))['audio_chunks'], 2);
        expect((await rowsReferencing(db, 'new'))['transcripts'], 1);

        policies[SettingKeys.audioRetention] = RetentionOption.days7;
        r = await sweep();
        // 'old': audio + transcript due → gone; 'new' (26 days): audio only.
        expect(r.recordingsDeleted, 1);
        expect(r.audioDeleted, 1);
        expect((await rowsReferencing(db, 'old'))['recordings'], 0);
        expect((await rowsReferencing(db, 'new'))['audio_chunks'], 0);
        expect((await rowsReferencing(db, 'new'))['transcripts'], 1);
        expect(filesUnder(paths.root).where((f) => f.contains('old')), isEmpty);
      },
    );

    test('skips recordings being captured or processed', () async {
      policies[SettingKeys.audioRetention] = RetentionOption.days7;
      await seedFullRecording(
        db,
        paths,
        'live',
        createdAt: created,
        status: RecordingStatus.recording,
      );
      await seedFullRecording(
        db,
        paths,
        'queued',
        createdAt: created,
        jobStatus: 'queued',
      );
      final r = await sweep();
      expect(r.audioDeleted, 0);
      expect(r.skippedBusy, 1);
      expect((await rowsReferencing(db, 'live'))['audio_chunks'], 2);
      expect((await rowsReferencing(db, 'queued'))['audio_chunks'], 2);
    });

    test('also sweeps orphaned files', () async {
      File(paths.renderedFile('ghost'))
        ..createSync(recursive: true)
        ..writeAsStringSync('x');
      expect((await sweep()).orphansRemoved, 1);
    });
  });

  group('RetentionScheduler', () {
    test(
      'runs the sweep with the effective (managed › user) settings',
      () async {
        final tmp = Directory.systemTemp.createTempSync('vv_ret_sched_');
        addTearDown(() => tmp.deleteSync(recursive: true));
        final paths = StoragePaths(p.join(tmp.path, 'vv'));
        final db = VaultVoiceDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await seedFullRecording(db, paths, 'r1', createdAt: created);
        final c = createContainer(
          overrides: [
            storagePathsProvider.overrideWith((ref) async => paths),
            vaultVoiceDatabaseProvider.overrideWithValue(db),
            clockProvider.overrideWithValue(
              FakeClock(created.add(const Duration(days: 40))),
            ),
            settingsStoreProvider.overrideWithValue(
              FakeSettingsStore({
                SettingKeys.privacyTranscriptRetention: RetentionOption.days30,
              }),
            ),
            // The organisation forces audio deletion after 7 days.
            managedSettingsSourceProvider.overrideWithValue(
              _Managed({SettingKeys.audioRetention: RetentionOption.days7}),
            ),
          ],
        );
        await c.read(retentionSchedulerProvider).runOnce();
        expect((await rowsReferencing(db, 'r1'))['recordings'], 0);
        expect(filesUnder(paths.root), isEmpty);
      },
    );
  });
}
