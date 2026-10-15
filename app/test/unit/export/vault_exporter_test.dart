import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';
import 'package:vaultvoice/features/export/data/app_local_vault_writer.dart';
import 'package:vaultvoice/features/export/data/export_request_builder.dart';
import 'package:vaultvoice/features/export/data/vault_exporter.dart';
import 'package:vaultvoice/features/export/domain/export_collision.dart';
import 'package:vaultvoice/features/export/domain/filename_pattern.dart';
import 'package:vaultvoice/features/export/domain/routing_engine.dart';
import 'package:vaultvoice/features/export/domain/routing_rule.dart';
import 'package:vaultvoice/features/export/domain/vault_target_options.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_engines.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_orchestrator.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';

import '../../db/db_test_utils.dart';
import '../../fakes/fake_clock.dart';
import '../../fakes/fake_vault_writer.dart';
import '../pipeline/pipeline_test_utils.dart';

/// Exporter over an in-memory DB with one [FakeVaultWriter] per target.
class _Fixture {
  _Fixture(this.db);

  final VaultVoiceDatabase db;
  final writers = <String, FakeVaultWriter>{};
  AudioAttachment? audioFile;

  late final exporter = VaultExporter(
    db: db,
    writerFor: (t) => writers.putIfAbsent(t.id, FakeVaultWriter.new),
    audio: (_) async => audioFile,
    clock: FakeClock(t0),
  );

  Future<void> target(String id, {int order = 0}) async {
    expectOk(
      await db.vaultRepository.upsertTarget(
        VaultTargetsCompanion.insert(
          id: id,
          platform: VaultPlatform.androidSaf,
          displayName: id,
          handle: 'content://tree/$id',
          createdAt: t0.add(Duration(minutes: order)),
        ),
      ),
    );
    writers[id] = FakeVaultWriter();
  }

  Future<void> rule(RoutingRule r) async {
    expectOk(
      await db.vaultRepository.upsertRule(
        RoutingRulesCompanion.insert(
          id: r.id,
          priority: r.priority,
          match: r.matchJson(),
          targetId: r.targetId,
          subPath: Value(r.subPath),
          filenamePattern: Value(r.filenamePattern),
        ),
      ),
    );
  }

  Future<void> policy(RoutingPolicy p) async {
    expectOk(
      await db.settingsRepository.set(
        SettingKeys.exportRoutingPolicy,
        p.toJson(),
      ),
    );
  }

  Future<void> options(Map<String, VaultTargetOptions> o) async {
    expectOk(
      await db.settingsRepository.set(
        SettingKeys.exportTargetOptions,
        encodeTargetOptions(o),
      ),
    );
  }

  Future<List<ExportRow>> rows() => db.select(db.exports).get();
}

ExportRequest request({
  String recordingId = 'r1',
  String markdown = '# Note v1\n',
  String profileId = 'meeting',
  String? title = 'Planning',
  List<String> tags = const [],
  String? transcript,
}) => ExportRequest(
  recordingId: recordingId,
  markdown: markdown,
  routing: RoutingInput(profileId: profileId, title: title, tags: tags),
  filename: FilenameValues(
    recordingId: recordingId,
    createdAt: DateTime(2026, 10, 14, 9, 30),
    profileId: profileId,
    title: title,
  ),
  transcriptMarkdown: transcript,
);

const _notePath = '2026-10-14-meeting-planning.md';

