import 'package:vaultvoice/features/library/domain/library_models.dart';

enum LibraryGroup { today, yesterday, thisWeek, earlier }

typedef LibrarySection = ({LibraryGroup? group, List<LibraryItem> items});

/// Splits [items] (already sorted) into consecutive date sections relative to
/// [now]. Sections keep the input order and empty ones are omitted; the
/// caller only groups for date-based sorts.
List<LibrarySection> groupLibraryItems(List<LibraryItem> items, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  LibraryGroup of(DateTime t) {
    final l = t.toLocal();
    final day = DateTime(l.year, l.month, l.day);
    final age = today.difference(day).inDays;
    if (age <= 0) return LibraryGroup.today;
    if (age == 1) return LibraryGroup.yesterday;
    if (age < 7) return LibraryGroup.thisWeek;
    return LibraryGroup.earlier;
  }

  final sections = <LibrarySection>[];
  for (final item in items) {
    final g = of(item.createdAt);
    if (sections.isNotEmpty && sections.last.group == g) {
      sections.last.items.add(item);
    } else {
      sections.add((group: g, items: [item]));
    }
  }
  return sections;
}
