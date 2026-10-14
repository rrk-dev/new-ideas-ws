import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/migrations.dart';

import '../db_test_utils.dart';
import '../fixtures/v2_fixture_database.dart';
import 'vaultvoice/generated/schema.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;
  late Directory tmp;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));
  setUp(() => tmp = Directory.systemTemp.createTempSync('vv_mig_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('[FND-04/AC1] current schema equals the frozen latest snapshot '
      '(drift_schemas/vaultvoice/drift_schema_v<current>.json)', () async {
    const current = VaultVoiceDatabase.currentSchemaVersion;
    final schema = await verifier.schemaAt(current);
    final db = VaultVoiceDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, current);
    await db.close();
  });

  test('[FND-04/AC1] v1 snapshot migrates to the v2 fixture: schema valid, '
      'data preserved, backfill applied, foreign keys enforced', () async {
    final schema = await verifier.schemaAt(1);
    final raw = schema.rawDatabase;
    final ms = t0.millisecondsSinceEpoch;
    raw
      ..execute(
        'INSERT INTO recordings (id, title, created_at, status, source) '
        "VALUES ('r1', 'Standup', $ms, 'recorded', 'mic'), "
        "('r2', 'Memo', $ms, 'recorded', 'imported')",
      )
      ..execute(
        'INSERT INTO transcripts (id, recording_id, model_id, language, '
        "created_at) VALUES ('t1', 'r1', 'ggml-base', 'en', $ms)",
      )
      ..execute(
        'INSERT INTO transcript_segments (transcript_id, seq, start_ms, '
        "end_ms, body) VALUES ('t1', 0, 0, 1500, 'hello')",
      )
      ..execute(
        'INSERT INTO jobs (id, recording_id, kind, step, status, '
        "created_at, updated_at) VALUES ('j1', 'r1', 'process', "
        "'extract', 'queued', $ms, $ms)",
      );

    final db = V2FixtureDatabase(schema.newConnection());
    addTearDown(db.close);
    await db.validateDatabaseSchema();

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(
      version.read<int>('user_version'),
      VaultVoiceDatabase.currentSchemaVersion + 1,
    );

    final recordings = await db.select(db.recordings).get();
    expect(
      recordings.map((r) => r.title),
      unorderedEquals(['Standup', 'Memo']),
    );
    expect(recordings.firstWhere((r) => r.id == 'r1').createdAt, t0);
    expect(
      recordings.firstWhere((r) => r.id == 'r2').source,
      RecordingSource.imported,
    );
    final segments = await db.select(db.transcriptSegments).get();
    expect(segments.single.body, 'hello');
    final jobs = await db.select(db.jobs).get();
    expect(jobs.single.step, 'extract');
    expect(jobs.single.checkpoint, isEmpty);

    final labels = await db.select(db.recordingLabels).get();
    expect(labels.single.recordingId, 'r2');
    expect(labels.single.label, 'imported');

    await expectLater(
      db
          .into(db.recordingLabels)
          .insert(
            RecordingLabelsCompanion.insert(recordingId: 'missing', label: 'x'),
          ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('[FND-04/AC1] a v1 database file written by the app upgrades to v2 '
      'on reopen', () async {
    final file = File('${tmp.path}/vaultvoice.sqlite');
    final v1 = VaultVoiceDatabase(NativeDatabase(file));
    await seedRecording(v1, 'r1', source: RecordingSource.imported);
    expectOk(await v1.settingsRepository.set('auto_process', true));
    await v1.close();

    final v2 = V2FixtureDatabase(NativeDatabase(file));
    addTearDown(v2.close);
    await v2.validateDatabaseSchema();
    expect((await v2.select(v2.recordings).get()).single.id, 'r1');
    expect(
      (await v2.select(v2.recordingLabels).get()).single.label,
      'imported',
    );
    expect((await v2.select(v2.settings).get()).single.value, 'true');
  });

  test('[FND-04/AC1] a missing upgrade step aborts opening', () async {
    final file = File('${tmp.path}/vaultvoice.sqlite');
    final v1 = VaultVoiceDatabase(NativeDatabase(file));
    await seedRecording(v1, 'r1');
    await v1.close();

    final broken = V2FixtureDatabase(NativeDatabase(file), steps: const {});
    await expectLater(
      broken.select(broken.recordings).get(),
      throwsA(
        isA<MigrationException>().having(
          (e) => e.message,
          'message',
          contains(
            'no migration step to '
            'v${VaultVoiceDatabase.currentSchemaVersion + 1}',
          ),
        ),
      ),
    );
    await broken.close();

    // The failed upgrade left the file at v1 and intact.
    final again = VaultVoiceDatabase(NativeDatabase(file));
    addTearDown(again.close);
    expect((await again.select(again.recordings).get()).single.id, 'r1');
  });

  test('[FND-04/AC1] downgrading v2 → v1 is refused', () async {
    final file = File('${tmp.path}/vaultvoice.sqlite');
    final v2 = V2FixtureDatabase(NativeDatabase(file));
    await v2.customSelect('SELECT 1').get();
    await v2.close();

    final v1 = VaultVoiceDatabase(NativeDatabase(file));
    addTearDown(v1.close);
    await expectLater(
      v1.customSelect('SELECT 1').get(),
      throwsA(isA<MigrationException>()),
    );
  });

  test('migration steps registry matches the schema version', () {
    // Every version above 1 needs exactly one registered step.
    expect(VaultVoiceDatabase.migrationSteps.keys.toSet(), {
      for (var v = 2; v <= VaultVoiceDatabase.currentSchemaVersion; v++) v,
    });
    expect(
      GeneratedHelper.versions.last,
      VaultVoiceDatabase.currentSchemaVersion,
    );
    expect(const MigrationException('x').toString(), 'MigrationException(x)');
  });
}
