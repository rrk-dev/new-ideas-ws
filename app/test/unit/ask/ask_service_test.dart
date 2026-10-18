import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/logging/logger.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/features/ask/domain/ask_models.dart';
import 'package:vaultvoice/features/ask/domain/ask_prompt.dart';
import 'package:vaultvoice/features/ask/domain/ask_query.dart';
import 'package:vaultvoice/features/ask/domain/ask_retriever.dart';
import 'package:vaultvoice/features/ask/domain/ask_service.dart';
import 'package:vaultvoice/features/extraction/domain/model_residency.dart';

import '../../db/db_test_utils.dart';
import '../../fakes/fake_ask_engine.dart';
import '../../fakes/fake_llm_engine.dart';
import '../../fakes/fake_schema_grammar_converter.dart';

final _at = DateTime(2026, 3, 2);

AskPassage passage(String rec, int tMs, String text) => AskPassage(
  recordingId: rec,
  tMs: tMs,
  text: text,
  kind: AskPassageKind.transcript,
  recordedAt: _at,
);

class _Retriever implements AskRetriever {
  _Retriever(this.passages);
  final List<AskPassage> passages;
  AskQuery? last;

  @override
  Future<Result<List<AskPassage>>> retrieve(AskQuery query) async {
    last = query;
    return Ok(passages);
  }
}

class _MemorySink implements LogSink {
  final List<LogRecord> records = [];
  @override
  void write(LogRecord record) => records.add(record);
  @override
  Future<void> close() async {}
}

String answerJson({
  bool found = true,
  String answer = 'Beta ships on the 9th.',
  List<Map<String, String>> citations = const [
    {'recording_id': 'meeting-1', 't': '00:00:04'},
  ],
}) => jsonEncode({'found': found, 'answer': answer, 'citations': citations});

