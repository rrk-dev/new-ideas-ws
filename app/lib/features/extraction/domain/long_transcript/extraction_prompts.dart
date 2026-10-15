import 'package:flutter/foundation.dart';
import 'package:vaultvoice/features/extraction/domain/long_transcript/transcript_chunker.dart';
import 'package:vaultvoice/features/profiles/domain/extraction_prompts.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/domain/prompt_inputs.dart';

/// Where a map chunk sits in the recording (shown to the model).
@immutable
final class ChunkInfo {
  const ChunkInfo({
    required this.index,
    required this.count,
    required this.startMs,
    required this.endMs,
  });

  final int index;
  final int count;
  final int startMs;
  final int endMs;
}

/// Prompts for single-pass, map and prose-reduce calls.
///
/// [systemPrompt] is identical for every call of one extraction, so map
/// chunks share it as a KV-cache prefix (LLM-06 prefix reuse); everything
/// chunk-specific goes into the user message. [chunkSystemPrompt] differs
/// only when the profile declares a `map_schema` (PRF-02).
abstract interface class ExtractionPromptSource {
  String get systemPrompt;

  /// System message of every map chunk.
  String get chunkSystemPrompt;

  /// The transcript text of [lines] as the user messages embed it
  /// (`[hh:mm:ss] Speaker: text`, sanitized).
  String transcript(List<TranscriptLine> lines);

  /// Single pass over the whole [transcript].
  String singleUser(String transcript, {required bool withExamples});

  /// One map chunk: same fields, partial — only what this part states.
  String chunkUser(String transcript, ChunkInfo info);

  /// LLM reduce of one prose field from its per-part values.
  String reduceUser(
    String field,
    List<String> parts, {
    required int maxLength,
    String? description,
  });
}

/// Neutralizes delimiter look-alikes inside transcript text so the block
/// cannot be closed early (prompt-injection hygiene).
String escapeTranscript(String text) => text
    .replaceAll('</transcript>', '</ transcript>')
    .replaceAll('<transcript>', '< transcript>');

/// `<transcript>…</transcript>` block of [lines].
String transcriptBlock(Iterable<TranscriptLine> lines) =>
    '<transcript>\n${escapeTranscript(lines.map((l) => l.render()).join('\n'))}'
    '\n</transcript>';

/// Prompt source of a [Profile]: PRF-02's [ExtractionPrompts] (system
/// prompt, sanitized transcript lines, single-pass and per-chunk user
/// messages — integration wave 3 replaced LLM-06's interim wording); only
/// the prose-reduce prompt is LLM-06's own.
final class ProfilePromptSource implements ExtractionPromptSource {
  ProfilePromptSource(Profile profile, {PromptMetadata? metadata})
    : prompts = ExtractionPrompts(profile, metadata: metadata);

  /// Wraps prompts from `extractionPromptsProvider`.
  ProfilePromptSource.of(this.prompts);

  final ExtractionPrompts prompts;

  @override
  String get systemPrompt => prompts.systemPrompt;

  @override
  String get chunkSystemPrompt => prompts.chunkSystemPrompt;

  @override
  String transcript(List<TranscriptLine> lines) => prompts.transcriptLines([
    for (final l in lines)
      PromptSegment(
        start: Duration(milliseconds: l.startMs),
        speaker: l.speaker,
        text: l.text,
      ),
  ]);

  @override
  String singleUser(String transcript, {required bool withExamples}) =>
      prompts.singleUser(transcript, withExamples: withExamples);

  @override
  String chunkUser(String transcript, ChunkInfo info) =>
      prompts.chunkUser(transcript, index: info.index, count: info.count);

  @override
  String reduceUser(
    String field,
    List<String> parts, {
    required int maxLength,
    String? description,
  }) {
    final what = description == null ? field : '$field ($description)';
    final numbered = [
      for (final (i, p) in parts.indexed) '${i + 1}. ${escapeTranscript(p)}',
    ].join('\n');
    return 'These are the "$field" values written for consecutive parts of '
        'one recording, in order:\n<parts>\n$numbered\n</parts>\n'
        'Write one $what for the whole recording, at most $maxLength '
        'characters. Use only facts from the parts. Reply with the text only.';
  }
}
