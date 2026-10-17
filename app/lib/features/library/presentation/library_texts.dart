import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/features/library/domain/library_grouping.dart';
import 'package:vaultvoice/features/library/domain/library_models.dart';

/// Localized Library labels.
abstract final class LibraryTexts {
  static String status(AppLocalizations l, LibraryStatus s) => switch (s) {
    LibraryStatus.recording => l.libraryStatusRecording,
    LibraryStatus.recorded => l.libraryStatusRecorded,
    LibraryStatus.processing => l.libraryStatusProcessing,
    LibraryStatus.waiting => l.libraryStatusWaiting,
    LibraryStatus.processed => l.libraryStatusProcessed,
    LibraryStatus.exported => l.libraryStatusExported,
    LibraryStatus.failed => l.libraryStatusFailed,
  };

  static IconData statusIcon(LibraryStatus s) => switch (s) {
    LibraryStatus.recording => Icons.fiber_manual_record_outlined,
    LibraryStatus.recorded => Icons.mic_none,
    LibraryStatus.processing => Icons.autorenew,
    LibraryStatus.waiting => Icons.hourglass_empty,
    LibraryStatus.processed => Icons.description_outlined,
    LibraryStatus.exported => Icons.check_circle_outline,
    LibraryStatus.failed => Icons.error_outline,
  };

  static String group(AppLocalizations l, LibraryGroup g) => switch (g) {
    LibraryGroup.today => l.libraryGroupToday,
    LibraryGroup.yesterday => l.libraryGroupYesterday,
    LibraryGroup.thisWeek => l.libraryGroupThisWeek,
    LibraryGroup.earlier => l.libraryGroupEarlier,
  };

  static String sort(AppLocalizations l, LibrarySort s) => switch (s) {
    LibrarySort.newest => l.librarySortNewest,
    LibrarySort.oldest => l.librarySortOldest,
    LibrarySort.longest => l.librarySortLongest,
    LibrarySort.title => l.librarySortTitle,
  };

  static String date(AppLocalizations l, DateTime d) =>
      DateFormat.yMMMd(l.localeName).add_jm().format(d.toLocal());

  static String shortDate(AppLocalizations l, DateTime d) =>
      DateFormat.yMMMd(l.localeName).format(d.toLocal());

  static String duration(AppLocalizations l, Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return l.durationHoursMinutes(h, m);
    if (m > 0) return l.durationMinutesSeconds(m, s);
    return l.durationSeconds(s);
  }

  static String title(AppLocalizations l, String title) =>
      title.trim().isEmpty ? l.untitledRecording : title;
}
