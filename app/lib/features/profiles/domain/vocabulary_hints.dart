/// STT vocabulary hints of a profile (PRF-05): the profile's own
/// `stt.vocabulary` plus the user's additions, as whisper's initial prompt.
///
/// Terms are user/profile text: they are sanitized here and never logged.
abstract final class VocabularyHints {
  /// Longest accepted term.
  static const int maxTermLength = 40;

  /// Most terms kept (whisper's prompt window is 224 tokens).
  static const int maxTerms = 60;

  /// Splits user input on commas, semicolons and line breaks.
  static List<String> parse(String input) =>
      sanitize(input.split(RegExp(r'[,;\n]')));

  /// Trims, collapses whitespace, drops control characters, empty,
  /// over-long and case-insensitive duplicate terms (first spelling wins).
  static List<String> sanitize(Iterable<String> terms) {
    final seen = <String>{};
    final out = <String>[];
    for (final raw in terms) {
      final t = raw
          .replaceAll(RegExp(r'[\u0000-\u001F\u007F\u202A-\u202E]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (t.isEmpty || t.length > maxTermLength) continue;
      if (seen.add(t.toLowerCase())) out.add(t);
      if (out.length == maxTerms) break;
    }
    return out;
  }

  /// Profile terms first, then the user's.
  static List<String> merge(
    List<String> profileTerms,
    List<String> userTerms,
  ) => sanitize([...profileTerms, ...userTerms]);

  /// Whisper prompt budget (`ProfileStt.vocabulary`: ≤ 200 characters).
  static const int maxPromptChars = 200;

  /// The text for `SttOptions.initialPrompt` (terms that do not fit in
  /// [maxPromptChars] are dropped), or null without terms.
  static String? prompt(List<String> terms) {
    final b = StringBuffer();
    for (final t in sanitize(terms)) {
      final next = b.isEmpty ? t : '$b, $t';
      if (next.length + 1 > maxPromptChars) break;
      b
        ..clear()
        ..write(next);
    }
    return b.isEmpty ? null : '$b.';
  }
}
