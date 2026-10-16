// Renders extraction prompts exactly like the app (PRF-02) — and, with
// `--generate`, runs them through the host llama.cpp build (`vv_native`) —
// for the extraction eval harness (PRF-09, tools/bench/eval/run.py).
//
// Usage (from app/):
//   fvm dart run tool/render_prompt.dart --profile meeting --case case.json
//       [--lib ../native/build/host/libvv_native.dylib --model m.gguf]
//       [--n-ctx 4096] [--max-tokens 1024] [--format text|json]
//   fvm dart run tool/render_prompt.dart --profile meeting
//       --cases cases.jsonl --out results.jsonl --lib … --model … --generate
//
// Without --model the chat template is ChatML and token counts are an
// approximation (`"exact": false`); with a model they are exact.
// --profile is a built-in id (assets/profiles/<id>.yaml) or a YAML path.
// Output never leaves the machine; transcripts are synthetic/consented only.
import 'dart:convert';
import 'dart:io';

import 'package:vaultvoice/features/extraction/domain/output_schema_validator.dart';
import 'package:vaultvoice/features/profiles/domain/extraction_prompts.dart';
import 'package:vaultvoice/features/profiles/domain/post_processing.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/domain/prompt_builder.dart';
import 'package:vv_native/vv_native.dart';

import 'src/prompt_case.dart';

Future<void> main(List<String> argv) async {
  final Map<String, String> args;
  try {
    args = _parse(argv);
  } on FormatException catch (e) {
    stderr
      ..writeln('render_prompt: ${e.message}')
      ..writeln(_usage);
    exitCode = 64;
    return;
  }
  if (args.containsKey('help')) {
    stdout.writeln(_usage);
    return;
  }
  final appDir = File.fromUri(Platform.script).parent.parent.path;
  final profile = loadProfile(args['profile']!, appDir: appDir);
  final budget = PromptBudget(
    contextSize: int.parse(args['n-ctx'] ?? '4096'),
    maxTokens: int.parse(args['max-tokens'] ?? '1024'),
  );

  VvNative? native;
  VvLlm? llm;
  final model = args['model'];
  if (model != null) {
    native = VvNative.open(hostPath: args['lib'] ?? _defaultLib(appDir));
    llm = await native.loadLlm(
      model,
      LlmBackendParams(
        useGpu: args.containsKey('gpu'),
        nCtx: budget.contextSize,
        nThreads: int.parse(args['threads'] ?? '0'),
      ),
    );
  }
  final tokenizer = llm == null
      ? const ApproxTokenizer()
      : _VvTokenizer(llm) as PromptTokenizer;
  final builder = PromptBuilder(tokenizer);
  final appPath = args.containsKey('app-path');
  final sampler = _SamplerOverrides(
    temperature: double.tryParse(args['temp'] ?? ''),
    topK: int.tryParse(args['top-k'] ?? ''),
    minP: double.tryParse(args['min-p'] ?? ''),
    repeatPenalty: double.tryParse(args['repeat-penalty'] ?? ''),
    repeatLastN: int.tryParse(args['repeat-last-n'] ?? ''),
  );

  try {
    if (args['cases'] case final casesPath?) {
      final generate = args.containsKey('generate');
      if (generate && llm == null) {
        throw const FormatException('--generate needs --model');
      }
      final grammar = generate
          ? native!.jsonSchemaToGbnf(jsonEncode(profile.schema.toJson()))
          : null;
      final out = args['out'] == null ? stdout : File(args['out']!).openWrite();
      for (final line in File(casesPath).readAsLinesSync()) {
        if (line.trim().isEmpty) continue;
        final c = PromptCase.fromJson(jsonDecode(line) as Map<String, Object?>);
        final record = _render(
          profile,
          c,
          builder,
          budget,
          llm != null,
          appPath: appPath,
        );
        if (generate && record['prompt'] is String) {
          record.addAll(
            await _generate(
              llm!,
              record['prompt']! as String,
              grammar!,
              profile,
              budget,
              PostProcessContext.fromTranscriptLines(
                builder.transcriptLines(c.segments, c.metadata),
                recordedAt: c.metadata.recordedAt,
                speakers: c.metadata.speakers,
              ),
              sampler,
            ),
          );
        }
        record
          ..remove('prompt')
          ..remove('messages');
        out.writeln(jsonEncode(record));
      }
      if (!identical(out, stdout)) await out.close();
      return;
    }
    final casePath = args['case'];
    if (casePath == null) throw const FormatException('--case or --cases');
    final c = PromptCase.fromJson(
      jsonDecode(File(casePath).readAsStringSync()) as Map<String, Object?>,
    );
    final record = _render(
      profile,
      c,
      builder,
      budget,
      llm != null,
      appPath: appPath,
    );
    if (args['format'] == 'json') {
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(record));
    } else {
      stdout.write(record['prompt'] ?? '(${record['plan']})\n');
    }
  } finally {
    llm?.destroy();
  }
}

