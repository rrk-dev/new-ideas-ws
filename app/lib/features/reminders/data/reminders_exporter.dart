import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/logging/logger.dart';
import 'package:vaultvoice/core/logging/redaction.dart';
import 'package:vaultvoice/core/platform/clock.dart';
import 'package:vaultvoice/features/reminders/domain/reminder_item.dart';
import 'package:vaultvoice/features/reminders/domain/reminders_platform.dart';

/// Link rows could not be read: exporting would risk duplicates.
final class _LinkReadFailed implements Exception {
  const _LinkReadFailed();
}

/// Whether an item can still be added (ADR-TSK-01 §6 reconciliation).
enum ReminderItemState {
  /// Never added.
  available,

  /// Linked and the reminder still exists: shown greyed, never updated.
  added,

  /// Linked, but the reminder is gone (deleted, or a full sync lost the
  /// identifier): selectable to add again.
  addedMissing,
}

/// One row of the selection list.
@immutable
final class ReminderCandidate {
  const ReminderCandidate(this.keyed, this.state);

  final KeyedActionItem keyed;
  final ReminderItemState state;

  bool get selectable =>
      keyed.item.eligible && state != ReminderItemState.added;
}

/// Result of one export tap.
@immutable
final class ReminderExportSummary {
  const ReminderExportSummary({
    required this.created,
    required this.skipped,
    required this.failed,
    this.listTitle,
    this.fellBackToDefault = false,
    this.listId,
  });

  final int created;
  final int skipped;
  final int failed;

  /// User content (list name): displayed, never logged.
  final String? listTitle;
  final String? listId;
  final bool fellBackToDefault;
}

/// Creates reminders from action items (TSK-02, ADR-TSK-01): create-only,
/// started by an explicit tap, no outbox and no background work. Links live
/// in `reminder_exports`; no reminder text is ever logged.
class RemindersExporter {
  RemindersExporter({
    required this._platform,
    required this._db,
    required this._clock,
    this._logger,
  });

  final RemindersPlatform _platform;
  final VaultVoiceDatabase _db;
  final Clock _clock;
  final Logger? _logger;

  Future<ReminderAccess> access() => _platform.authorizationStatus();

  Future<ReminderAccess> requestAccess() => _platform.requestAccess();

  Future<Result<List<ReminderList>>> lists() async {
    try {
      return Ok(await _platform.writableLists());
    } on RemindersAccessDenied {
      return const Err(PermissionFailure('reminders'));
    } on RemindersPlatformError catch (e) {
      return Err(UnexpectedFailure('reminders_${e.code}'));
    }
  }

  /// Items of the newest extraction of [recordingId] (or of every recording)
  /// with their link state. Done and blank items are included with
  /// `selectable == false` only when linked; otherwise they are left out.
  Future<Result<List<ReminderCandidate>>> candidates({
    String? recordingId,
  }) async {
    try {
      final all = await _loadItems(recordingId);
      final keyed = keyActionItems(all);
      final links = await _links([for (final k in keyed) k.key]);
      final stillThere = links.isEmpty
          ? <String>{}
          : await _existing([for (final l in links.values) l.calendarItemId]);
      return Ok([
        for (final k in keyed)
          if (k.item.eligible || links.containsKey(k.key))
            ReminderCandidate(k, _state(links[k.key], stillThere)),
      ]);
    } on RemindersAccessDenied {
      return const Err(PermissionFailure('reminders'));
    } on RemindersPlatformError catch (e) {
      return Err(UnexpectedFailure('reminders_${e.code}'));
    } on _LinkReadFailed {
      return const Err(UnexpectedFailure('link_read'));
    } on Object catch (e) {
      return Err(UnexpectedFailure(e.runtimeType.toString()));
    }
  }

