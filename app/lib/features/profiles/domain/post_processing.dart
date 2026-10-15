/// Implementations of the profile post-processors (PRF-03/PRF-04/PRF-05):
/// the deterministic Dart steps that run on a valid extraction *after* the
/// LLM (vv-extraction-profiles: "the LLM fills JSON; Dart renders
/// Markdown"). The contract (names, required fields, derived fields) is in
/// `post_processors.dart`; this file is pure and has no I/O, no logging.
library;

import 'package:flutter/foundation.dart';
import 'package:vaultvoice/features/profiles/domain/post_processors.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/domain/profile_schema.dart';
import 'package:vaultvoice/features/profiles/domain/prompt_inputs.dart';

/// What the post-processors may look at besides the extraction JSON.
@immutable
final class PostProcessContext {
  const PostProcessContext({
    required this.recordedAt,
    this.speakerNames = const [],
    this.speakerAliases = const {},
    this.lineSpeakers = const {},
  });

  /// From the `[hh:mm:ss] Name: text` transcript lines the prompt showed
  /// the model (`PromptBuilder.transcriptLines` / `ExtractionPrompts`):
  /// the timestamps, who spoke at each one, and the speaker names.
  factory PostProcessContext.fromTranscriptLines(
    String lines, {
    required DateTime recordedAt,
    List<PromptSpeaker> speakers = const [],
  }) {
    final bySecond = <String, String?>{};
    final names = <String>{};
    for (final raw in lines.split('\n')) {
      final m = _line.firstMatch(raw.trim());
      if (m == null) continue;
      final name = m.group(2)?.trim();
      bySecond.putIfAbsent(m.group(1)!, () => name);
      if (name != null && name.isNotEmpty) names.add(name);
    }
    final aliases = <String, String>{};
    for (final s in speakers) {
      final display = s.name?.trim();
      if (display != null && display.isNotEmpty) {
        aliases[s.label] = display;
        names.add(display);
      }
    }
    return PostProcessContext(
      recordedAt: recordedAt,
      speakerNames: names.toList(),
      speakerAliases: aliases,
      lineSpeakers: bySecond,
    );
  }

  /// Local wall-clock start of the recording (reference for relative dates).
  final DateTime recordedAt;

  /// Display names of the speakers (as they appear in the transcript).
  final List<String> speakerNames;

  /// Diarization label (`S1`) → display name.
  final Map<String, String> speakerAliases;

  /// `hh:mm:ss` of every transcript line → its speaker (null = unlabelled).
  final Map<String, String?> lineSpeakers;

  Set<String> get timestamps => lineSpeakers.keys.toSet();
}

final _line = RegExp(r'^\[(\d{2}:\d{2}:\d{2})\]\s*(?:([^:\]]{1,60}):\s)?');

/// Applies [profile]'s `post_process` list, in order, to a copy of
/// [extraction] (a schema-valid result). Unknown shapes are left alone —
/// a post-processor never throws on model output.
Map<String, Object?> applyPostProcessors(
  Profile profile,
  Map<String, Object?> extraction,
  PostProcessContext context,
) {
  final out = _deepCopy(extraction)! as Map<String, Object?>;
  for (final p in profile.postProcess) {
    switch (p) {
      case PostProcessor.normalizeSerial:
        final raw = out['serial_number'];
        if (raw is String) out['serial_number'] = normalizeSerial(raw);
      case PostProcessor.mapOwnerToSpeaker:
        _visitObjects(out, (o) {
          if (o['owner'] case final String owner) {
            o['owner'] = mapOwnerToSpeaker(
              owner,
              context,
              at: o['t'] is String ? o['t']! as String : null,
            );
          }
        });
      case PostProcessor.dropUngroundedTimestamps:
        final known = context.timestamps;
        _visitObjects(out, (o) {
          if (o['t'] case final String t when !known.contains(t)) o['t'] = null;
        });
      case PostProcessor.sortByTimestamp:
        _visitLists(out, (list) {
          if (list.isEmpty ||
              !list.every((e) => e is Map && e.containsKey('t'))) {
            return;
          }
          _stableSortByT(list);
        });
      case PostProcessor.resolveRelativeDates:
        _resolveDates(out, profile.schema, context.recordedAt);
      case PostProcessor.computeWarrantyExpiry:
        out[kWarrantyExpiryField] = _expiryOf(out, context.recordedAt);
      case PostProcessor.dedupeLists:
        _visitLists(out, dedupeList);
    }
  }
  return out;
}

