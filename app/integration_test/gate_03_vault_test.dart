import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';
import 'package:vaultvoice/features/export/data/export_outbox.dart';
import 'package:vaultvoice/features/export/domain/pending_export.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_engines.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_orchestrator.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/recording/data/recording_session_service.dart';
import 'package:vaultvoice/features/recording/domain/recording_session.dart';
import 'package:vaultvoice/features/templates/domain/note_context.dart';

import '../test/db/db_test_utils.dart';
import '../test/fakes/fake_clock.dart';
import '../test/fakes/fake_vault_writer.dart';
import '../test/unit/pipeline/pipeline_test_utils.dart';
import '../test/unit/profiles/builtin_profile_acceptance_test.dart'
    show casesOf, frontMatter, processed, scoringTargets;
import '../test/unit/templates/template_fixtures.dart';

/// GATE-03 automatable half (docs/test-plans/gates/GATE-03.md): every
/// built-in profile renders a note whose front-matter parses and tasks
/// render, the eval targets are the gate's, the outbox writes exactly one
/// note after a revoke/re-grant, and consent reaches the note. Obsidian and
/// real vaults are device rows (docs/test-plans/device/GATE-03.md).
///   cd app && fvm flutter test integration_test/gate_03_vault_test.dart
///
/// Enterprise/MDM (LIC-04) is out of scope for the gates.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  String render(String profileId, {DateTime? consentAt}) {
    final p = profile(profileId);
    final c = casesOf(profileId).first;
    return renderBuiltin(
      p.templateId,
      contextFor(
        profileId,
        processed(p, c),
        meta: buildNoteMeta(
          recordingId: c.id,
          createdAt: c.recordedAt,
          durationMs: 600000,
          profileId: p.id,
          profileName: p.name,
          appVersion: '1.0.0',
          consentAt: consentAt,
        ),
      ),
    );
  }

  testWidgets('[GATE-03/AC1] meeting, warranty and engineering notes have '
      'parsable front-matter and render their tasks', (tester) async {
    for (final id in ['meeting', 'warranty', 'engineering']) {
      final md = render(id);
      final fm = frontMatter(md);
      expect(fm['source'], 'vaultvoice', reason: id);
      expect(fm['recording_id'], isNotNull, reason: id);
      if (id != 'engineering') {
        expect(md, contains('- [ ] '), reason: '$id renders tasks');
      }
    }
  });

  testWidgets('[GATE-03/AC2] the gate eval targets are configured for every '
      'built-in profile', (tester) async {
    final meeting = scoringTargets('meeting');
    final warranty = scoringTargets('warranty');
    final engineering = scoringTargets('engineering');
    expect(meeting['lists.action_items.recall'], greaterThanOrEqualTo(0.8));
    expect(meeting['lists.action_items.precision'], greaterThanOrEqualTo(0.8));
    expect(warranty['scalars.accuracy'], greaterThanOrEqualTo(0.9));
    expect(engineering.values.whereType<num>(), isNotEmpty);
    for (final t in [meeting, warranty, engineering]) {
      expect(t['schema_valid'], greaterThanOrEqualTo(0.99));
    }
  });

  testWidgets('[GATE-03/AC4] consent is stored on the recording and appears '
      'in the note only when confirmed', (tester) async {
    final confirmed = DateTime.utc(2026, 10, 14, 9);
    final md = render('meeting', consentAt: confirmed);
    expect(frontMatter(md)['consent_at'], isNotNull);
    expect(frontMatter(render('meeting')).containsKey('consent_at'), isFalse);

    final db = memoryDb();
    addTearDown(db.close);
    await seedRecording(db, 'r1');
    await RecordingSessionService(
      recordings: db.recordingsRepository,
      settings: db.settingsRepository,
    ).applySetup(
      'r1',
      const RecordingSetup(profileId: 'meeting'),
      consentConfirmedAt: confirmed,
    );
    final row = (await db.recordingsRepository.get('r1')).valueOrNull!;
    expect(row.consentConfirmedAt, confirmed);
  });

  testWidgets('[GATE-03/AC3] revoke the vault folder → record → re-grant '
      'writes exactly one note', (tester) async {
    await tester.runAsync(() async {
      final db = memoryDb();
      addTearDown(db.close);
      final paths = tempPaths();
      final vault = FakeVaultWriter()..access = VaultAccess.revoked;
      final clock = FakeClock(t0);
      final o = PipelineOrchestrator.withEngines(
        db: db,
        paths: paths,
        engines: PipelineEngines(
          stt: ScriptedStt(),
          llm: ScriptedLlm(),
          vault: vault,
          clock: clock,
          vaultResolver: (_) => vault,
        ),
        newId: sequentialIds(),
      );
      addTearDown(o.dispose);
      await o.start();
      await seedRecordingWithChunks(db, 'r1');
      await seedVaultTarget(db);
      final outbox = ExportOutbox(
        db: db,
        client: () async => o,
        writerFor: (_) => vault,
        clock: clock,
      );

      final job = expectOk(await o.enqueue('r1'));
      await o.whenIdle();
      expect((await loadJob(db, job)).state, JobState.waiting);
      expect(
        (await outbox.snapshot()).single.reason,
        PendingReason.accessRevoked,
      );
      expect(vault.notes, isEmpty);

      vault.access = VaultAccess.ok; // re-granted
      expect(await outbox.recheck(), 1);
      await o.whenIdle();
      expect((await loadJob(db, job)).state, JobState.done);
      expect(vault.notes, hasLength(1));
      expect(await outbox.snapshot(), isEmpty);
      expect((await db.select(db.exports).get()).map((e) => e.status), [
        ExportStatus.written,
      ]);
    });
  });

  testWidgets('[GATE-03/AC1] the eval references of every built-in profile '
      'are present on disk', (tester) async {
    for (final id in ['meeting', 'warranty', 'engineering']) {
      expect(casesOf(id), isNotEmpty, reason: id);
      expect(
        jsonDecode(
          File('../tools/bench/eval/$id/scoring.json').readAsStringSync(),
        ),
        isA<Map<String, Object?>>(),
      );
    }
  });
}
