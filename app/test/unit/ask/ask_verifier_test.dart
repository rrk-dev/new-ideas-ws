import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/features/ask/domain/ask_models.dart';
import 'package:vaultvoice/features/ask/domain/ask_query.dart';
import 'package:vaultvoice/features/ask/domain/ask_retriever.dart';
import 'package:vaultvoice/features/ask/domain/ask_service.dart';
import 'package:vaultvoice/features/ask/domain/ask_verifier.dart';
import 'package:vaultvoice/features/extraction/domain/model_residency.dart';

import '../../fakes/fake_schema_grammar_converter.dart';

final _at = DateTime(2026, 3, 2);

AskPassage _p(String rec, int tMs, String text) => AskPassage(
  recordingId: rec,
  tMs: tMs,
  text: text,
  kind: AskPassageKind.transcript,
  recordedAt: _at,
);

class _Retriever implements AskRetriever {
  _Retriever(this.passages);
  final List<AskPassage> passages;

  @override
  Future<Result<List<AskPassage>>> retrieve(AskQuery query) async =>
      Ok(passages);
}

/// Answers the main call first, then one scripted reply per verify call.
class _ScriptedEngine implements LlmEngine {
  _ScriptedEngine(this.replies);
  final List<Result<String>> replies;
  final List<LlmRequest> requests = [];

  @override
  Future<Result<String>> generate(
    LlmRequest request, {
    CancelToken? cancel,
    void Function(String token)? onToken,
  }) async {
    requests.add(request);
    return replies[requests.length - 1];
  }
}

String _answer(List<String> recs) => jsonEncode({
  'found': true,
  'answer': 'Beta ships on the 9th.',
  'citations': [
    for (final r in recs) {'recording_id': r, 't': '00:00:04'},
  ],
});

const Result<String> _yes = Ok('{"supported":"yes"}');
const Result<String> _no = Ok('{"supported":"no"}');

void main() {
  final passages = [
    _p('a', 3000, 'Planning notes.'),
    _p('a', 4000, 'Okay, beta ships on the 9th.'),
    _p('b', 4000, 'The beta ships on the 9th, said the old plan.'),
  ];

  AskService service(_ScriptedEngine engine, {bool verify = true}) =>
      AskService(
        retriever: _Retriever(passages),
        engine: engine,
        grammarConverter: FakeSchemaGrammarConverter(),
        residency: ModelResidency(),
        deviceSupportsAsk: () => true,
        modelInstalled: () => true,
        pipelineBusy: () => false,
        idleUnload: const Duration(hours: 1),
        verifyCitations: verify,
      );

  Future<AskAnswer> ask(AskService s) async {
    final res = await s.ask(const AskRequest(question: 'When does beta ship?'));
    return (res as Ok<AskAnswer>).value;
  }

  test('[ASK-05/AC1] a citation judged no is dropped, yes is kept', () async {
    final engine = _ScriptedEngine([
      Ok(_answer(['a', 'b'])),
      _yes,
      _no,
    ]);
    final out = await ask(service(engine));
    expect(out.outcome, AskOutcome.answered);
    expect(out.citations.map((c) => c.recordingId), ['a']);
    expect(engine.requests[1].grammar, isNotNull);
    expect(engine.requests[1].prompt, contains('>> Okay, beta ships'));
    expect(engine.requests[1].prompt, contains('Planning notes.'));
  });

  test('[ASK-05/AC1] every citation judged no refuses the answer', () async {
    final engine = _ScriptedEngine([
      Ok(_answer(['a'])),
      _no,
    ]);
    final out = await ask(service(engine));
    expect(out.outcome, AskOutcome.notFound);
    expect(out.citations, isEmpty);
  });

  test('[ASK-05/AC1] verifier errors fail open, cancel propagates', () async {
    final open = _ScriptedEngine([
      Ok(_answer(['a'])),
      const Err(OutOfMemoryFailure()),
    ]);
    expect((await ask(service(open))).citations, hasLength(1));

    final cancelled = _ScriptedEngine([
      Ok(_answer(['a'])),
      const Err(CancelledFailure()),
    ]);
    final res = await service(cancelled)
        .ask(const AskRequest(question: 'When does beta ship?'));
    expect(res, isA<Err<AskAnswer>>());
  });

  test(
    '[ASK-05/AC1] a malformed verdict keeps the citation; off skips',
    () async {
      final bad = _ScriptedEngine([
        Ok(_answer(['a'])),
        const Ok('?'),
      ]);
      expect((await ask(service(bad))).citations, hasLength(1));

      final off = _ScriptedEngine([
        Ok(_answer(['a'])),
      ]);
      await ask(service(off, verify: false));
      expect(off.requests, hasLength(1));
    },
  );

  test('verdict parsing', () {
    expect(parseAskVerdict('{"supported":"yes"}'), isTrue);
    expect(parseAskVerdict('{"supported":"no"}'), isFalse);
    expect(parseAskVerdict('nope'), isNull);
  });
}