// ---------------------------------------------------------------- serials

const _natoish = {
  'alpha': 'A',
  'alfa': 'A',
  'bravo': 'B',
  'charlie': 'C',
  'delta': 'D',
  'echo': 'E',
  'foxtrot': 'F',
  'golf': 'G',
  'hotel': 'H',
  'india': 'I',
  'juliet': 'J',
  'juliett': 'J',
  'kilo': 'K',
  'lima': 'L',
  'mike': 'M',
  'november': 'N',
  'oscar': 'O',
  'papa': 'P',
  'quebec': 'Q',
  'romeo': 'R',
  'sierra': 'S',
  'tango': 'T',
  'uniform': 'U',
  'victor': 'V',
  'whiskey': 'W',
  'whisky': 'W',
  'xray': 'X',
  'x-ray': 'X',
  'yankee': 'Y',
  'zulu': 'Z',
};

const _digitWords = {
  'zero': '0',
  'oh': '0',
  'one': '1',
  'two': '2',
  'three': '3',
  'four': '4',
  'five': '5',
  'six': '6',
  'seven': '7',
  'eight': '8',
  'nine': '9',
};

/// Letters spoken by name ("ess", "bee"), as whisper tends to write them.
const _letterNames = {
  'ay': 'A',
  'bee': 'B',
  'be': 'B',
  'cee': 'C',
  'see': 'C',
  'dee': 'D',
  'ee': 'E',
  'ef': 'F',
  'eff': 'F',
  'gee': 'G',
  'aitch': 'H',
  'eye': 'I',
  'jay': 'J',
  'kay': 'K',
  'el': 'L',
  'ell': 'L',
  'em': 'M',
  'en': 'N',
  'pee': 'P',
  'cue': 'Q',
  'queue': 'Q',
  'ar': 'R',
  'are': 'R',
  'ess': 'S',
  'es': 'S',
  'esses': 'S',
  'tee': 'T',
  'you': 'U',
  'vee': 'V',
  'double-u': 'W',
  'ex': 'X',
  'why': 'Y',
  'zed': 'Z',
  'zee': 'Z',
};

/// `normalize_serial`: upper-case letters and digits only. Spelling aids
/// are resolved first: "S as in Sam" / "as in Sam" / "S for Sam" → S (the
/// initial of the example word wins, so an ASR-garbled letter such as
/// "Esses in Sam" still yields S), NATO words ("Kilo") → K, digit words
/// ("four") → 4, letter names ("ess") → S, "double 7" → 77. A leading
/// "serial (number) is" is dropped. Already-normalized input is unchanged.
String? normalizeSerial(String raw) {
  final s = raw.trim().replaceFirst(
    RegExp(
      r'^(?:the\s+)?(?:serial(?:\s+number)?|s/?n)\s*(?:is|:|=)?\s*',
      caseSensitive: false,
    ),
    '',
  );
  final words = s
      .split(RegExp(r'[\s,;.:/]+'))
      .where((w) => w.isNotEmpty)
      .toList();
  final out = <_SerialPiece>[];
  var repeat = 1;
  for (var i = 0; i < words.length; i++) {
    final word = words[i];
    final w = word.toLowerCase();
    final next = i + 1 < words.length ? words[i + 1] : null;
    final isExample =
        next != null && RegExp(r"^[A-Za-z][A-Za-z'-]+$").hasMatch(next);
    if ((w == 'in' || w == 'for') && isExample) {
      // Drop the "as"/"is" markers, then the one spelled letter they
      // explain ("S" / "Esses" / the last letter of a run like "AB").
      while (out.isNotEmpty && out.last.text.isEmpty) {
        out.removeLast();
      }
      if (out.isNotEmpty && out.last.letterish) {
        final last = out.removeLast();
        if (!last.spelled && last.text.length > 1) {
          out.add(_SerialPiece(last.text.substring(0, last.text.length - 1)));
        }
      }
      out.add(_SerialPiece(next[0].toUpperCase()));
      i++;
      continue;
    }
    if (w == 'as' || w == 'is' || w == 'like') {
      out.add(const _SerialPiece('', letterish: true));
      continue;
    }
    if (w == 'double' || w == 'triple') {
      repeat = w == 'double' ? 2 : 3;
      continue;
    }
    final digit = _digitWords[w];
    final letter = digit == null ? (_natoish[w] ?? _letterNames[w]) : null;
    final piece =
        digit ??
        letter ??
        word.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
    if (piece.isEmpty) continue;
    out.add(
      _SerialPiece(
        repeat > 1 ? piece[0] * repeat + piece.substring(1) : piece,
        letterish: letter != null || RegExp(r'^[A-Za-z]{1,6}$').hasMatch(word),
        spelled: letter != null,
      ),
    );
    repeat = 1;
  }
  final result = out.map((p) => p.text).join();
  return result.isEmpty ? null : result;
}

