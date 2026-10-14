import 'dart:async';
import 'dart:convert';

import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';

/// Word-based [LlmTokenizer]: ⌈1.3 × words⌉ + 1 (BOS) tokens; the chat
/// template adds [templateTokens]. Deterministic stand-in for llama.cpp
/// counts in unit tests (the host test uses the real tokenizer).
class WordTokenizer implements LlmTokenizer {
  WordTokenizer({this.context = 4096, this.templateTokens = 12});

  int context;
  final int templateTokens;
  int countCalls = 0;

  static int count(String text) {
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    return (words * 1.3).ceil() + 1;
  }

  @override
  Future<Result<int>> countTokens(String text) async {
    countCalls++;
    return Ok(count(text));
  }

  @override
  Future<Result<int>> countPromptTokens(
    String user, {
    String? systemPrompt,
  }) async => Ok(count('${systemPrompt ?? ''} $user') + templateTokens);

  @override
  Future<Result<int>> contextWindow() async => Ok(context);
}

/// A perfect "model" for pipeline mechanics: reads the transcript block of
/// the prompt and returns, as meeting JSON, every line of the form
/// `[hh:mm:ss] Name: … ACTION <task> …` as an action item (owner = Name),
/// attendees = speakers, decisions = lines with `DECISION <text>.`.
/// Prose-reduce prompts (no grammar) get a fixed sentence.
///
/// With it, map-reduce recall equals what the chunking/reduce preserves —
/// exactly the part LLM-06 owns. Records every request; [failAt] makes call
/// n return a failure; [blockAt] hangs call n until cancelled.
class OracleLlmEngine implements LlmEngine {
  OracleLlmEngine({this.failAt = const {}, this.blockAt});

  final Map<int, Failure> failAt;
  int? blockAt;
  final List<LlmRequest> requests = [];
  final List<int> promptTokens = [];
  bool get blocked => blockAt != null && requests.length > blockAt!;

  static final _line = RegExp(
    r'^\[(\d{2}:\d{2}:\d{2})\] ([A-Za-z]+): (.*)$',
    multiLine: true,
  );
  static final _action = RegExp(r'ACTION ([^.]+)\.');
  static final _decision = RegExp(r'DECISION ([^.]+)\.');

  @override
  Future<Result<String>> generate(
    LlmRequest request, {
    CancelToken? cancel,
    void Function(String token)? onToken,
  }) async {
    final n = requests.length;
    requests.add(request);
    promptTokens.add(
      WordTokenizer.count('${request.systemPrompt ?? ''} ${request.prompt}') +
          12,
    );
    if (n == blockAt) {
      while (!(cancel?.isCancelled ?? false)) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    }
    if (cancel?.isCancelled ?? false) return const Err(CancelledFailure());
    if (failAt[n] case final f?) return Err(f);
    if (request.grammar == null) {
      const s = 'The team reviewed the plan and agreed on next steps.';
      onToken?.call(s);
      return const Ok(s);
    }
    final start = request.prompt.indexOf('<transcript>');
    final end = request.prompt.indexOf('</transcript>');
    final block = start < 0 || end < 0
        ? ''
        : request.prompt.substring(start, end);
    final attendees = <String>[];
    final items = <Map<String, Object?>>[];
    final decisions = <String>[];
    for (final m in _line.allMatches(block)) {
      final who = m[2]!;
      if (!attendees.contains(who)) attendees.add(who);
      if (_action.firstMatch(m[3]!) case final a?) {
        items.add({'task': a[1], 'owner': who, 'due': null, 't': m[1]});
      }
      if (_decision.firstMatch(m[3]!) case final d?) decisions.add(d[1]!);
    }
    final out = jsonEncode({
      'title': 'Planning sync',
      'summary': 'Part of a planning meeting.',
      'attendees': attendees.take(20).toList(),
      'decisions': decisions.take(30).toList(),
      'action_items': items.take(50).toList(),
      'open_questions': <String>[],
      'topics': <String>[],
    });
    for (final tok in out.split(',')) {
      onToken?.call(tok);
    }
    return Ok(out);
  }
}
