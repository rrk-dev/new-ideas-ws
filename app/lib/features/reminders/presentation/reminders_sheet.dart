import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/platform/app_settings_launcher.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/core/widgets/status_message.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/licensing/domain/paywall.dart';
import 'package:vaultvoice/features/licensing/presentation/feature_gate.dart';
import 'package:vaultvoice/features/reminders/data/reminders_exporter.dart';
import 'package:vaultvoice/features/reminders/data/reminders_providers.dart';
import 'package:vaultvoice/features/reminders/domain/reminder_item.dart';
import 'package:vaultvoice/features/reminders/domain/reminders_platform.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';

/// Opens the Reminders sheet after the licence check. Callers hide their
/// action when [remindersSupportedProvider] is false.
Future<void> showRemindersSheet(
  BuildContext context,
  WidgetRef ref, {
  String? recordingId,
}) async {
  final allowed = await ensureFeature(
    ref,
    Feature.remindersExport,
    from: PaywallEntryPoint.reminders,
  );
  if (!allowed || !context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => RemindersSheet(recordingId: recordingId),
  );
}

/// Select action items and add them to Apple Reminders (TSK-02). Nothing is
/// requested or created before the user's taps.
class RemindersSheet extends ConsumerStatefulWidget {
  const RemindersSheet({this.recordingId, super.key});

  final String? recordingId;

  @override
  ConsumerState<RemindersSheet> createState() => _RemindersSheetState();
}

class _RemindersSheetState extends ConsumerState<RemindersSheet> {
  ReminderAccess? _access;
  bool _loadFailed = false;
  bool _busy = false;
  List<ReminderCandidate> _items = const [];
  List<ReminderList> _lists = const [];
  final Set<String> _selected = {};
  String? _listId;
  ReminderExportSummary? _summary;

  RemindersExporter get _exporter => ref.read(remindersExporterProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    final access = await _exporter.access();
    if (!mounted) return;
    setState(() => _access = access);
    if (access == ReminderAccess.granted) await _load();
  }

  Future<void> _continue() async {
    setState(() => _busy = true);
    final access = await _exporter.requestAccess();
    if (!mounted) return;
    setState(() {
      _access = access;
      _busy = false;
    });
    if (access == ReminderAccess.granted) await _load();
  }

  Future<void> _load() async {
    setState(() => _loadFailed = false);
    final items = await _exporter.candidates(recordingId: widget.recordingId);
    final lists = await _exporter.lists();
    final last = await ref
        .read(settingsRepositoryProvider)
        .get(SettingKeys.remindersLastList);
    if (!mounted) return;
    if (items case Err(failure: final f) when f is PermissionFailure) {
      setState(() => _access = ReminderAccess.denied);
      return;
    }
    if (items is! Ok<List<ReminderCandidate>> ||
        lists is! Ok<List<ReminderList>>) {
      setState(() => _loadFailed = true);
      return;
    }
    final lastId = last.valueOrNull;
    setState(() {
      _items = items.value;
      _lists = lists.value;
      _listId = lastId is String && lists.value.any((l) => l.id == lastId)
          ? lastId
          : null;
      _selected
        ..clear()
        ..addAll([
          for (final c in _items)
            if (c.selectable && c.state == ReminderItemState.available)
              c.keyed.key,
        ]);
    });
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    final chosen = [
      for (final c in _items)
        if (_selected.contains(c.keyed.key)) c,
    ];
    final r = await _exporter.export(chosen, listId: _listId);
    if (!mounted) return;
    switch (r) {
      case Err(failure: final f) when f is PermissionFailure:
        setState(() {
          _access = ReminderAccess.denied;
          _busy = false;
        });
      case Err():
        setState(() {
          _loadFailed = true;
          _busy = false;
        });
      case Ok(value: final summary):
        if (summary.listId != null) {
          await ref
              .read(settingsRepositoryProvider)
              .set(SettingKeys.remindersLastList, summary.listId);
        }
        setState(() {
          _summary = summary;
          _busy = false;
        });
    }
  }

