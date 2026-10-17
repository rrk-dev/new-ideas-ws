import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/core/routing/app_routes.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/core/widgets/circle_icon_button.dart';
import 'package:vaultvoice/core/widgets/grouped_card.dart';
import 'package:vaultvoice/core/widgets/section_header.dart';
import 'package:vaultvoice/core/widgets/status_message.dart';
import 'package:vaultvoice/features/library/data/library_providers.dart';
import 'package:vaultvoice/features/library/domain/library_grouping.dart';
import 'package:vaultvoice/features/library/domain/library_models.dart';
import 'package:vaultvoice/features/library/presentation/library_texts.dart';

/// Library tab (APP-02): every recording with title, date, duration,
/// profile, status and export destination; full-text search over titles,
/// tags, transcripts and extracted fields; filters and sort.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  late final TextEditingController _search = TextEditingController(
    text: ref.read(libraryFilterStateProvider).query,
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _update(LibraryFilter Function(LibraryFilter f) change) {
    ref
        .read(libraryFilterStateProvider.notifier)
        .update(change(ref.read(libraryFilterStateProvider)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filter = ref.watch(libraryFilterStateProvider);
    final results = ref.watch(libraryResultsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabLibrary),
        actions: [
          CircleIconButton(
            key: const ValueKey('library-action-items'),
            tooltip: l10n.actionItemsTitle,
            icon: Icons.checklist,
            onPressed: () => const ActionItemsRoute().go(context),
          ),
          PopupMenuButton<LibrarySort>(
            key: const ValueKey('library-sort'),
            tooltip: l10n.librarySort,
            icon: const Icon(Icons.sort),
            style: circleMenuStyle(context),
            initialValue: filter.sort,
            onSelected: (s) => _update((f) => f.copyWith(sort: s)),
            itemBuilder: (context) => [
              for (final s in LibrarySort.values)
                PopupMenuItem(
                  value: s,
                  child: Text(LibraryTexts.sort(context.l10n, s)),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: TextField(
              key: const ValueKey('library-search'),
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.librarySearchHint,
                suffixIcon: filter.query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l10n.librarySearchClear,
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          _update((f) => f.copyWith(query: ''));
                        },
                      ),
              ),
              onChanged: (q) => _update((f) => f.copyWith(query: q)),
            ),
          ),
          _FilterBar(filter: filter, onChange: _update),
          Expanded(
            child: results.when(
              skipLoadingOnReload: true,
              loading: () => Center(
                child: CircularProgressIndicator(
                  semanticsLabel: l10n.commonLoading,
                ),
              ),
              error: (_, _) => StatusMessage(
                icon: Icons.error_outline,
                message: l10n.libraryLoadFailed,
                actionLabel: l10n.commonTryAgain,
                onAction: () => ref.invalidate(libraryItemsProvider),
              ),
              data: (r) {
                if (r.items.isEmpty) {
                  final nothingYet =
                      !r.searching &&
                      !filter.hasFilters &&
                      (ref.read(libraryItemsProvider).value?.isEmpty ?? true);
                  return StatusMessage(
                    icon: nothingYet ? Icons.library_books : Icons.search_off,
                    message: nothingYet
                        ? l10n.libraryEmpty
                        : l10n.libraryNoMatches,
                  );
                }
                final dated =
                    filter.sort == LibrarySort.newest ||
                    filter.sort == LibrarySort.oldest;
                final sections = dated
                    ? groupLibraryItems(r.items, ref.watch(clockProvider).now())
                    : <LibrarySection>[(group: null, items: r.items)];
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppSizes.maxContentWidth,
                    ),
                    child: ListView(
                      key: const ValueKey('library-list'),
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      children: [
                        for (final s in sections) ...[
                          if (s.group case final g?)
                            SectionHeader(
                              LibraryTexts.group(l10n, g),
                              key: ValueKey('library-group-${g.name}'),
                            ),
                          GroupedCard(
                            children: [
                              for (final item in s.items)
                                LibraryTile(item: item, hit: r.hits[item.id]),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.filter, required this.onChange});

  final LibraryFilter filter;
  final void Function(LibraryFilter Function(LibraryFilter f)) onChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profiles = ref.watch(profileNamesProvider).value ?? const {};
    final items = ref.watch(libraryItemsProvider).value ?? const [];
    final tags = {for (final i in items) ...i.tags}.toList()..sort();
    final range = filter.from == null || filter.to == null
        ? null
        : '${LibraryTexts.shortDate(l10n, filter.from!)} – '
              '${LibraryTexts.shortDate(l10n, filter.to!)}';
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        spacing: AppSpacing.sm,
        children: [
          _MenuChip<LibraryStatus>(
            key: const ValueKey('library-filter-status'),
            label: filter.statuses.isEmpty
                ? l10n.libraryFilterStatus
                : LibraryTexts.status(l10n, filter.statuses.first),
            selected: filter.statuses.isNotEmpty,
            values: LibraryStatus.values,
            labelOf: (s) => LibraryTexts.status(l10n, s),
            onSelected: (s) => onChange((f) => f.copyWith(statuses: {?s})),
          ),
          _MenuChip<String>(
            key: const ValueKey('library-filter-profile'),
            label: filter.profileId == null
                ? l10n.libraryFilterProfile
                : profiles[filter.profileId] ?? filter.profileId!,
            selected: filter.profileId != null,
            values: profiles.keys.toList(),
            labelOf: (id) => profiles[id] ?? id,
            onSelected: (id) =>
                onChange((f) => f.copyWith(profileId: () => id)),
          ),
          if (tags.isNotEmpty)
            _MenuChip<String>(
              key: const ValueKey('library-filter-tag'),
              label: filter.tag ?? l10n.libraryFilterTag,
              selected: filter.tag != null,
              values: tags,
              labelOf: (t) => t,
              onSelected: (t) => onChange((f) => f.copyWith(tag: () => t)),
            ),
          FilterChip(
            key: const ValueKey('library-filter-date'),
            label: Text(range ?? l10n.libraryFilterDate),
            selected: range != null,
            onSelected: (_) async {
              if (range != null) {
                onChange((f) => f.copyWith(from: () => null, to: () => null));
                return;
              }
              final now = DateTime.now();
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(now.year + 1),
              );
              if (picked == null) return;
              onChange(
                (f) =>
                    f.copyWith(from: () => picked.start, to: () => picked.end),
              );
            },
          ),
          if (filter.hasFilters)
            ActionChip(
              key: const ValueKey('library-filter-clear'),
              label: Text(l10n.libraryFilterClear),
              onPressed: () =>
                  onChange((f) => LibraryFilter(query: f.query, sort: f.sort)),
            ),
        ],
      ),
    );
  }
}

/// A filter chip that opens a menu of [values] ("All" clears the filter).
class _MenuChip<T> extends StatelessWidget {
  const _MenuChip({
    required this.label,
    required this.selected,
    required this.values,
    required this.labelOf,
    required this.onSelected,
    super.key,
  });

  final String label;
  final bool selected;
  final List<T> values;
  final String Function(T value) labelOf;
  final void Function(T? value) onSelected;

  @override
  Widget build(BuildContext context) => MenuAnchor(
    menuChildren: [
      MenuItemButton(
        onPressed: () => onSelected(null),
        child: Text(context.l10n.libraryFilterAll),
      ),
      for (final v in values)
        MenuItemButton(onPressed: () => onSelected(v), child: Text(labelOf(v))),
    ],
    builder: (context, controller, _) => FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) =>
          controller.isOpen ? controller.close() : controller.open(),
    ),
  );
}

/// One recording in the list.
class LibraryTile extends ConsumerWidget {
  const LibraryTile({required this.item, this.hit, super.key});

  final LibraryItem item;
  final SearchHit? hit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final profile = item.profileId == null
        ? null
        : ref.watch(profileNamesProvider).value?[item.profileId] ??
              item.profileId;
    final facts = [
      LibraryTexts.date(l10n, item.createdAt),
      LibraryTexts.duration(l10n, item.duration),
      ?profile,
    ].join(' · ');
    final status = LibraryTexts.status(l10n, item.status);
    final exported = item.exportedTo;
    return ListTile(
      key: ValueKey('library-item-${item.id}'),
      leading: Icon(
        LibraryTexts.statusIcon(item.status),
        color: item.status == LibraryStatus.failed
            ? theme.colorScheme.error
            : theme.colorScheme.primary,
      ),
      title: Text(LibraryTexts.title(l10n, item.title)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(facts),
          Text(
            exported.isEmpty
                ? status
                : l10n.libraryExportedTo(status, exported.join(', ')),
          ),
          if (hit case final h?)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: SnippetText(h.snippet),
            ),
        ],
      ),
      isThreeLine: true,
      onTap: () => RecordingStatusRoute(recordingId: item.id).go(context),
    );
  }
}

/// Search snippet with the matched terms in bold.
class SnippetText extends StatelessWidget {
  const SnippetText(this.snippet, {super.key});

  final String snippet;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodySmall;
    final spans = <TextSpan>[];
    var bold = false;
    final buffer = StringBuffer();
    void flush() {
      if (buffer.isEmpty) return;
      spans.add(
        TextSpan(
          text: buffer.toString(),
          style: bold ? const TextStyle(fontWeight: FontWeight.w600) : null,
        ),
      );
      buffer.clear();
    }

    for (final ch in snippet.split('')) {
      if (ch == kSnippetOpen || ch == kSnippetClose) {
        flush();
        bold = ch == kSnippetOpen;
      } else {
        buffer.write(ch);
      }
    }
    flush();
    return Text.rich(
      TextSpan(style: base, children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