final class _SerialPiece {
  const _SerialPiece(this.text, {this.letterish = false, this.spelled = false});

  final String text;

  /// A spelled letter (or letter run) an "as in `Word`" may replace.
  final bool letterish;

  /// Came from a letter name ("ess", "Kilo"): replaced whole.
  final bool spelled;
}

// ---------------------------------------------------------------- owners

const _selfWords = {'i', 'me', 'myself', 'speaker'};

String _nameKey(String s) =>
    s.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

/// `map_owner_to_speaker`: the owner the model wrote → the speaker's
/// display name. Diarization labels (`S2`) map to their names; "I"/"me"
/// map to whoever spoke the cited line [at]; spelling variants ("Ko-fi" vs
/// "Kofi", "sam") and first names ("Sam" for "Sam Lee") map to the listed
/// speaker. Anything else (a non-speaker such as "finance") stays as is.
String? mapOwnerToSpeaker(
  String owner,
  PostProcessContext context, {
  String? at,
}) {
  final trimmed = owner.trim();
  if (trimmed.isEmpty) return null;
  if (context.speakerAliases[trimmed] case final name?) return name;
  final key = _nameKey(trimmed);
  if (_selfWords.contains(key) || _selfWords.contains(trimmed.toLowerCase())) {
    final spoke = at == null ? null : context.lineSpeakers[at];
    if (spoke != null) return context.speakerAliases[spoke] ?? spoke;
    return trimmed;
  }
  for (final name in context.speakerNames) {
    if (_nameKey(name) == key) return name;
  }
  final first = _nameKey(trimmed.split(RegExp(r'\s+')).first);
  final byFirst = [
    for (final name in context.speakerNames)
      if (_nameKey(name.split(RegExp(r'\s+')).first) == first) name,
  ];
  if (byFirst.length == 1) return byFirst.single;
  return trimmed;
}

// ---------------------------------------------------------------- dates

const Map<String, int> _weekdays = {
  'monday': DateTime.monday,
  'tuesday': DateTime.tuesday,
  'wednesday': DateTime.wednesday,
  'thursday': DateTime.thursday,
  'friday': DateTime.friday,
  'saturday': DateTime.saturday,
  'sunday': DateTime.sunday,
};

const _months = {
  'january': 1,
  'jan': 1,
  'february': 2,
  'feb': 2,
  'march': 3,
  'mar': 3,
  'april': 4,
  'apr': 4,
  'may': 5,
  'june': 6,
  'jun': 6,
  'july': 7,
  'jul': 7,
  'august': 8,
  'aug': 8,
  'september': 9,
  'sep': 9,
  'sept': 9,
  'october': 10,
  'oct': 10,
  'november': 11,
  'nov': 11,
  'december': 12,
  'dec': 12,
};

const _ordinalWords = {
  'first': 1,
  'second': 2,
  'third': 3,
  'fourth': 4,
  'fifth': 5,
  'sixth': 6,
  'seventh': 7,
  'eighth': 8,
  'ninth': 9,
  'tenth': 10,
  'eleventh': 11,
  'twelfth': 12,
  'thirteenth': 13,
  'fourteenth': 14,
  'fifteenth': 15,
  'sixteenth': 16,
  'seventeenth': 17,
  'eighteenth': 18,
  'nineteenth': 19,
  'twentieth': 20,
  'twenty-first': 21,
  'twenty-second': 22,
  'twenty-third': 23,
  'twenty-fourth': 24,
  'twenty-fifth': 25,
  'twenty-sixth': 26,
  'twenty-seventh': 27,
  'twenty-eighth': 28,
  'twenty-ninth': 29,
  'thirtieth': 30,
  'thirty-first': 31,
};

