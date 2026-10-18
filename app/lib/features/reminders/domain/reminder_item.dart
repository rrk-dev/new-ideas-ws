import 'dart:convert';

import 'package:characters/characters.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// An action item as the Reminders export sees it (ADR-TSK-01 §4).
@immutable
final class ExportableActionItem {
  const ExportableActionItem({
    required this.rowId,
    required this.recordingId,
    required this.recordingTitle,
    required this.recordingCreatedAt,
    required this.body,
    required this.done,
    this.owner,
    this.dueIso,
    this.tMs,
  });

  final int rowId;
  final String recordingId;

  /// User content: displayed in the selection list, never logged and never
  /// written to Reminders.
  final String recordingTitle;
  final DateTime recordingCreatedAt;

  /// User content: displayed, never logged.
  final String body;
  final bool done;
  final String? owner;
  final String? dueIso;
  final int? tMs;

  /// Offered for export: open and not blank (ADR eligibility 1 and 2).
  bool get eligible => !done && body.trim().isNotEmpty;
}

/// Normalised wording used for the identity key: NFKC, lower case, trimmed,
/// whitespace runs collapsed, leading and trailing punctuation removed.
String normaliseActionBody(String body) {
  final folded = unorm
      .nfkc(body)
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
  return folded.replaceAll(
    RegExp('^[.,;:!?\\-–—"\']+|[.,;:!?\\-–—"\']+\$'),
    '',
  );
}

/// `sha256(recordingId ␟ norm(body) ␟ occurrence)` as hex (ADR-TSK-01 §6).
String reminderItemKey({
  required String recordingId,
  required String normalisedBody,
  required int occurrence,
}) => sha256
    .convert(utf8.encode('$recordingId\u001F$normalisedBody\u001F$occurrence'))
    .toString();

/// An item together with its stable key.
@immutable
final class KeyedActionItem {
  const KeyedActionItem(this.item, this.key);

  final ExportableActionItem item;
  final String key;
}

/// Computes the key of every item. `occurrence` counts earlier items of the
/// same recording with the same normalised wording, ordered by `tMs`
/// ascending (nulls last), then body, then row id; it is computed over all
/// items of the recording (done ones included) so ticking an item off never
/// shifts the key of a duplicate.
List<KeyedActionItem> keyActionItems(List<ExportableActionItem> items) {
  final byRecording = <String, List<ExportableActionItem>>{};
  for (final i in items) {
    (byRecording[i.recordingId] ??= []).add(i);
  }
  final keys = <int, String>{};
  for (final entry in byRecording.entries) {
    final ordered = [...entry.value]
      ..sort((a, b) {
        final at = a.tMs;
        final bt = b.tMs;
        if (at != bt) {
          if (at == null) return 1;
          if (bt == null) return -1;
          return at.compareTo(bt);
        }
        final byBody = a.body.compareTo(b.body);
        return byBody != 0 ? byBody : a.rowId.compareTo(b.rowId);
      });
    final seen = <String, int>{};
    for (final i in ordered) {
      final norm = normaliseActionBody(i.body);
      final n = seen.update(norm, (v) => v + 1, ifAbsent: () => 0);
      keys[i.rowId] = reminderItemKey(
        recordingId: entry.key,
        normalisedBody: norm,
        occurrence: n,
      );
    }
  }
  return [for (final i in items) KeyedActionItem(i, keys[i.rowId]!)];
}

/// Calendar components of a due date.
@immutable
final class ReminderDue {
  const ReminderDue({
    required this.year,
    required this.month,
    required this.day,
    this.hour,
    this.minute,
  });

  final int year;
  final int month;
  final int day;
  final int? hour;
  final int? minute;

  @override
  bool operator ==(Object other) =>
      other is ReminderDue &&
      other.year == year &&
      other.month == month &&
      other.day == day &&
      other.hour == hour &&
      other.minute == minute;

  @override
  int get hashCode => Object.hash(year, month, day, hour, minute);
}

final _isoDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final _isoDateTime = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?'
  r'(?:Z|[+-]\d{2}(?::?\d{2})?)?$',
);

/// The due date of [dueIso] when it is a strict ISO-8601 calendar date or
/// date-time, else null. A date gives year/month/day only; a date-time adds
/// the written hour and minute (a UTC offset is ignored: the wall-clock time
/// is kept). Spoken phrases ("next Friday") are never interpreted.
ReminderDue? parseReminderDue(String? dueIso) {
  final text = dueIso?.trim();
  if (text == null || text.isEmpty) return null;
  final date = _isoDate.firstMatch(text);
  final dateTime = date == null ? _isoDateTime.firstMatch(text) : null;
  final m = date ?? dateTime;
  if (m == null) return null;
  final y = int.parse(m[1]!);
  final mo = int.parse(m[2]!);
  final d = int.parse(m[3]!);
  final probe = DateTime.utc(y, mo, d);
  if (y < 1 || probe.year != y || probe.month != mo || probe.day != d) {
    return null;
  }
  if (dateTime == null) return ReminderDue(year: y, month: mo, day: d);
  final h = int.parse(m[4]!);
  final mi = int.parse(m[5]!);
  final s = m[6] == null ? 0 : int.parse(m[6]!);
  if (h > 23 || mi > 59 || s > 59) return null;
  return ReminderDue(year: y, month: mo, day: d, hour: h, minute: mi);
}

/// Longest reminder title we write (our choice, not an Apple limit).
const int kReminderTitleMax = 255;

/// What is written to Reminders for one item.
@immutable
final class ReminderDraft {
  const ReminderDraft({
    required this.key,
    required this.title,
    required this.notes,
    this.due,
  });

  final String key;
  final String title;
  final String notes;
  final ReminderDue? due;
}

/// Maps an item to a draft: whitespace-collapsed title truncated at a
/// grapheme boundary; notes `Owner: <owner>` (text only) and
/// `From Lumen, <yyyy-mm-dd>`; no transcript text, no recording title.
ReminderDraft buildReminderDraft(KeyedActionItem keyed) {
  final item = keyed.item;
  final title = item.body
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .characters
      .take(kReminderTitleMax)
      .toString();
  final owner = item.owner?.trim();
  final created = item.recordingCreatedAt.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  final date =
      '${created.year.toString().padLeft(4, '0')}-'
      '${two(created.month)}-${two(created.day)}';
  return ReminderDraft(
    key: keyed.key,
    title: title,
    notes: [
      if (owner != null && owner.isNotEmpty) 'Owner: $owner',
      'From Lumen, $date',
    ].join('\n'),
    due: parseReminderDue(item.dueIso),
  );
}
