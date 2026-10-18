// Runs the app's automatic profile classification (`ProfileClassifier`, PRF-06)
// over the classification eval set (`tools/bench/eval/classify/cases.json`,
// TPL-04) and writes one JSON line per case.
//
// Usage (from app/):
//   fvm dart run tool/classify_eval.dart --cases ../tools/bench/eval/classify/cases.json
//       --out results.jsonl [--no-llm]
//       [--lib ../native/build/host/libvv_native.dylib --model m.gguf]
//       [--n-ctx 4096] [--threads N] [--min-confidence 0.6]
//
// Without --model (or with --no-llm) only the keyword stage runs; cases it
// does not decide get `"method": "none"`. With a model the same call the app
// makes runs: keyword pre-filter, then the grammar-constrained LLM answer on
// the first 5000 characters. The 1-pass classification prompt contains only
// profile ids/descriptions and the transcript start; nothing leaves the
// machine. Transcripts are synthetic.
import 'dart:convert';
import 'dart:io';

import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/features/profiles/domain/builtin_profiles.dart';
import 'package:vaultvoice/features/profiles/domain/profile_classifier.dart';
import 'package:vaultvoice/features/profiles/domain/prompt_builder.dart';
import 'package:vv_native/vv_native.dart';

Future<void> main(List<String> argv) async {
  final Map<String, String> args;
  try {
    args = _parse(argv);
  } on FormatException catch (e) {
    stderr
      ..writeln('classify_eval: ${e.message}')
      ..writeln(_usage);
    exitCode = 64;
    return;
  }
  final appDir = File.fromUri(Platform.script).parent.parent.path;
  final builtins = BuiltinProfiles.parse({
    for (final a in kBuiltinProfileAssets)
      a: File('$appDir/$a').readAsStringSync(),
  });
  final profiles = builtins.all;
  final cases =
      ((jsonDecode(File(args['cases']!).readAsStringSync())
                  as Map<String, Object?>)['cases']!
              as List<Object?>)
          .cast<Map<String, Object?>>();

  final model = args.containsKey('no-llm') ? null : args['model'];
  _VvEngine? service;
  var loadMs = 0;
  if (model != null) {
    final native = VvNative.open(hostPath: args['lib'] ?? _defaultLib(appDir));
    final watch = Stopwatch()..start();
    final llm = await native.loadLlm(
      model,
      LlmBackendParams(
        useGpu: false,
        nCtx: int.parse(args['n-ctx'] ?? '4096'),
        nThreads: int.parse(args['threads'] ?? '0'),
      ),
    );
    loadMs = watch.elapsedMilliseconds;
    service = _VvEngine(llm);
  }
  final engine = service ?? const _NoLlm();
  final classifier = ProfileClassifier(
    llm: engine,
    minConfidence: double.parse(args['min-confidence'] ?? '0.6'),
  );

  final out = args['out'] == null ? stdout : File(args['out']!).openWrite();
  try {
    for (final c in cases) {
      final text = c['transcript']! as String;
      final watch = Stopwatch()..start();
      final result = await classifier.classify(
        profiles,
        text,
        allowLlm: service != null,
      );
      watch.stop();
      final hits = classifier.keywordHits(profiles, classifier.sample(text));
      final record = <String, Object?>{
        'id': c['id'],
        'keyword_hits': hits,
        'latency_ms': watch.elapsedMilliseconds,
        'load_ms': loadMs,
      };
      switch (result) {
        case Ok(:final value):
          record.addAll({
            'picked': value.profileId,
            'confidence': value.confidence,
            'method': value.method.name,
            'needs_choice': value.needsChoice,
          });
        case Err(:final failure):
          record.addAll({
            'picked': null,
            'confidence': 0,
            'method': 'none',
            'needs_choice': true,
            'error': failure.message,
          });
      }
      out.writeln(jsonEncode(record));
    }
  } finally {
    if (!identical(out, stdout)) await out.close();
  }
}

/// The classification call of `FfiLlmRuntime`: chat template, greedy,
/// grammar, at most 16 tokens.
final class _VvEngine implements LlmEngine {
  const _VvEngine(this._llm);

  final VvLlm _llm;

  @override
  Future<Result<String>> generate(
    LlmRequest request, {
    CancelToken? cancel,
    void Function(String token)? onToken,
  }) async {
    final prompt = _llm.applyChatTemplate(<ChatMessage>[
      if (request.systemPrompt != null) ('system', request.systemPrompt!),
      ('user', request.prompt),
    ]);
    final gen = _llm.generate(
      prompt,
      LlmGenParams(
        nPredict: request.maxTokens < 16 ? request.maxTokens : 16,
        temperature: 0,
        minP: 0,
        grammar: request.grammar,
      ),
    );
    final text = StringBuffer();
    await gen.text.forEach(text.write);
    await gen.done;
    return Ok(text.toString());
  }
}

/// No model: keyword-only runs never reach the LLM.
final class _NoLlm implements LlmEngine {
  const _NoLlm();

  @override
  Future<Result<String>> generate(
    LlmRequest request, {
    CancelToken? cancel,
    void Function(String token)? onToken,
  }) async => const Err(UnexpectedFailure('no model'));
}

String _defaultLib(String appDir) =>
    '$appDir/../native/build/host/'
    'libvv_native.${Platform.isMacOS ? 'dylib' : 'so'}';

const _flags = {'no-llm'};
const _options = {
  'cases',
  'out',
  'lib',
  'model',
  'n-ctx',
  'threads',
  'min-confidence',
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
  if (!out.containsKey('cases')) throw const FormatException('--cases');
  return out;
}

const _usage = '''
classify_eval.dart --cases <cases.json> [--out <results.jsonl>] [--no-llm]
  [--lib <libvv_native>] [--model <model.gguf>] [--n-ctx 4096] [--min-confidence 0.6]''';