  /// Creates reminders for [selected]. Items that are ineligible or already
  /// added (re-checked here, so a second tap never duplicates) count as
  /// skipped. A permission problem creates nothing and returns
  /// [PermissionFailure].
  Future<Result<ReminderExportSummary>> export(
    List<ReminderCandidate> selected, {
    String? listId,
  }) async {
    var skipped = 0;
    try {
      final links = await _links([for (final c in selected) c.keyed.key]);
      final stillThere = links.isEmpty
          ? <String>{}
          : await _existing([for (final l in links.values) l.calendarItemId]);
      final todo = <KeyedActionItem>[];
      final seen = <String>{};
      for (final c in selected) {
        final k = c.keyed;
        final state = _state(links[k.key], stillThere);
        if (!k.item.eligible ||
            state == ReminderItemState.added ||
            !seen.add(k.key)) {
          skipped++;
        } else {
          todo.add(k);
        }
      }
      if (todo.isEmpty) {
        _logger?.info(
          'reminders',
          'export finished',
          fields: {'created': 0, 'skipped': skipped, 'failed': 0},
        );
        return Ok(
          ReminderExportSummary(created: 0, skipped: skipped, failed: 0),
        );
      }
      final batch = await _platform.createReminders(
        listId: listId,
        drafts: [for (final k in todo) buildReminderDraft(k)],
      );
      final byKey = {for (final k in todo) k.key: k};
      var created = 0;
      var failed = 0;
      final now = _clock.now();
      for (final r in batch.created) {
        final item = byKey.remove(r.key);
        final id = r.calendarItemId;
        if (item == null) continue;
        if (!r.ok || id == null) {
          failed++;
          continue;
        }
        created++;
        final saved = await _db.reminderExportsRepository.upsert(
          ReminderExportsCompanion.insert(
            itemKey: r.key,
            recordingId: item.item.recordingId,
            calendarItemId: id,
            reminderCalendarId: batch.listId,
            exportedAt: now,
          ),
        );
        if (!saved.isOk) {
          _logger?.warning('reminders', 'link not saved');
        }
      }
      failed += byKey.length;
      _logger?.info(
        'reminders',
        'export finished',
        fields: {
          'created': created,
          'skipped': skipped,
          'failed': failed,
          'fell_back': batch.fellBackToDefault,
        },
      );
      return Ok(
        ReminderExportSummary(
          created: created,
          skipped: skipped,
          failed: failed,
          listTitle: batch.listTitle,
          listId: batch.listId,
          fellBackToDefault: batch.fellBackToDefault,
        ),
      );
    } on RemindersAccessDenied {
      _logger?.warning('reminders', 'access denied');
      return const Err(PermissionFailure('reminders'));
    } on RemindersPlatformError catch (e) {
      _logger?.warning(
        'reminders',
        'host failed',
        fields: {'code': LogId(e.code)},
      );
      return Err(UnexpectedFailure('reminders_${e.code}'));
    } on _LinkReadFailed {
      return const Err(UnexpectedFailure('link_read'));
    }
  }

  ReminderItemState _state(ReminderExportRow? link, Set<String> stillThere) =>
      link == null
      ? ReminderItemState.available
      : stillThere.contains(link.calendarItemId)
      ? ReminderItemState.added
      : ReminderItemState.addedMissing;

  Future<Map<String, ReminderExportRow>> _links(List<String> keys) async {
    final r = await _db.reminderExportsRepository.linksFor(keys);
    return switch (r) {
      Ok(value: final v) => v,
      Err() => throw const _LinkReadFailed(),
    };
  }

  Future<Set<String>> _existing(List<String> ids) =>
      _platform.existingReminderIds(ids);

  /// Newest extraction's items per recording (older extractions can leave
  /// rows behind), with the recording facts the mapping needs.
  Future<List<ExportableActionItem>> _loadItems(String? recordingId) async {
    final query = _db.select(_db.actionItems).join([
      innerJoin(
        _db.recordings,
        _db.recordings.id.equalsExp(_db.actionItems.recordingId),
      ),
      innerJoin(
        _db.extractions,
        _db.extractions.id.equalsExp(_db.actionItems.extractionId),
      ),
    ]);
    if (recordingId != null) {
      query.where(_db.actionItems.recordingId.equals(recordingId));
    }
    query.orderBy([
      OrderingTerm.desc(_db.recordings.createdAt),
      OrderingTerm.asc(_db.actionItems.id),
    ]);
    final rows = await query.get();
    final newest = <String, DateTime>{};
    final newestId = <String, String>{};
    for (final r in rows) {
      final e = r.readTable(_db.extractions);
      final cur = newest[e.recordingId];
      if (cur == null || e.createdAt.isAfter(cur)) {
        newest[e.recordingId] = e.createdAt;
        newestId[e.recordingId] = e.id;
      }
    }
    return [
      for (final r in rows)
        if (r.readTable(_db.actionItems).extractionId ==
            newestId[r.readTable(_db.actionItems).recordingId])
          () {
            final a = r.readTable(_db.actionItems);
            final rec = r.readTable(_db.recordings);
            return ExportableActionItem(
              rowId: a.id,
              recordingId: a.recordingId,
              recordingTitle: rec.title,
              recordingCreatedAt: rec.createdAt,
              body: a.body,
              done: a.done,
              owner: a.owner,
              dueIso: a.dueIso,
              tMs: a.tMs,
            );
          }(),
    ];
  }
}
