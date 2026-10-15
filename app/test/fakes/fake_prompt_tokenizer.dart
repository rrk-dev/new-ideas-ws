import 'package:vaultvoice/features/profiles/domain/prompt_builder.dart';

/// Deterministic [PromptTokenizer] for tests: ChatML template; one token per
/// word, per punctuation character and per ChatML control marker.
class FakePromptTokenizer implements PromptTokenizer {
  FakePromptTokenizer({this.supportsTemplate = true});

  final bool supportsTemplate;
  int countCalls = 0;

  static final _token = RegExp(r'<\|[a-z_]+\|>|\w+|[^\w\s]');

  @override
  int countTokens(String text) {
    countCalls++;
    return _token.allMatches(text).length;
  }

  @override
  String applyChatTemplate(List<ChatMessage> messages) {
    if (!supportsTemplate) throw StateError('unsupported template');
    final out = StringBuffer();
    for (final (role, content) in messages) {
      out.write('<|im_start|>$role\n$content<|im_end|>\n');
    }
    return (out..write('<|im_start|>assistant\n')).toString();
  }
}
