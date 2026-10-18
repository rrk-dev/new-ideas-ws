import 'package:flutter/services.dart';
import 'package:vaultvoice/features/reminders/data/pigeon/reminders_api.g.dart';
import 'package:vaultvoice/features/reminders/domain/reminder_item.dart';
import 'package:vaultvoice/features/reminders/domain/reminders_platform.dart';

/// [RemindersPlatform] over the Pigeon `RemindersHostApi`
/// (`ios/Runner/RemindersHostApiImpl.swift`, shared by iOS and macOS). A
/// missing host (tests, other platforms) reads as "unsupported".
class PigeonRemindersPlatform implements RemindersPlatform {
  PigeonRemindersPlatform({RemindersHostApi? api})
    : _api = api ?? RemindersHostApi();

  final RemindersHostApi _api;

  static ReminderAccess _access(ReminderAuthStatusMessage m) => switch (m) {
    ReminderAuthStatusMessage.notDetermined => ReminderAccess.notDetermined,
    ReminderAuthStatusMessage.denied => ReminderAccess.denied,
    ReminderAuthStatusMessage.restricted => ReminderAccess.restricted,
    ReminderAuthStatusMessage.granted => ReminderAccess.granted,
    ReminderAuthStatusMessage.unsupported => ReminderAccess.unsupported,
  };

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (e) {
      if (e.code == 'denied') throw const RemindersAccessDenied();
      throw RemindersPlatformError(e.code);
    }
  }

  @override
  Future<ReminderAccess> authorizationStatus() async {
    try {
      return _access(await _api.authorizationStatus());
    } on PlatformException {
      return ReminderAccess.unsupported;
    }
  }

  @override
  Future<ReminderAccess> requestAccess() async {
    try {
      return _access(await _api.requestAccess());
    } on PlatformException {
      return ReminderAccess.unsupported;
    }
  }

  @override
  Future<List<ReminderList>> writableLists() => _guard(() async {
    final lists = await _api.writableLists();
    return [for (final l in lists) ReminderList(id: l.id, title: l.title)];
  });

  @override
  Future<ReminderBatch> createReminders({
    required String? listId,
    required List<ReminderDraft> drafts,
  }) => _guard(() async {
    final r = await _api.createReminders(listId, [
      for (final d in drafts)
        ReminderDraftMessage(
          key: d.key,
          title: d.title,
          notes: d.notes,
          dueYear: d.due?.year,
          dueMonth: d.due?.month,
          dueDay: d.due?.day,
          dueHour: d.due?.hour,
          dueMinute: d.due?.minute,
        ),
    ]);
    return ReminderBatch(
      listId: r.listId,
      listTitle: r.listTitle,
      fellBackToDefault: r.fellBackToDefault,
      created: [
        for (final c in r.created)
          ReminderCreated(
            key: c.key,
            ok: c.ok,
            calendarItemId: c.calendarItemId,
          ),
      ],
    );
  });

  @override
  Future<Set<String>> existingReminderIds(Iterable<String> calendarItemIds) =>
      _guard(
        () async =>
            (await _api.existingReminderIds(calendarItemIds.toList())).toSet(),
      );
}

/// The Android (and unsupported) platform: nothing to export to.
class UnsupportedRemindersPlatform implements RemindersPlatform {
  const UnsupportedRemindersPlatform();

  @override
  Future<ReminderAccess> authorizationStatus() async =>
      ReminderAccess.unsupported;

  @override
  Future<ReminderAccess> requestAccess() async => ReminderAccess.unsupported;

  @override
  Future<List<ReminderList>> writableLists() async => const [];

  @override
  Future<ReminderBatch> createReminders({
    required String? listId,
    required List<ReminderDraft> drafts,
  }) => throw const RemindersPlatformError('unsupported');

  @override
  Future<Set<String>> existingReminderIds(
    Iterable<String> calendarItemIds,
  ) async => const {};
}
