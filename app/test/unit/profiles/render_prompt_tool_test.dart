import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/profiles/domain/prompt_builder.dart';

import '../../../tool/src/prompt_case.dart';

/// The eval CLI (`tool/render_prompt.dart`) reads cases into the same
/// [PromptInput] the app builds, so prompts match the app's (PRF-02/PRF-09).
void main() {
  test('case JSON with segments and metadata', () {
    final c = PromptCase.fromJson({
      'id': 'meeting-001',
      'metadata': {
        'date': '2026-03-02T10:00:00',
        'duration_s': 95,
        'speakers': [
          {'label': 'S1', 'name': 'Priya'},
        ],
        'markers': [
          {'t': '00:01:00', 'label': 'Budget'},
        ],
      },
      'segments': [
        {'t': '00:00:05', 'speaker': 'S1', 'text': 'Hello.'},
        {'t': '01:02:03', 'text': 'Unlabelled.'},
      ],
    });
    expect(c.id, 'meeting-001');
    expect(c.metadata.duration, const Duration(seconds: 95));
    expect(c.metadata.markers.single.at, const Duration(minutes: 1));
    expect(
      c.segments.last.start,
      const Duration(hours: 1, minutes: 2, seconds: 3),
    );
    expect(c.metadata.displayName('S1'), 'Priya');
    expect(c.segments.last.speaker, isNull);
  });

  test('case JSON with transcript lines', () {
    final segs = parseTranscriptLines(
      '[00:00:05] Priya: Let us start.\ncontinued line\n'
      '[00:00:12] Sam: Fine.\n\n[00:20] no speaker here',
    );
    expect(segs.map((s) => s.speaker), ['Priya', 'Sam', null]);
    expect(segs.first.text, 'Let us start. continued line');
    expect(segs.last.start, const Duration(seconds: 20));
    expect(segs.last.text, 'no speaker here');
  });

  test('builds the same prompt as the app builder', () {
    final profile = loadProfile('meeting', appDir: '.');
    final c = PromptCase.fromJson({
      'transcript': '[00:00:05] Priya: We ship Monday.',
    });
    const budget = PromptBudget(contextSize: 4096, maxTokens: 1024);
    final a = const PromptBuilder(ApproxTokenizer())
        .build(c.inputFor(profile), budget);
    final p = (a as SinglePassPrompt).prompt;
    expect(p.text, startsWith('<|im_start|>system\n'));
    expect(p.text, endsWith('<|im_start|>assistant\n'));
    expect(p.promptTokens, (p.text.length + 3) ~/ 4);
  });
}