const _countWords = {
  'a': 1,
  'an': 1,
  'one': 1,
  'two': 2,
  'three': 3,
  'four': 4,
  'five': 5,
  'six': 6,
  'seven': 7,
  'eight': 8,
  'nine': 9,
  'ten': 10,
  'eleven': 11,
  'twelve': 12,
  'couple of': 2,
};

/// Which way an ambiguous date ("Friday", "May 3rd") points: purchase
/// dates are in the past, due dates in the future.
enum DateBias { past, future }

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

int _daysIn(int year, int month) => DateTime(year, month + 1, 0).day;

/// Calendar-safe month arithmetic: the day is clamped to the target month
/// (Jan 31 + 1 month = Feb 28/29; Feb 29 + 1 year = Feb 28).
DateTime addMonths(DateTime d, int months) {
  final total = d.year * 12 + (d.month - 1) + months;
  final year = total ~/ 12;
  final month = total % 12 + 1;
  final day = d.day.clamp(1, _daysIn(year, month));
  return DateTime(year, month, day);
}

/// `resolve_relative_dates` for one spoken date: absolute calendar day or
/// null when the phrase is not a single day ("next week", "Q3", "soon").
/// [reference] is the recording start (local).
DateTime? resolveSpokenDate(
  String spoken,
  DateTime reference, {
  DateBias bias = DateBias.past,
}) {
  final ref = _day(reference);
  var s = spoken.toLowerCase().trim();
  s = s.replaceAll(RegExp(r'[.,!?]+$'), '').replaceAll(',', ' ');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  s = s.replaceFirst(RegExp(r'^(on|by|until|before|due|from)\s+'), '');
  s = s.replaceFirst(RegExp(r'^the\s+'), '');
  s = s.replaceFirst(RegExp(r'\s+(at|around)\s+.*$'), '');
  if (s.isEmpty) return null;

  final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
  if (iso != null) {
    final y = int.parse(iso.group(1)!);
    final m = int.parse(iso.group(2)!);
    final d = int.parse(iso.group(3)!);
    if (m < 1 || m > 12 || d < 1 || d > _daysIn(y, m)) return null;
    return DateTime(y, m, d);
  }
  switch (s) {
    case 'today' ||
        'tonight' ||
        'this morning' ||
        'this afternoon' ||
        'this evening' ||
        'end of day' ||
        'end of today' ||
        'eod':
      return ref;
    case 'yesterday' ||
        'last night' ||
        'yesterday morning' ||
        'yesterday afternoon' ||
        'yesterday evening':
      return ref.subtract(const Duration(days: 1));
    case 'day before yesterday' || 'the day before yesterday':
      return ref.subtract(const Duration(days: 2));
    case 'tomorrow' ||
        'tomorrow morning' ||
        'tomorrow afternoon' ||
        'end of tomorrow':
      return ref.add(const Duration(days: 1));
    case 'day after tomorrow':
      return ref.add(const Duration(days: 2));
    case 'end of the month' ||
        'end of month' ||
        'the end of the month' ||
        'month end' ||
        'end of this month':
      return DateTime(ref.year, ref.month, _daysIn(ref.year, ref.month));
    case 'end of next month':
      final n = addMonths(DateTime(ref.year, ref.month), 1);
      return DateTime(n.year, n.month, _daysIn(n.year, n.month));
    case 'end of the week' || 'end of week' || 'end of this week':
      return ref.add(Duration(days: (DateTime.friday - ref.weekday) % 7));
  }

  // "next friday", "last tuesday", "this thursday", "friday",
  // "friday next week"
  final wd = RegExp(
    r'^(?:(last|this|next|coming|this coming|past)\s+)?'
    '(monday|tuesday|wednesday|thursday|friday|saturday|sunday)'
    r'(?:\s+(next week|this week|last week))?$',
  ).firstMatch(s);
  if (wd != null) {
    final target = _weekdays[wd.group(2)]!;
    final mod = wd.group(1) ?? '';
    final suffix = wd.group(3);
    final forward = (target - ref.weekday) % 7; // 0..6
    final back = (ref.weekday - target) % 7; // 0..6
    if (suffix == 'next week' || mod == 'next') {
      // "next Friday" = the Friday of next week when said early in the week
      // is a known ambiguity; we use the first occurrence after today,
      // except that a same-week day still ahead skips to the following week
      // only for the explicit "<day> next week".
      if (suffix == 'next week') {
        final monday = ref.add(Duration(days: 8 - ref.weekday));
        return monday.add(Duration(days: target - DateTime.monday));
      }
      return ref.add(Duration(days: forward == 0 ? 7 : forward));
    }
    if (suffix == 'last week') {
      final monday = ref.subtract(Duration(days: ref.weekday - 1 + 7));
      return monday.add(Duration(days: target - DateTime.monday));
    }
    if (mod == 'last' || mod == 'past') {
      return ref.subtract(Duration(days: back == 0 ? 7 : back));
    }
    if (mod == 'this' ||
        mod == 'coming' ||
        mod == 'this coming' ||
        suffix == 'this week') {
      return ref.add(Duration(days: forward));
    }
    return bias == DateBias.past
        ? ref.subtract(Duration(days: back == 0 ? 7 : back))
        : ref.add(Duration(days: forward == 0 ? 7 : forward));
  }

  // "3 days ago", "two weeks ago", "a month ago", "in 2 weeks", "in a month"
  final rel = RegExp(
    r'^(?:(in)\s+)?(\d+|a|an|one|two|three|four|five|six|seven|eight|nine|'
    r'ten|eleven|twelve|couple of)\s+(day|week|month|year)s?(?:\s+(ago|from now))?$',
  ).firstMatch(s);
  if (rel != null && (rel.group(1) != null || rel.group(4) != null)) {
    final n = int.tryParse(rel.group(2)!) ?? _countWords[rel.group(2)]!;
    final sign = rel.group(4) == 'ago' ? -1 : 1;
    return switch (rel.group(3)) {
      'day' => ref.add(Duration(days: sign * n)),
      'week' => ref.add(Duration(days: sign * 7 * n)),
      'month' => addMonths(ref, sign * n),
      _ => addMonths(ref, sign * 12 * n),
    };
  }

  // "february 10th", "feb 10 2026", "10th of february", "may third",
  // "the 3rd of may 2025", "october first".
  final dayToken =
      r'(\d{1,2})(?:st|nd|rd|th)?|'
      '(${_ordinalWords.keys.map(RegExp.escape).join('|')})';
  final monthToken = '(${_months.keys.join('|')})';
  final md = RegExp(
    '^$monthToken\\s+(?:the\\s+)?(?:$dayToken)(?:\\s+(\\d{4}))?\$',
  ).firstMatch(s);
  final dm = RegExp(
    '^(?:$dayToken)\\s+(?:of\\s+)?$monthToken(?:\\s+(\\d{4}))?\$',
  ).firstMatch(s);
  int? month;
  int? day;
  int? year;
  if (md != null) {
    month = _months[md.group(1)];
    day = int.tryParse(md.group(2) ?? '') ?? _ordinalWords[md.group(3)];
    year = int.tryParse(md.group(4) ?? '');
  } else if (dm != null) {
    day = int.tryParse(dm.group(1) ?? '') ?? _ordinalWords[dm.group(2)];
    month = _months[dm.group(3)];
    year = int.tryParse(dm.group(4) ?? '');
  }
  if (month != null && day != null) {
    DateTime? at(int y) =>
        day! <= _daysIn(y, month!) ? DateTime(y, month, day) : null;
    if (year != null) return at(year);
    final same = at(ref.year);
    if (bias == DateBias.past) {
      if (same != null && !same.isAfter(ref)) return same;
      return at(ref.year - 1);
    }
    if (same != null && !same.isBefore(ref)) return same;
    return at(ref.year + 1);
  }
  return null;
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateBias _biasFor(String field) =>
    field == 'due' ? DateBias.future : DateBias.past;

void _resolveDates(Object? node, SchemaNode schema, DateTime ref) {
  switch ((node, schema)) {
    case (final Map<String, Object?> map, final ObjectSchema obj):
      for (final entry in obj.properties.entries) {
        final value = map[entry.key];
        if (isDateField(entry.key, entry.value)) {
          final resolved = value is String
              ? resolveSpokenDate(value, ref, bias: _biasFor(entry.key))
              : null;
          map[isoSiblingName(entry.key)] = resolved == null
              ? null
              : _isoDate(resolved);
        } else {
          _resolveDates(value, entry.value, ref);
        }
      }
    case (final List<Object?> list, final ArraySchema arr):
      for (final item in list) {
        _resolveDates(item, arr.items, ref);
      }
    default:
      break;
  }
}

// ---------------------------------------------------------------- warranty

/// `compute_warranty_expiry`: purchase day + period (calendar arithmetic;
/// month/year periods clamp to the month end, so a 1-year warranty bought
/// on Feb 29 ends on Feb 28). Null when either input is missing or not a
/// single day.
DateTime? computeWarrantyExpiry(DateTime purchase, int value, String unit) {
  if (value < 0) return null;
  final p = _day(purchase);
  return switch (unit) {
    'days' || 'day' => DateTime(p.year, p.month, p.day + value),
    'weeks' || 'week' => DateTime(p.year, p.month, p.day + 7 * value),
    'months' || 'month' => addMonths(p, value),
    'years' || 'year' => addMonths(p, 12 * value),
    _ => null,
  };
}

String? _expiryOf(Map<String, Object?> out, DateTime ref) {
  final iso = out[isoSiblingName('purchase_date')];
  final purchase = switch ((iso, out['purchase_date'])) {
    (final String i, _) => DateTime.tryParse(i),
    (_, final String spoken) => resolveSpokenDate(spoken, ref),
    _ => null,
  };
  final period = out['warranty_period'];
  if (purchase == null || period is! Map) return null;
  final value = period['value'];
  final unit = period['unit'];
  if (value is! num || unit is! String) return null;
  final expiry = computeWarrantyExpiry(purchase, value.toInt(), unit);
  return expiry == null ? null : _isoDate(expiry);
}

// ---------------------------------------------------------------- lists

String _dedupeKey(Object? item) => switch (item) {
  final String s =>
    s.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), ' ').trim(),
  final Map<Object?, Object?> m => [
    for (final e in m.entries)
      if (e.key != 't') '${e.key}=${_dedupeKey(e.value)}',
  ].join('|'),
  final List<Object?> l => l.map(_dedupeKey).join(','),
  _ => '$item',
};