void main() {
  late VaultVoiceDatabase db;
  late _Fixture f;

  setUp(() async {
    db = memoryDb();
    f = _Fixture(db);
    await seedRecording(db, 'r1');
    await seedRecording(db, 'r2');
  });

  test('no target configured → needs a destination', () async {
    expect(await f.exporter.export(request()), isA<ExportNeedsDestination>());
    expect(await f.rows(), isEmpty);
  });

  test('[EXP-05/AC2] the note lands in the rule-selected target and '
      'sub-folder (multi-target with Pro policy)', () async {
    await f.target('personal');
    await f.target('work', order: 1);
    await f.target('archive', order: 2);
    await f.policy(RoutingPolicy.unlimited);
    await f.rule(
      const RoutingRule(
        id: 'work',
        priority: 1,
        targetId: 'work',
        match: RuleMatch(tagsAny: ['work']),
        subPath: 'Meetings/../Q4',
        mode: RuleMode.continueMatching,
      ),
    );
    await f.rule(
      const RoutingRule(
        id: 'all',
        priority: 2,
        targetId: 'archive',
        filenamePattern: '{{id}}.md',
      ),
    );

    final out = await f.exporter.export(request(tags: ['#Work']));
    expect(out, isA<ExportDone>());
    expect(f.writers['work']!.notes.keys, ['Meetings/Q4/$_notePath']);
    expect(f.writers['archive']!.notes.keys, ['r1.md']);
    expect(f.writers['personal']!.notes, isEmpty);
    final rows = await f.rows();
    expect(
      {for (final r in rows) r.targetId: r.status},
      {'work': ExportStatus.written, 'archive': ExportStatus.written},
    );
    expect(rows.first.contentHash, isNotEmpty);
  });

  test(
    'Free policy (no mirror yet): rules ignored, first target only',
    () async {
      await f.target('personal');
      await f.target('work', order: 1);
      await f.rule(const RoutingRule(id: 'w', priority: 1, targetId: 'work'));
      expect(await f.exporter.export(request()), isA<ExportDone>());
      expect(f.writers['personal']!.notes.keys, [_notePath]);
      expect(f.writers['work']!.notes, isEmpty);
    },
  );

  test('re-export is idempotent: same path, unchanged content not '
      'rewritten, new content updated in place', () async {
    await f.target('v');
    await f.exporter.export(request());
    final w = f.writers['v']!;
    expect(w.writes, 1);
    await f.exporter.export(request());
    expect(w.writes, 1, reason: 'unchanged → no write');
    // Title changed: the stable identity keeps the original path.
    await f.exporter.export(request(markdown: '# v2\n', title: 'Renamed'));
    expect(w.notes, {_notePath: '# v2\n'});
    expect((await f.rows()).single.attempts, 2);
  });

  test('a crash between vault write and commit does not duplicate', () async {
    await f.target('v');
    final w = f.writers['v']!;
    // Simulate: row persisted as `writing` (no hash), file written, then the
    // process died before the row was confirmed.
    expectOk(
      await db.vaultRepository.upsertExport(
        ExportsCompanion.insert(
          id: exportId('r1', 'v'),
          recordingId: 'r1',
          targetId: 'v',
          relPath: _notePath,
          contentHash: '',
          status: ExportStatus.writing,
          updatedAt: t0,
        ),
      ),
    );
    w.notes[_notePath] = '# Note v1\n';
    expect(await f.exporter.export(request()), isA<ExportDone>());
    expect(w.notes.keys, [_notePath]);
    expect((await f.rows()).single.status, ExportStatus.written);
  });

  test('a stale pending row never claims a foreign file', () async {
    await f.target('v');
    final w = f.writers['v']!;
    expectOk(
      await db.vaultRepository.upsertExport(
        ExportsCompanion.insert(
          id: exportId('r1', 'v'),
          recordingId: 'r1',
          targetId: 'v',
          relPath: _notePath,
          contentHash: '',
          status: ExportStatus.failed,
          updatedAt: t0,
        ),
      ),
    );
    w.notes[_notePath] = 'the user wrote this';
    await f.options({
      'v': const VaultTargetOptions(collision: CollisionMode.overwrite),
    });
    await f.exporter.export(request());
    expect(w.notes[_notePath], 'the user wrote this');
    expect(w.notes['2026-10-14-meeting-planning-2.md'], '# Note v1\n');
  });

  test('per-target collision mode applies to a user-edited note', () async {
    await f.target('a');
    await f.target('b', order: 1);
    await f.policy(RoutingPolicy.unlimited);
    for (final (id, t, prio) in [('ra', 'a', 1), ('rb', 'b', 2)]) {
      await f.rule(
        RoutingRule(
          id: id,
          priority: prio,
          targetId: t,
          mode: RuleMode.continueMatching,
        ),
      );
    }
    await f.options({
      'a': const VaultTargetOptions(collision: CollisionMode.overwrite),
      'b': const VaultTargetOptions(collision: CollisionMode.skip),
    });
    await f.exporter.export(request());
    f.writers['a']!.notes[_notePath] = 'edited';
    f.writers['b']!.notes[_notePath] = 'edited';
    await f.exporter.export(request(markdown: '# v2\n'));
    expect(f.writers['a']!.notes, {_notePath: '# v2\n'});
    expect(f.writers['b']!.notes, {_notePath: 'edited'});
  });

  test("global collision setting is the default; another recording's "
      'path is never reused', () async {
    await f.target('v');
    await f.exporter.export(request());
    await f.exporter.export(request(recordingId: 'r2', markdown: 'other'));
    expect(f.writers['v']!.notes.keys, [
      _notePath,
      '2026-10-14-meeting-planning-2.md',
    ]);
  });

  test(
    'sidecars: transcript note + audio attachment, off by default',
    () async {
      await f.target('v');
      f.audioFile = (bytes: Uint8List.fromList([1, 2, 3]), extension: 'm4a');
      await f.exporter.export(request(transcript: '# T\n'));
      expect(f.writers['v']!.notes.keys, [_notePath]);
      expect(f.writers['v']!.binaries, isEmpty);

      await f.options({
        'v': const VaultTargetOptions(
          transcriptSidecar: true,
          audioSidecar: true,
        ),
      });
      await f.exporter.export(request(transcript: '# T\n'));
      final w = f.writers['v']!;
      expect(w.notes['2026-10-14-meeting-planning.transcript.md'], '# T\n');
      expect(w.binaries['attachments/2026-10-14-meeting-planning.m4a'], [
        1,
        2,
        3,
      ]);
      final writes = w.writes;
      await f.exporter.export(request(transcript: '# T\n'));
      // The audio copy is never rewritten; the transcript is refreshed.
      expect(w.writes, writes + 1);
    },
  );

  test('revoked access → needs destination; re-grant writes exactly one '
      'note and keeps the done target untouched', () async {
    await f.target('a');
    await f.target('b', order: 1);
    await f.policy(RoutingPolicy.unlimited);
    await f.rule(
      const RoutingRule(
        id: '1',
        priority: 1,
        targetId: 'a',
        mode: RuleMode.continueMatching,
      ),
    );
    await f.rule(const RoutingRule(id: '2', priority: 2, targetId: 'b'));
    f.writers['b']!.access = VaultAccess.revoked;

    final out = await f.exporter.export(request());
    expect(out, isA<ExportNeedsDestination>());
    expect(
      {for (final t in out.targets) t.targetId: t.ok},
      {'a': true, 'b': false},
    );
    expect(
      {for (final r in await f.rows()) r.targetId: r.status},
      {'a': ExportStatus.written, 'b': ExportStatus.failed},
    );

    f.writers['b']!.access = VaultAccess.ok;
    final writesA = f.writers['a']!.writes;
    expect(await f.exporter.export(request()), isA<ExportDone>());
    expect(f.writers['a']!.writes, writesA);
    expect(f.writers['b']!.notes.keys, [_notePath]);
  });

  test('unavailable storage / write errors → retryable failure', () async {
    await f.target('v');
    f.writers['v']!.access = VaultAccess.unavailable;
    final out = await f.exporter.export(request());
    expect(out, isA<ExportFailed>());
    expect((out as ExportFailed).failure, isA<VaultAccessFailure>());

    f.writers['v']!
      ..access = VaultAccess.ok
      ..failWith(const StorageFailure('disk full'));
    final full = await f.exporter.export(request());
    expect((full as ExportFailed).failure, isA<StorageFailure>());
    final row = (await f.rows()).single;
    expect(row.status, ExportStatus.failed);
    expect(row.attempts, 2);
    expect(row.contentHash, isEmpty);
  });

  test('subPath sanitizing', () {
    expect(sanitizeSubPath(' Work / ../Q4:Plans//./x '), 'Work/Q4Plans/x');
    expect(sanitizeSubPath(''), '');
  });

  test('transcript sidecar markdown', () {
    expect(
      transcriptSidecarMarkdown(
        title: 'T\nx',
        lines: const [
          (startMs: 65000, speaker: 'Priya', text: 'Hi\nthere'),
          (startMs: 0, speaker: null, text: 'Bye'),
        ],
      ),
      '# T x\n\n[00:01:05] Priya: Hi there\n\n[00:00:00] Bye\n\n',
    );
  });

  group('end-to-end', () {
    late StoragePaths paths;
    late Directory work;
    late Directory personal;

    setUp(() {
      paths = tempPaths();
      final root = Directory.systemTemp.createTempSync('vv_vaults_');
      addTearDown(() => root.deleteSync(recursive: true));
      work = Directory(p.join(root.path, 'work'))..createSync();
      personal = Directory(p.join(root.path, 'personal'))..createSync();
    });

    test('[EXP-05/AC2] recording → note lands in the rule-selected vault '
        'folder (pipeline with real file writers)', () async {
      await seedRecordingWithChunks(db, 'r3');
      for (final (id, i) in [('personal', 0), ('work', 1)]) {
        expectOk(
          await db.vaultRepository.upsertTarget(
            VaultTargetsCompanion.insert(
              id: id,
              platform: VaultPlatform.appLocal,
              displayName: id,
              handle: id,
              createdAt: t0.add(Duration(minutes: i)),
            ),
          ),
        );
      }
      await f.policy(RoutingPolicy.unlimited);
      await f.rule(
        const RoutingRule(
          id: 'meetings-to-work',
          priority: 1,
          targetId: 'work',
          match: RuleMatch(profileIds: ['meeting'], keywordsAny: ['ok']),
          subPath: 'Meetings',
        ),
      );
      final writers = {
        'work': AppLocalVaultWriter.at(work),
        'personal': AppLocalVaultWriter.at(personal),
      };
      final o = PipelineOrchestrator.withEngines(
        db: db,
        paths: paths,
        engines: PipelineEngines(
          stt: ScriptedStt(),
          llm: ScriptedLlm(),
          vault: FakeVaultWriter(),
          clock: FakeClock(t0),
          vaultResolver: (t) => writers[t.id]!,
        ),
        newId: sequentialIds(),
      );
      addTearDown(o.dispose);
      await o.start();
      final id = expectOk(await o.enqueue('r3'));
      await o.whenIdle();

      expect((await loadJob(db, id)).state, JobState.done);
      final files = [
        for (final e in work.listSync(recursive: true))
          if (e is File) p.relative(e.path, from: work.path),
      ];
      expect(files, hasLength(1));
      expect(files.single, startsWith('Meetings${p.separator}2026-10-12-'));
      expect(files.single, endsWith('.md'));
      expect(
        File(p.join(work.path, files.single)).readAsStringSync(),
        File(paths.renderedFile('r3')).readAsStringSync(),
      );
      expect(personal.listSync(), isEmpty);
      expect(
        utf8.decode(
          (await writers['work']!.read(files.single.replaceAll(r'\', '/')))
              .valueOrNull!,
        ),
        contains('chunk_1'),
      );
    });

    test('no target → the job waits for a destination', () async {
      await seedRecordingWithChunks(db, 'r4');
      final o = PipelineOrchestrator.withEngines(
        db: db,
        paths: paths,
        engines: PipelineEngines(
          stt: ScriptedStt(),
          llm: ScriptedLlm(),
          vault: FakeVaultWriter(),
          clock: FakeClock(t0),
          vaultResolver: (_) => FakeVaultWriter(),
        ),
        newId: sequentialIds(),
      );
      addTearDown(o.dispose);
      await o.start();
      final id = expectOk(await o.enqueue('r4'));
      await o.whenIdle();
      final job = await loadJob(db, id);
      expect(job.state, JobState.waiting);
      expect(job.waitingReason, WaitingReason.destination);
    });
  });
}