void main() {
  final passages = [
    passage('meeting-1', 4000, 'Okay, beta ships on the 9th.'),
    passage('meeting-2', 9000, 'Launch is moved to April.'),
  ];
  late ModelResidency residency;
  late FakeSchemaGrammarConverter converter;

  AskService service(
    FakeLlmEngine engine, {
    bool supported = true,
    bool installed = true,
    bool busy = false,
    int? available,
    Logger? log,
  }) => AskService(
    retriever: _Retriever(passages),
    engine: engine,
    grammarConverter: converter,
    residency: residency,
    deviceSupportsAsk: () => supported,
    modelInstalled: () => installed,
    pipelineBusy: () => busy,
    availableBytes: available == null ? null : () => available,
    log: log,
    queueWait: const Duration(milliseconds: 60),
    queuePoll: const Duration(milliseconds: 10),
    idleUnload: const Duration(hours: 1),
  );

  setUp(() {
    residency = ModelResidency();
    converter = FakeSchemaGrammarConverter();
  });

  test('answers with validated citations', () async {
    final engine = FakeLlmEngine(tokens: [answerJson()]);
    final out = expectOk(
      await service(engine)
          .ask(const AskRequest(question: 'When is the beta?')),
    );
    expect(out.outcome, AskOutcome.answered);
    expect(out.citations.single.recordingId, 'meeting-1');
    expect(engine.requests.single.grammar, isNotNull);
    expect(engine.requests.single.prompt, contains('<passages>'));
    // The grammar only admits retrieved recordings and timestamps.
    final schema =
        jsonDecode(converter.requests.single) as Map<String, Object?>;
    expect(schema.toString(), contains('meeting-1'));
    expect(schema.toString(), isNot(contains('meeting-3')));
  });

  test('[ASK-03/AC2] a citation to a non-retrieved or non-existent passage '
      'is never returned', () async {
    final engine = FakeLlmEngine(
      tokens: [
        answerJson(
          citations: [
            {'recording_id': 'meeting-1', 't': '00:00:04'},
            {'recording_id': 'ghost', 't': '00:00:04'},
            {'recording_id': 'meeting-1', 't': '00:09:59'},
            {'recording_id': 'meeting-2', 't': '00:00:04'},
          ],
        ),
      ],
    );
    final out = expectOk(
      await service(engine)
          .ask(const AskRequest(question: 'When is the beta?')),
    );
    expect(out.citations, [
      const Citation(recordingId: 'meeting-1', tMs: 4000),
    ]);
    expect(
      out.citations.every(
        (c) => passages.any(
          (p) => p.recordingId == c.recordingId && p.tMs == c.tMs,
        ),
      ),
      isTrue,
    );
  });

  test(
    '[ASK-03/AC2] found with only invalid citations is "not found"',
    () async {
      final engine = FakeLlmEngine(
        tokens: [
          answerJson(
            citations: [
              {'recording_id': 'ghost', 't': '00:00:01'},
            ],
          ),
        ],
      );
      final out = expectOk(
        await service(engine)
            .ask(const AskRequest(question: 'When is the beta?')),
      );
      expect(out.outcome, AskOutcome.notFound);
      expect(out.answer, kAskNotFoundText);
      expect(out.citations, isEmpty);
    },
  );

  test('found=false and unparseable output never invent an answer', () async {
    final no = expectOk(
      await service(
        FakeLlmEngine(
          tokens: [answerJson(found: false, answer: '', citations: [])],
        ),
      ).ask(const AskRequest(question: 'What is the capital of France?')),
    );
    expect(no.outcome, AskOutcome.notFound);
    final bad = expectOk(
      await service(FakeLlmEngine(tokens: ['not json']))
          .ask(const AskRequest(question: 'When is the beta?')),
    );
    expect(bad.outcome, AskOutcome.retrievalOnly);
    expect(bad.passages, isNotEmpty);
  });

  test(
    '[ASK-03/AC3] with STT resident Ask never loads the LLM alongside it',
    () async {
      var sttUnloaded = false;
      residency
        ..register(ResidentModel.stt, () => sttUnloaded = true)
        ..register(ResidentModel.llm, () {});
      await residency.acquire(ResidentModel.stt);
      final engine = FakeLlmEngine(tokens: [answerJson()]);

      final out = expectOk(
        await service(engine)
            .ask(const AskRequest(question: 'When is the beta?')),
      );

      expect(out.outcome, AskOutcome.retrievalOnly);
      expect(out.passages, isNotEmpty);
      expect(engine.requests, isEmpty);
      expect(sttUnloaded, isFalse, reason: 'Ask never preempts the pipeline');
      expect(residency.loaded, {ResidentModel.stt});
    },
  );

  test('[ASK-03/AC3] a busy pipeline job holds Ask back; afterwards the LLM '
      'is acquired and STT is not resident', () async {
    final engine = FakeLlmEngine(tokens: [answerJson()]);
    final busy = expectOk(
      await service(
        engine,
        busy: true,
      ).ask(const AskRequest(question: 'When is the beta?')),
    );
    expect(busy.outcome, AskOutcome.retrievalOnly);
    expect(engine.requests, isEmpty);

    residency.register(ResidentModel.stt, () {});
    final ok = expectOk(
      await service(engine)
          .ask(const AskRequest(question: 'When is the beta?')),
    );
    expect(ok.outcome, AskOutcome.answered);
    expect(residency.loaded, {ResidentModel.llm});
  });

  test('not enough free memory gives the retrieval-only result', () async {
    final engine = FakeLlmEngine(tokens: [answerJson()]);
    final out = expectOk(
      await service(
        engine,
        available: 1024 * 1024 * 1024,
      ).ask(const AskRequest(question: 'When is the beta?')),
    );
    expect(out.outcome, AskOutcome.retrievalOnly);
    expect(engine.requests, isEmpty);
  });

  test(
    '3B missing and unsupported tiers are typed failures, no engine call',
    () async {
      final engine = FakeLlmEngine(tokens: [answerJson()]);
      const q = AskRequest(question: 'When is the beta?');
      final missing = await service(engine, installed: false).ask(q);
      expect(missing.failureOrNull, isA<ModelMissingFailure>());
      expect(
        (missing.failureOrNull! as ModelMissingFailure).modelId,
        kAskModelId,
      );
      final low = await service(engine, supported: false).ask(q);
      expect(low.failureOrNull, isA<UnsupportedFeatureFailure>());
      expect(engine.requests, isEmpty);
    },
  );

  test('cancel stops Ask with CancelledFailure', () async {
    final engine = FakeLlmEngine(
      tokens: [answerJson()],
      perToken: const Duration(milliseconds: 5),
    );
    final token = CancelToken()..cancel();
    final res = await service(engine)
        .ask(const AskRequest(question: 'When is the beta?'), cancel: token);
    expect(res.failureOrNull, isA<CancelledFailure>());
  });

  test('[ASK-03/AC5] no question, answer or passage text in logs', () async {
    final sink = _MemorySink();
    final log = Logger(sinks: [sink]);
    final engine = FakeLlmEngine(tokens: [answerJson()]);
    const question = 'When is the secret beta shipping?';
    await service(engine, log: log).ask(const AskRequest(question: question));
    await service(
      FakeLlmEngine(tokens: ['not json']),
      log: log,
    ).ask(const AskRequest(question: question));
    await service(
      engine,
      installed: false,
      log: log,
    ).ask(const AskRequest(question: question));

    expect(sink.records, isNotEmpty);
    final dump = sink.records.map((r) => r.toJsonLine()).join('\n');
    for (final secret in [
      'secret beta',
      'Beta ships on the 9th',
      'beta ships on the 9th',
      'Launch is moved to April',
      'meeting-1',
    ]) {
      expect(dump, isNot(contains(secret)));
    }
  });

  test('FakeAskEngine implements the interface for UI tests', () async {
    final fake = FakeAskEngine();
    final out = expectOk(
      await fake.ask(const AskRequest(question: 'anything')),
    );
    expect(out.outcome, AskOutcome.notFound);
  });

  test('[ASK-03/AC2] grounding: a name absent from the cited passages and a '
      'citation sharing no term with the question are not trusted', () async {
    final named = expectOk(
      await service(
        FakeLlmEngine(tokens: [answerJson()]),
      ).ask(const AskRequest(question: 'What did Priya say about the beta?')),
    );
    expect(named.outcome, AskOutcome.notFound);

    final extra = expectOk(
      await service(
        FakeLlmEngine(
          tokens: [
            answerJson(
              citations: [
                {'recording_id': 'meeting-1', 't': '00:00:04'},
                {'recording_id': 'meeting-2', 't': '00:00:09'},
              ],
            ),
          ],
        ),
      ).ask(const AskRequest(question: 'When is the beta?')),
    );
    expect(extra.outcome, AskOutcome.answered);
    expect(extra.citations.map((c) => c.recordingId), ['meeting-1']);
  });

  group('prompt budget', () {
    test('keeps the highest-ranked passages within the token budget', () {
      final many = [
        for (var i = 0; i < 40; i++) passage('r$i', 1000 * i, 'word ' * 60),
      ];
      final prompt = buildAskPrompt('q?', many, budgetTokens: 500);
      expect(prompt.passages.length, lessThan(40));
      expect(prompt.passages.first.recordingId, 'r0');
      expect(askPassageBudget(6144), kAskSendCapTokens);
      expect(askPassageBudget(3000), 3000 - 512 - 578);
    });
  });
}
