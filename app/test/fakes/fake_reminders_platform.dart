import 'package:vaultvoice/features/reminders/domain/reminder_item.dart';
import 'package:vaultvoice/features/reminders/domain/reminders_platform.dart';

/// In-memory stand-in for the EventKit host (TSK-02): reminders live in
/// [store] by calendar item id; the user can delete them externally.
class FakeRemindersPlatform implements RemindersPlatform {
  ReminderAccess access = ReminderAccess.granted;

  /// What a permission prompt answers.
  ReminderAccess promptAnswer = ReminderAccess.granted;

  final Map<String, ReminderDraft> store = {};
  final List<ReminderDraft> everCreated = [];
  List<ReminderList> lists = const [ReminderList(id: 'l-work', title: 'Work')];

  /// Draft keys the host fails to save.
  final Set<String> failKeys = {};
  bool lumenListFails = false;
  int requestCount = 0;
  int _next = 0;

  void deleteExternally(String id) => store.remove(id);

  @override
  Future<ReminderAccess> authorizationStatus() async => access;

  @override
  Future<ReminderAccess> requestAccess() async {
    requestCount++;
    if (access == ReminderAccess.notDetermined) access = promptAnswer;
    return access;
  }

  @override
  Future<List<ReminderList>> writableLists() async {
    _requireAccess();
    return lists;
  }

  @override
  Future<ReminderBatch> createReminders({
    required String? listId,
    required List<ReminderDraft> drafts,
  }) async {
    _requireAccess();
    final known = lists.any((l) => l.id == listId);
    final fellBack = !known && lumenListFails;
    final created = <ReminderCreated>[];
    for (final d in drafts) {
      if (failKeys.contains(d.key)) {
        created.add(ReminderCreated(key: d.key, ok: false));
        continue;
      }
      final id = 'cal-${_next++}';
      store[id] = d;
      everCreated.add(d);
      created.add(ReminderCreated(key: d.key, ok: true, calendarItemId: id));
    }
    return ReminderBatch(
      listId: known ? listId! : (fellBack ? 'l-default' : 'l-lumen'),
      listTitle: known ? 'Work' : (fellBack ? 'Reminders' : 'Lumen'),
      fellBackToDefault: fellBack,
      created: created,
    );
  }

  @override
  Future<Set<String>> existingReminderIds(Iterable<String> ids) async {
    _requireAccess();
    return {
      for (final id in ids)
        if (store.containsKey(id)) id,
    };
  }

  void _requireAccess() {
    if (access != ReminderAccess.granted) throw const RemindersAccessDenied();
  }
}