  String? _due(ExportableActionItem item) {
    final due = parseReminderDue(item.dueIso);
    if (due == null) return null;
    String two(int v) => v.toString().padLeft(2, '0');
    final date = '${due.year}-${two(due.month)}-${two(due.day)}';
    return due.hour == null
        ? date
        : '$date ${two(due.hour!)}:${two(due.minute ?? 0)}';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final access = _access;
    final Widget body;
    if (access == null) {
      body = Center(
        child: CircularProgressIndicator(semanticsLabel: l.commonLoading),
      );
    } else if (access.blocked) {
      body = StatusMessage(
        icon: Icons.lock_outline,
        message: access == ReminderAccess.restricted
            ? l.remindersRestricted
            : l.remindersDenied,
        actionLabel: access == ReminderAccess.denied
            ? l.remindersOpenSettings
            : null,
        onAction: () => ref.read(appSettingsLauncherProvider).openAppSettings(),
      );
    } else if (access == ReminderAccess.notDetermined) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.remindersPrimer),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const ValueKey('reminders-continue'),
            onPressed: _busy ? null : _continue,
            child: Text(l.remindersContinue),
          ),
        ],
      );
    } else if (access != ReminderAccess.granted) {
      body = StatusMessage(icon: Icons.block, message: l.remindersLoadFailed);
    } else if (_loadFailed) {
      body = StatusMessage(
        icon: Icons.error_outline,
        message: l.remindersLoadFailed,
        actionLabel: l.commonTryAgain,
        onAction: _load,
      );
    } else if (_summary case final s?) {
      body = _result(l, s);
    } else {
      body = _selection(l);
    }
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.remindersTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Flexible(child: body),
          ],
        ),
      ),
    );
  }

  Widget _result(AppLocalizations l, ReminderExportSummary s) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        l.remindersResult(s.created, s.skipped, s.failed),
        key: const ValueKey('reminders-result'),
      ),
      if (s.listTitle case final title?)
        Text(
          s.fellBackToDefault
              ? l.remindersFellBack(title)
              : l.remindersResultList(title),
        ),
      const SizedBox(height: AppSpacing.md),
      FilledButton(
        onPressed: () => Navigator.of(context).maybePop(),
        child: Text(l.remindersDone),
      ),
    ],
  );

  Widget _selection(AppLocalizations l) {
    final selectable = _items.where((c) => c.selectable).toList();
    if (selectable.isEmpty) {
      return StatusMessage(icon: Icons.task_alt, message: l.remindersNone);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String?>(
          key: const ValueKey('reminders-list'),
          initialValue: _listId,
          decoration: InputDecoration(labelText: l.remindersList),
          items: [
            DropdownMenuItem<String?>(child: Text(l.remindersListDefault)),
            for (final list in _lists)
              DropdownMenuItem<String?>(
                value: list.id,
                child: Text(list.title),
              ),
          ],
          onChanged: (v) => setState(() => _listId = v),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final c in _items)
                if (c.keyed.item.eligible ||
                    c.state != ReminderItemState.available)
                  _row(l, c),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton(
          key: const ValueKey('reminders-add'),
          onPressed: _busy || _selected.isEmpty ? null : _export,
          child: Text(l.remindersAddCount(_selected.length)),
        ),
      ],
    );
  }

  Widget _row(AppLocalizations l, ReminderCandidate c) {
    final item = c.keyed.item;
    final due = _due(item);
    final owner = item.owner;
    final status = switch (c.state) {
      ReminderItemState.added => l.remindersAdded,
      ReminderItemState.addedMissing => l.remindersAddedMissing,
      ReminderItemState.available => null,
    };
    final parts = <String>[
      ?status,
      if (owner != null && owner.trim().isNotEmpty)
        l.remindersOwner(owner.trim()),
      ?(due == null ? null : l.remindersDue(due)),
    ];
    return CheckboxListTile(
      key: ValueKey('reminders-item-${c.keyed.key}'),
      value:
          c.state == ReminderItemState.added || _selected.contains(c.keyed.key),
      onChanged: c.selectable
          ? (v) => setState(() {
              if (v ?? false) {
                _selected.add(c.keyed.key);
              } else {
                _selected.remove(c.keyed.key);
              }
            })
          : null,
      title: Text(item.body),
      subtitle: parts.isEmpty ? null : Text(parts.join(' · ')),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}