Map<String, Object?> _render(
  Profile profile,
  PromptCase c,
  PromptBuilder builder,
  PromptBudget budget,
  bool exact, {
  bool appPath = false,
}) {
  if (appPath) return _renderAppPath(profile, c, builder, budget, exact);
  final base = <String, Object?>{
    'id': c.id,
    'profile_id': profile.id,
    'profile_version': profile.version,
    'exact': exact,
    'n_ctx': budget.contextSize,
    'max_tokens': budget.maxTokens,
  };
  switch (builder.build(c.inputFor(profile), budget)) {
    case SinglePassPrompt(:final prompt):
      return base..addAll({
        'plan': 'single',
        'prompt_tokens': prompt.promptTokens,
        'examples_used': prompt.examplesUsed,
        'examples_dropped': prompt.examplesDropped,
        'messages': [
          for (final (role, content) in prompt.messages)
            {'role': role, 'content': content},
        ],
        'prompt': prompt.text,
      });
    case MapReducePrompt(:final transcriptTokens, :final chunkTranscriptBudget):
      return base..addAll({
        'plan': 'map_reduce',
        'transcript_tokens': transcriptTokens,
        'chunk_transcript_budget': chunkTranscriptBudget,
      });
    case PromptTooLarge(:final overheadTokens):
      return base
        ..addAll({'plan': 'too_large', 'overhead_tokens': overheadTokens});
  }
}

/// The prompt the app's extract step sends (`ExtractionPrompts`: system +
/// one user message, few-shot examples inlined) — not the chat-pair form of
/// [PromptBuilder.build].
Map<String, Object?> _renderAppPath(
  Profile profile,
  PromptCase c,
  PromptBuilder builder,
  PromptBudget budget,
  bool exact,
) {
  final p = ExtractionPrompts(profile, metadata: c.metadata);
  final messages = <ChatMessage>[
    ('system', p.systemPrompt),
    ('user', p.singleUser(p.transcriptLines(c.segments))),
  ];
  final text = builder.tokenizer.applyChatTemplate(messages);
  return {
    'id': c.id,
    'profile_id': profile.id,
    'profile_version': profile.version,
    'exact': exact,
    'n_ctx': budget.contextSize,
    'max_tokens': budget.maxTokens,
    'plan': 'single',
    'prompt_tokens': builder.tokenizer.countTokens(text),
    'messages': [
      for (final (role, content) in messages)
        {'role': role, 'content': content},
    ],
    'prompt': text,
  };
}

