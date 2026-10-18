import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/logging/logger.dart';
import 'package:vaultvoice/features/reminders/data/reminders_exporter.dart';
import 'package:vaultvoice/features/reminders/domain/reminders_platform.dart';

import '../../db/db_test_utils.dart';
import '../../fakes/fake_clock.dart';
import '../../fakes/fake_reminders_platform.dart';

class _MemorySink implements LogSink {
  final lines = <String>[];

  @override
  void write(LogRecord record) =>
      lines.add('${record.tag} ${record.message} ${record.fields}');

  @override
  Future<void> close() async {}
}

Future<void> _seed(
  VaultVoiceDatabase db,
  String recordingId,
  String extractionId,
  List<({String body, bool done, String? due, String? owner})> items, {
  DateTime? at,
}) async {
  await db
      .into(db.extractions)
      .insert(
        ExtractionsCompanion.insert(
          id: extractionId,
          recordingId: recordingId,
          profileId: 'meeting',
          profileVersion: 1,
          modelId: 'llm',
          json: const {},
          valid: true,
          createdAt: at ?? t0,
        ),
      );
  for (final i in items) {
    await db
        .into(db.actionItems)
        .insert(
          ActionItemsCompanion.insert(
            recordingId: recordingId,
            extractionId: extractionId,
            body: i.body,
            done: Value(i.done),
            dueIso: Value(i.due),
            owner: Value(i.owner),
          ),
        );
  }
}

({String body, bool done, String? due, String? owner}) _item(
  String body, {
  bool done = false,
  String? due,
  String? owner,
}) => (body: body, done: done, due: due, owner: owner);