/// `dedupe_lists` for one list (in place): drops items whose normalized
/// content (case, punctuation, whitespace; object timestamps `t` ignored)
/// equals an earlier item's.
void dedupeList(List<Object?> list) {
  final seen = <String>{};
  list.retainWhere((item) => seen.add(_dedupeKey(item)));
}

// ---------------------------------------------------------------- helpers

Object? _deepCopy(Object? v) => switch (v) {
  final Map<String, Object?> m => {
    for (final e in m.entries) e.key: _deepCopy(e.value),
  },
  final Map<Object?, Object?> m => {
    for (final e in m.entries) '${e.key}': _deepCopy(e.value),
  },
  final List<Object?> l => [for (final e in l) _deepCopy(e)],
  _ => v,
};

void _visitObjects(Object? node, void Function(Map<String, Object?>) f) {
  if (node is Map<String, Object?>) {
    f(node);
    for (final v in node.values) {
      _visitObjects(v, f);
    }
  } else if (node is List) {
    for (final v in node) {
      _visitObjects(v, f);
    }
  }
}

void _visitLists(Object? node, void Function(List<Object?>) f) {
  if (node is Map<String, Object?>) {
    for (final v in node.values) {
      _visitLists(v, f);
    }
  } else if (node is List<Object?>) {
    f(node);
    for (final v in node) {
      _visitLists(v, f);
    }
  }
}

void _stableSortByT(List<Object?> list) {
  final indexed = [for (var i = 0; i < list.length; i++) (i, list[i])];
  int key(Object? e) {
    final t = (e! as Map)['t'];
    if (t is! String) return 1 << 30;
    final parts = t.split(':').map(int.tryParse).toList();
    if (parts.length != 3 || parts.contains(null)) return 1 << 30;
    return parts[0]! * 3600 + parts[1]! * 60 + parts[2]!;
  }

  indexed.sort((a, b) {
    final c = key(a.$2).compareTo(key(b.$2));
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  for (var i = 0; i < list.length; i++) {
    list[i] = indexed[i].$2;
  }
}
