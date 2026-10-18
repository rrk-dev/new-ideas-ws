import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/diagnostics/diagnostics_providers.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/features/reminders/data/pigeon_reminders_platform.dart';
import 'package:vaultvoice/features/reminders/data/reminders_exporter.dart';
import 'package:vaultvoice/features/reminders/domain/reminders_platform.dart';

part 'reminders_providers.g.dart';

/// Apple Reminders exists on iOS and macOS only; Android shows no action
/// (ADR-TSK-01 §3). Tests override it.
@Riverpod(keepAlive: true)
bool remindersSupported(Ref ref) => Platform.isIOS || Platform.isMacOS;

@Riverpod(keepAlive: true)
RemindersPlatform remindersPlatform(Ref ref) =>
    ref.watch(remindersSupportedProvider)
    ? PigeonRemindersPlatform()
    : const UnsupportedRemindersPlatform();

@Riverpod(keepAlive: true)
RemindersExporter remindersExporter(Ref ref) => RemindersExporter(
  platform: ref.watch(remindersPlatformProvider),
  db: ref.watch(vaultVoiceDatabaseProvider),
  clock: ref.watch(clockProvider),
  logger: ref.watch(loggerProvider),
);