void main() {
  late VaultVoiceDatabase db;
  late FakeRemindersPlatform platform;
  late RemindersExporter exporter;
  late _MemorySink sink;

  setUp(() async {
    db = VaultVoiceDatabase(NativeDatabase.memory());
    await db.customStatement('PRAGMA foreign_keys = ON');
    platform = FakeRemindersPlatform();
    sink = _MemorySink();
    exporter = RemindersExporter(
      platform: platform,
      db: db,
      clock: FakeClock(t0),
      logger: Logger(sinks: [sink], clock: FakeClock(t0)),
    );
    await seedRecording(db, 'r1');
  });
  tearDown(() => db.close());

  Future<List<ReminderCandidate>> candidates() async =>
      (await exporter.candidates()).valueOrNull!;

  group('[TSK-02/AC1] create once, skip ineligible, no duplicates', () {
    test('eligible items are created, done and empty are skipped', () async {
      await _seed(db, 'r1', 'e1', [
        _item('Send the budget'),
        _item('Book the room'),
        _item('Already finished', done: true),
        _item('   '),
      ]);
      final list = await candidates();
      expect(list.map((c) => c.keyed.item.body), [
        'Send the budget',
        'Book the room',
      ]);
      final r = (await exporter.export(list)).valueOrNull!;
      expect(r.created, 2);
      expect(platform.store, hasLength(2));
    });

    test('ineligible items passed in are skipped, not created', () async {
      await _seed(db, 'r1', 'e1', [
        _item('Send the budget'),
        _item('Already finished', done: true),
      ]);
      final all = await db.select(db.actionItems).get();
      expect(all, hasLength(2));
      // Mark the open one done after listing: export re-checks.
      final list = await candidates();
      await (db.update(db.actionItems)
            ..where((a) => a.body.equals('Send the budget')))
          .write(const ActionItemsCompanion(done: Value(true)));
      final r = (await exporter.export(list)).valueOrNull!;
      expect(r.created, 1);
      expect(platform.store, hasLength(1));
    });

    test('a second push does not duplicate', () async {
      await _seed(db, 'r1', 'e1', [_item('Send the budget')]);
      await exporter.export(await candidates());
      final second = await candidates();
      expect(second.single.state, ReminderItemState.added);
      expect(second.single.selectable, isFalse);
      final r = (await exporter.export(second)).valueOrNull!;
      expect((r.created, r.skipped), (0, 1));
      expect(platform.everCreated, hasLength(1));
    });

    test('a double tap on a stale selection never duplicates', () async {
      await _seed(db, 'r1', 'e1', [_item('Send the budget')]);
      final stale = await candidates();
      await exporter.export(stale);
      await exporter.export(stale);
      expect(platform.everCreated, hasLength(1));
    });

    test(
      'a reminder deleted externally is handled and can be re-added',
      () async {
        await _seed(db, 'r1', 'e1', [_item('Send the budget')]);
        await exporter.export(await candidates());
        platform.deleteExternally(platform.store.keys.single);

        final list = await candidates();
        expect(list.single.state, ReminderItemState.addedMissing);
        expect(list.single.selectable, isTrue);
        final r = await exporter.export(list);
        expect(r, isA<Ok<ReminderExportSummary>>());
        expect(platform.store, hasLength(1));
        expect((await candidates()).single.state, ReminderItemState.added);
      },
    );

    test('a host failure for one item is counted, others still land', () async {
      await _seed(db, 'r1', 'e1', [_item('One'), _item('Two')]);
      final list = await candidates();
      platform.failKeys.add(list.first.keyed.key);
      final r = (await exporter.export(list)).valueOrNull!;
      expect((r.created, r.failed), (1, 1));
      expect((await candidates()).first.state, ReminderItemState.available);
    });

    test('only the newest extraction of a recording is offered', () async {
      await _seed(db, 'r1', 'old', [_item('Old wording')], at: t0);
      await _seed(db, 'r1', 'new', [
        _item('New wording'),
      ], at: t0.add(const Duration(hours: 1)));
      expect((await candidates()).map((c) => c.keyed.item.body), [
        'New wording',
      ]);
    });
  });

  group('[TSK-02/AC2] due date only from due_iso', () {
    test('due_iso sets a due date, a spoken phrase does not', () async {
      await _seed(db, 'r1', 'e1', [
        _item('With date', due: '2026-11-03'),
        _item('With time', due: '2026-11-03T09:30:00'),
        _item('Spoken only', due: 'next Friday'),
        _item('None'),
      ]);
      await exporter.export(await candidates());
      final byTitle = {for (final d in platform.everCreated) d.title: d.due};
      expect(byTitle['With date']!.day, 3);
      expect(byTitle['With date']!.hour, isNull);
      expect(byTitle['With time']!.hour, 9);
      expect(byTitle['With time']!.minute, 30);
      expect(byTitle['Spoken only'], isNull);
      expect(byTitle['None'], isNull);
    });
  });

  group('[TSK-02/AC3] denied or revoked permission', () {
    test('creates nothing and reports a permission failure', () async {
      await _seed(db, 'r1', 'e1', [_item('Send the budget')]);
      final list = await candidates();
      platform.access = ReminderAccess.denied;
      final r = await exporter.export(list);
      expect(r, isA<Err<ReminderExportSummary>>());
      expect(
        (r as Err<ReminderExportSummary>).failure,
        isA<PermissionFailure>(),
      );
      expect(platform.store, isEmpty);
      expect(await db.select(db.reminderExports).get(), isEmpty);
    });
  });

  group('[TSK-02/AC5] no reminder text in logs', () {
    test('export logs counts only', () async {
      await _seed(db, 'r1', 'e1', [
        _item('Confidential acquisition of Zeta', owner: 'Dana Whitfield'),
      ]);
      platform.lists = const [
        ReminderList(id: 'l-secret', title: 'Secret list name'),
      ];
      await exporter.export(await candidates(), listId: 'l-secret');
      final logs = sink.lines.join('\n');
      expect(logs, isNotEmpty);
      for (final s in ['Confidential', 'Zeta', 'Dana', 'Secret list']) {
        expect(logs, isNot(contains(s)));
      }
    });
  });

  group('[TSK-02/AC6] push, re-render, push', () {
    test(
      'a re-extraction with the same wording creates no duplicate',
      () async {
        await _seed(db, 'r1', 'e1', [
          _item('Send the budget'),
          _item('Call Ana'),
        ]);
        await exporter.export(await candidates());
        expect(platform.everCreated, hasLength(2));

        // Re-extract / re-render: new extraction id, new row ids, same wording
        // (different case and spacing included).
        await db.delete(db.extractions).go();
        await _seed(db, 'r1', 'e2', [
          _item('send the  budget'),
          _item('Call Ana'),
        ], at: t0.add(const Duration(hours: 2)));
        final again = await candidates();
        expect(
          again.map((c) => c.state),
          everyElement(ReminderItemState.added),
        );
        await exporter.export(again);
        expect(platform.everCreated, hasLength(2));
      },
    );

    test('repeated identical items get separate keys', () async {
      await _seed(db, 'r1', 'e1', [_item('Call Ana'), _item('Call Ana')]);
      final list = await candidates();
      expect(list.map((c) => c.keyed.key).toSet(), hasLength(2));
      await exporter.export(list);
      await exporter.export(await candidates());
      expect(platform.everCreated, hasLength(2));
    });
  });

  group('[TSK-02/AC7] deleting a recording removes its idempotency rows', () {
    test('cascade', () async {
      await seedRecording(db, 'r2');
      await _seed(db, 'r1', 'e1', [_item('One')]);
      await _seed(db, 'r2', 'e2', [_item('Two')]);
      await exporter.export(await candidates());
      expect(await db.select(db.reminderExports).get(), hasLength(2));

      await (db.delete(db.recordings)..where((r) => r.id.equals('r1'))).go();
      final left = await db.select(db.reminderExports).get();
      expect(left.map((l) => l.recordingId), ['r2']);
    });
  });
}
