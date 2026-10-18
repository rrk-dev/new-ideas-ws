import 'package:vaultvoice/features/ask/domain/ask_models.dart';

final Set<String> _stop =
    'a an the of in on at to for from by with about and or but if then '
            'than so as is are was were be been being am do does did done have '
            'has had having i me my mine we our us you your he she it its his '
            'her their they them this that these those there here what which '
            'who whom whose when where why how can could would should will '
            'shall may might must say said says tell told any some all each '
            'every not no yes also just very much many long came out up down '
            'over into again record recorded recording recordings note notes'
        .split(' ')
        .toSet();

const Set<String> _dateWords = {
  'yesterday', 'today', 'tomorrow', 'last', 'next', 'this', 'week', 'weeks', //
  'month', 'months', 'day', 'days', 'ago', ..._weekdays, ..._monthNames,
};

const List<String> _weekdays = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

const List<String> _monthNames = [
  'january',
  'february',
  'march',
  'april',
  'may',
  'june',
  'july',
  'august',
  'september',
  'october',
  'november',
  'december',
];

/// The deterministic part of a question (ADR-ASK-02): content stems for the
/// FTS5 query and the date / profile / tag filters. Nothing here is asked of
/// the LLM.
final class AskQuery {
  const AskQuery({
    required this.question,
    required this.stems,
    this.range,
    this.recordingId,
    this.profileId,
    this.tags = const [],
  });

  /// Builds the query. [now] anchors relative dates ("yesterday").
  factory AskQuery.parse(AskRequest request, DateTime now) {
    var text = request.question;
    var profile = request.profileId;
    final tags = [...request.tags];
    // Explicit filter tokens: `profile:meeting`, `#budget`.
    text = text.replaceAllMapped(RegExp(r'\bprofile:([a-z0-9_\-]+)'), (m) {
      profile ??= m.group(1);
      return ' ';
    });
    text = text.replaceAllMapped(RegExp(r'#([A-Za-z0-9_\-]+)'), (m) {
      tags.add(m.group(1)!.toLowerCase());
      return ' ';
    });
    final range = request.dateRange ?? parseAskDateRange(text, now);
    return AskQuery(
      question: request.question,
      stems: askContentStems(text),
      range: range,
      recordingId: request.recordingId,
      profileId: profile,
      tags: tags,
    );
  }

  final String question;
  final List<String> stems;
  final AskDateRange? range;
  final String? recordingId;
  final String? profileId;
  final List<String> tags;

  /// "What did I record last week?": nothing to match on but the date.
  bool get dateOnly => stems.isEmpty && range != null;

  /// FTS5 MATCH expression (prefix terms joined with OR), null when there
  /// is nothing to search for.
  String? get ftsMatch =>
      stems.isEmpty ? null : stems.map((s) => '"$s"*').join(' OR ');
}

List<String> _tokens(String text) =>
    RegExp('[a-z0-9]+')
        .allMatches(text.toLowerCase().replaceAll("'s", ''))
        .map((m) => m[0]!)
        .toList();

String _stem(String t) {
  if (t.endsWith('ies') && t.length >= 6) {
    return '${t.substring(0, t.length - 3)}y';
  }
  for (final suffix in const ['ing', 'ed', 'es', 's']) {
    if (t.endsWith(suffix) && t.length - suffix.length >= 3) {
      return t.substring(0, t.length - suffix.length);
    }
  }
  return t;
}

/// Stop words, date words and one-letter tokens removed, light suffix
/// stripping, order kept, duplicates dropped.
List<String> askContentStems(String question) {
  final out = <String>[];
  for (final t in _tokens(question)) {
    if (t.length < 2 || _stop.contains(t) || _dateWords.contains(t)) continue;
    final s = _stem(t);
    if (!out.contains(s)) out.add(s);
  }
  return out;
}

/// Understands "yesterday", "last week", "this week", "last/on WEEKDAY"
/// and "in MONTH" (a month later than [now]'s means last year's).
AskDateRange? parseAskDateRange(String question, DateTime now) {
  final q = question.toLowerCase().replaceAll("'s", '');
  final today = DateTime(now.year, now.month, now.day);
  DateTime shift(DateTime d, int days) =>
      DateTime(d.year, d.month, d.day + days);
  if (q.contains('yesterday')) {
    final d = shift(today, -1);
    return AskDateRange(d, d);
  }
  final monday = shift(today, -(today.weekday - 1));
  if (q.contains('last week')) {
    return AskDateRange(shift(monday, -7), shift(monday, -1));
  }
  if (q.contains('this week')) return AskDateRange(monday, today);
  final day = RegExp('\\b(?:last|on) (${_weekdays.join('|')})\\b')
      .firstMatch(q);
  if (day != null) {
    final target = _weekdays.indexOf(day.group(1)!) + 1;
    var delta = (today.weekday - target) % 7;
    if (delta == 0) delta = 7;
    final d = shift(today, -delta);
    return AskDateRange(d, d);
  }
  final month = RegExp('\\bin (${_monthNames.join('|')})\\b').firstMatch(q);
  if (month != null) {
    final m = _monthNames.indexOf(month.group(1)!) + 1;
    final year = m > today.month ? today.year - 1 : today.year;
    return AskDateRange(DateTime(year, m), DateTime(year, m + 1, 0));
  }
  return null;
}
