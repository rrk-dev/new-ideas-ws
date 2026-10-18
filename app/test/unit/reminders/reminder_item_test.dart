import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/reminders/domain/reminder_item.dart';

ExportableActionItem _item(
  int id,
  String body, {
  String recording = 'r1',
  bool done = false,
  String? owner,
  String? due,
  int? tMs,
}) => ExportableActionItem(
  rowId: id,
  recordingId: recording,
  recordingTitle: 'Private title',
  recordingCreatedAt: DateTime(2026, 10, 12, 9),
  body: body,
  done: done,
  owner: owner,
  dueIso: due,
  tMs: tMs,
);

void main() {
  test('normalisation folds case, spacing and edge punctuation', () {
    expect(normaliseActionBody('  Send   the BUDGET. '), 'send the budget');
    expect(normaliseActionBody('Ｓend it!'), 'send it');
  });

  test('keys depend on recording, wording and occurrence only', () {
    final a = keyActionItems([_item(1, 'Call Ana'), _item(2, 'Call Ana')]);
    final b = keyActionItems([_item(9, 'call ana.')]);
    expect(a[0].key, isNot(a[1].key));
    expect(b.single.key, a.first.key);
    final other = keyActionItems([_item(1, 'Call Ana', recording: 'r2')]);
    expect(other.single.key, isNot(a.first.key));
  });

  test('done items still count for the occurrence number', () {
    final all = keyActionItems([
      _item(1, 'Call Ana', done: true),
      _item(2, 'Call Ana'),
    ]);
    final alone = keyActionItems([_item(2, 'Call Ana')]);
    expect(all[1].key, isNot(alone.single.key));
  });

  test('due parsing is strict', () {
    expect(parseReminderDue('2026-11-03')?.day, 3);
    expect(parseReminderDue('2026-11-03T09:30:00')?.minute, 30);
    expect(parseReminderDue('2026-02-30'), isNull);
    expect(parseReminderDue('next Friday'), isNull);
    expect(parseReminderDue(null), isNull);
  });

  test('draft carries owner and date but no recording title', () {
    final d = buildReminderDraft(
      keyActionItems([_item(1, ' Send  it ', owner: 'Dana')]).single,
    );
    expect(d.title, 'Send it');
    expect(d.notes, 'Owner: Dana\nFrom Lumen, 2026-10-12');
    expect(d.notes, isNot(contains('Private title')));
  });

  test('long titles are truncated', () {
    final d = buildReminderDraft(keyActionItems([_item(1, 'x' * 400)]).single);
    expect(d.title.length, kReminderTitleMax);
  });

  test('[TSK-02/AC4] device rows exist for the EventKit behaviour', () {
    final doc = File('../docs/test-plans/device/TSK-02.md').readAsStringSync();
    for (final row in ['D1', 'D3', 'D4', 'D5', 'D6', 'D9', 'D11']) {
      expect(doc, contains('| $row [TSK-02/AC4]'));
    }
    expect(doc, contains('release gate'));
  });
}
