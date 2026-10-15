/// What the tester chose to share (REL-04). The message is never logged
/// and is never written into the diagnostics zip.
final class BetaFeedbackDraft {
  const BetaFeedbackDraft({
    required this.message,
    required this.subject,
    this.satisfactionOutOfFive,
    this.satisfactionLine,
    this.diagnosticsNote,
  });

  final String message;
  final String subject;

  /// 1–5, or null when the tester skipped the question.
  final int? satisfactionOutOfFive;

  /// Already localized. Null when they skipped the score.
  final String? satisfactionLine;

  /// Already localized. Null when diagnostics are not included.
  final String? diagnosticsNote;

  bool get hasMessage => message.trim().isNotEmpty;

  bool get satisfactionValid =>
      satisfactionOutOfFive == null ||
      (satisfactionOutOfFive! >= 1 && satisfactionOutOfFive! <= 5);

  /// Plain text handed to the OS share sheet.
  String get body {
    final buf = StringBuffer(message.trim());
    final score = satisfactionLine;
    if (score != null && score.isNotEmpty) {
      buf
        ..writeln()
        ..writeln(score);
    }
    final note = diagnosticsNote;
    if (note != null && note.isNotEmpty) {
      buf
        ..writeln()
        ..writeln(note);
    }
    return buf.toString();
  }
}