Future<Map<String, Object?>> _generate(
  VvLlm llm,
  String prompt,
  String grammar,
  Profile profile,
  PromptBudget budget,
  PostProcessContext postContext,
  _SamplerOverrides sampler,
) async {
  final watch = Stopwatch()..start();
  final base = LlmGenParams.extraction(
    grammar: grammar,
    nPredict: budget.maxTokens,
  );
  final gen = llm.generate(
    prompt,
    LlmGenParams(
      nPredict: base.nPredict,
      seed: base.seed,
      temperature: sampler.temperature ?? base.temperature,
      topK: sampler.topK ?? base.topK,
      topP: base.topP,
      minP: sampler.minP ?? base.minP,
      repeatPenalty: sampler.repeatPenalty ?? base.repeatPenalty,
      repeatLastN: sampler.repeatLastN ?? base.repeatLastN,
      grammar: grammar,
      tokenBatch: base.tokenBatch,
    ),
  );
  final text = StringBuffer();
  await gen.text.forEach(text.write);
  final r = await gen.done;
  watch.stop();
  final output = text.toString();
  Object? decoded;
  List<String> issues;
  try {
    decoded = jsonDecode(output);
    issues = const OutputSchemaValidator().validate(
      decoded,
      profile.schema.toJson(),
    );
  } on FormatException {
    issues = [r'$: not valid JSON'];
  }
  return {
    'status': r.status,
    'output': output,
    // What the app stores and renders: the profile's Dart post-processors
    // applied to the valid model output (PRF-03/04/05).
    if (issues.isEmpty && decoded is Map<String, Object?>)
      'post_processed': applyPostProcessors(profile, decoded, postContext),
    'valid': issues.isEmpty,
    'issues': issues,
    'n_prompt': r.nPrompt,
    'n_gen': r.nGen,
    'prefill_ms': r.prefillMs,
    'decode_ms': r.decodeMs,
    'latency_ms': watch.elapsedMilliseconds,
  };
}

/// Sampler experiments (`--temp`, `--repeat-penalty`, …); unset = the
/// `LlmGenParams.extraction` preset the app uses.
final class _SamplerOverrides {
  const _SamplerOverrides({
    this.temperature,
    this.topK,
    this.minP,
    this.repeatPenalty,
    this.repeatLastN,
  });

  final double? temperature;
  final int? topK;
  final double? minP;
  final double? repeatPenalty;
  final int? repeatLastN;
}

final class _VvTokenizer implements PromptTokenizer {
  const _VvTokenizer(this._llm);

  final VvLlm _llm;

  @override
  int countTokens(String text) => _llm.countTokens(text);

  @override
  String applyChatTemplate(List<ChatMessage> messages) =>
      _llm.applyChatTemplate(messages);
}

String _defaultLib(String appDir) =>
    '$appDir/../native/build/host/'
    'libvv_native.${Platform.isMacOS ? 'dylib' : 'so'}';

const _flags = {'generate', 'gpu', 'help', 'app-path'};
const _options = {
  'profile',
  'case',
  'cases',
  'out',
  'lib',
  'model',
  'n-ctx',
  'max-tokens',
  'threads',
  'format',
  'temp',
  'top-k',
  'min-p',
  'repeat-penalty',
  'repeat-last-n',
};

Map<String, String> _parse(List<String> argv) {
  final out = <String, String>{};
  for (var i = 0; i < argv.length; i++) {
    final a = argv[i];
    if (!a.startsWith('--')) throw FormatException('unexpected "$a"');
    final name = a.substring(2);
    if (_flags.contains(name)) {
      out[name] = '';
    } else if (_options.contains(name) && i + 1 < argv.length) {
      out[name] = argv[++i];
    } else {
      throw FormatException('unknown or incomplete option "$a"');
    }
  }
  if (!out.containsKey('help') && !out.containsKey('profile')) {
    throw const FormatException('--profile is required');
  }
  return out;
}

const _usage = '''
render_prompt.dart --profile <id|file.yaml> (--case <case.json> | --cases <cases.jsonl> [--out <results.jsonl>])
  [--lib <libvv_native>] [--model <model.gguf>] [--n-ctx 4096] [--max-tokens 1024]
  [--threads N] [--gpu] [--generate] [--app-path] [--format text|json]
  [--temp T] [--top-k K] [--min-p P] [--repeat-penalty R] [--repeat-last-n N]''';
