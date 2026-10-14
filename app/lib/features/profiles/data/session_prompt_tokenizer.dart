import 'package:vaultvoice/features/extraction/domain/llm_runtime.dart';
import 'package:vaultvoice/features/profiles/domain/prompt_builder.dart';

/// [PromptTokenizer] over a loaded [LlmSession] (`vv_llm_count_tokens`,
/// `vv_llm_apply_chat_template` — LLM-04). Counting uses the same
/// tokenization as generation, so budgets are exact.
final class SessionPromptTokenizer implements PromptTokenizer {
  const SessionPromptTokenizer(this.session);

  final LlmSession session;

  @override
  int countTokens(String text) => session.countTokens(text);

  /// Throws `LlmRequestException(unsupportedTemplate)` for models without a
  /// supported chat template.
  @override
  String applyChatTemplate(List<ChatMessage> messages) =>
      session.applyChatTemplate(messages);
}
