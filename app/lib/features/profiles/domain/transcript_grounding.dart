/// Grounding of extraction output in the transcript (EXQ guard against small
/// models inventing content or copying prompt text): pure Dart, no I/O, and
/// no logging — callers log [GroundingStats] counts only, never item text.
library;

/// Counts of what the post-processing guards removed or replaced. Safe to
/// log at INFO (numbers only).
final class GroundingStats {
  /// Repeated list items dropped by `dedupe_lists`.
  int duplicatesDropped = 0;

  /// List items (strings or objects) with no support in the transcript.
  int itemsDropped = 0;

  /// `owner` values naming nobody in the transcript, set to null.
  int ownersCleared = 0;

  /// `title` / `summary` / `context` not derived from the transcript.
  int proseReplaced = 0;

  bool get isEmpty =>
      duplicatesDropped == 0 &&
      itemsDropped == 0 &&
      ownersCleared == 0 &&
      proseReplaced == 0;

  Map<String, int> toJson() => {
    'duplicates': duplicatesDropped,
    'ungrounded_items': itemsDropped,
    'owners_cleared': ownersCleared,
    'prose_replaced': proseReplaced,
  };
}

/// Share of an item's key terms that must occur in the transcript.
const double kGroundedShare = 0.5;

/// Prose (summary, context) paraphrases more than list items do.
const double kProseGroundedShare = 0.4;

/// Keys whose values are structure, not claims: never grounded as text.
bool _isStructuralKey(String key) =>
    key == 'owner' || key == 'due' || key == 't' || key.endsWith('_iso');

/// Key terms of a text: lower-case letters/digits runs of ≥ 3 characters
/// (digits-bearing words of any length) minus stop words, reduced to a
/// 5-character stem so "tenant"/"tenancy"/"tenants" and
/// "change"/"changes" agree.
Iterable<String> keyTerms(String text) sync* {
  for (final m in _word.allMatches(text.toLowerCase())) {
    final w = m.group(0)!;
    final hasDigit = _digit.hasMatch(w);
    if (!hasDigit && (w.length < 3 || _stopWords.contains(w))) continue;
    yield stemOf(w);
  }
}

/// 5-character stem used by [keyTerms].
String stemOf(String word) => word.length > 5 ? word.substring(0, 5) : word;

/// What the transcript (and the speakers' names) support.
final class TranscriptGrounding {
  TranscriptGrounding(String transcript, {Iterable<String> names = const []})
    : transcript = transcript.trim(),
      _stems = {...keyTerms(transcript), for (final n in names) ...keyTerms(n)};

  /// Plain transcript text (no timestamps), in order.
  final String transcript;
  final Set<String> _stems;

  /// Nothing to ground against (no transcript text): guards stay off.
  bool get isEmpty => _stems.isEmpty;

  /// Fraction of [text]'s key terms found in the transcript; 1 when the text
  /// has no key terms.
  double share(String text) {
    final terms = keyTerms(text).toList();
    if (terms.isEmpty) return 1;
    return terms.where(_stems.contains).length / terms.length;
  }

  bool supports(String text, {double minShare = kGroundedShare}) =>
      share(text) >= minShare;

  /// Text claimed by [item]: a string, or every string leaf of an object
  /// except structural fields (`owner`, `due`, `t`, `*_iso`).
  String claimText(Object? item) => switch (item) {
    final String s => s,
    final Map<Object?, Object?> m => [
      for (final e in m.entries)
        if (!_isStructuralKey('${e.key}')) claimText(e.value),
    ].where((s) => s.isNotEmpty).join(' '),
    final List<Object?> l =>
      l.map(claimText).where((s) => s.isNotEmpty).join(' '),
    _ => '',
  };

  /// First [maxSentences] sentences of the transcript, clipped to
  /// [maxLength] at a word boundary (the derived fallback for a title or
  /// summary the model did not take from the transcript).
  String leadingText({int maxSentences = 1, int? maxLength}) {
    final sentences = transcript
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .take(maxSentences)
        .toList();
    var out = sentences.join(' ');
    if (maxLength != null && out.length > maxLength) {
      out = out.substring(0, maxLength);
      final cut = out.lastIndexOf(' ');
      if (cut > maxLength ~/ 2) out = out.substring(0, cut);
    }
    return out.replaceAll(RegExp(r'[\s,;:.\-]+$'), '').trim();
  }
}

final _word = RegExp(r'[\p{L}\p{N}]+', unicode: true);
final _digit = RegExp(r'\p{N}', unicode: true);

const _stopWords = {
  'the',
  'and',
  'for',
  'are',
  'but',
  'not',
  'you',
  'all',
  'can',
  'had',
  'her',
  'was',
  'one',
  'our',
  'out',
  'has',
  'have',
  'that',
  'this',
  'with',
  'from',
  'they',
  'will',
  'would',
  'there',
  'their',
  'what',
  'when',
  'where',
  'which',
  'who',
  'whom',
  'how',
  'why',
  'been',
  'were',
  'than',
  'then',
  'them',
  'these',
  'those',
  'into',
  'about',
  'also',
  'just',
  'some',
  'such',
  'only',
  'does',
  'did',
  'its',
  'any',
  'too',
  'very',
  'should',
  'could',
  'more',
  'most',
  'other',
  'over',
  'under',
  'each',
  'both',
  'being',
  'need',
  'needs',
  'use',
  'used',
  'using',
  'make',
  'made',
  'get',
  'gets',
  'let',
  'lets',
  'new',
  'again',
  'still',
  'before',
  'after',
  'while',
  'between',
  'because',
  'whether',
  'every',
  'same',
};
