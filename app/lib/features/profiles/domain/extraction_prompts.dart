import 'dart:convert';

import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/domain/profile_schema.dart';
import 'package:vaultvoice/features/profiles/domain/prompt_builder.dart';
import 'package:vaultvoice/features/profiles/domain/schema_prompt_text.dart';

/// Creates [ExtractionPrompts] (injected via `extractionPromptsProvider`).
typedef ExtractionPromptsFactory = ExtractionPrompts Function(
  Profile profile, {
  PromptMetadata? metadata,
});

/// String-level PRF-02 prompts for callers that hand a system + user
/// message to `LlmEngine` / `StructuredExtractor` (the engine applies the
/// chat template) instead of the exact-budget [PromptBuilder.build] path:
/// the FND-11 extract step and the LLM-06 map-reduce strategy.
///
/// Same assembly as [PromptBuilder] (fixed system prompt + instructions +
/// field list; metadata, sanitized `<transcript>` block, schema reminder).
/// [systemPrompt] is identical for single pass and every map chunk, so
/// chunks share it as a KV-cache prefix (LLM-06 prefix reuse). It is meant
/// to replace LLM-06's interim `ProfilePromptSource` (method names match its
/// `ExtractionPromptSource`; `reduceUser` stays in LLM-06) and FND-11's
/// `kInterimExtractionSystemPrompt` + instructions/transcript user prompt.
final class ExtractionPrompts {
  ExtractionPrompts(this.profile, {this.metadata});

  final Profile profile;

  /// Recording metadata (date, duration, speakers, markers); null = none.
  final PromptMetadata? metadata;

  static const _builder = PromptBuilder(_TextOnly());

  /// Schema of a map chunk (`map_schema`, else `schema`).
  ObjectSchema get chunkSchema => profile.mapSchema ?? profile.schema;

  /// System message of the single pass (and of every chunk when the profile
  /// has no `map_schema`).
  late final String systemPrompt = _builder.systemMessage(
    profile,
    profile.schema,
  );

  /// System message for map chunks (differs from [systemPrompt] only when
  /// the profile declares a `map_schema`).
  late final String chunkSystemPrompt = profile.mapSchema == null
      ? systemPrompt
      : _builder.systemMessage(profile, chunkSchema);

  /// Sanitized `[hh:mm:ss] Name: text` lines of [segments] (no tags).
  String transcriptLines(List<PromptSegment> segments) =>
      _builder.transcriptLines(segments, metadata ?? _noMeta);

  /// Single-pass user message. With [withExamples] the few-shot examples are
  /// inlined as text (the chat-message form is [PromptBuilder.build]).
  String singleUser(String transcriptLines, {bool withExamples = true}) {
    final user = _builder.userMessage(
      transcript: transcriptLines,
      schema: profile.schema,
      metadata: metadata,
    );
    if (!withExamples || profile.examples.isEmpty) return user;
    String example(ProfileExample e) {
      final lines = e.transcript
          .split('\n')
          .map(sanitizeUntrusted)
          .where((l) => l.isNotEmpty)
          .join('\n');
      final json = jsonEncode(canonicalizeToSchema(e.output, profile.schema));
      return 'Example transcript:\n<example>\n$lines\n</example>\n'
          'Example JSON:\n$json';
    }

    final examples = [for (final e in profile.examples) example(e)];
    return '${examples.join('\n\n')}\n\n$user';
  }

  /// Map-chunk user message: part [index] (0-based) of [count], same
  /// fields (partial), only what this part states.
  String chunkUser(
    String transcriptLines, {
    required int index,
    required int count,
  }) => _builder.userMessage(
    transcript: transcriptLines,
    schema: chunkSchema,
    metadata: metadata,
    part: (index + 1, count),
  );

  static final _noMeta = PromptMetadata(
    recordedAt: DateTime(1970),
    duration: Duration.zero,
  );
}

/// [PromptBuilder] is only used for its text helpers here.
final class _TextOnly implements PromptTokenizer {
  const _TextOnly();

  @override
  String applyChatTemplate(List<ChatMessage> messages) =>
      throw UnsupportedError('string prompts are templated by the engine');

  @override
  int countTokens(String text) =>
      throw UnsupportedError('string prompts are not budgeted here');
}
