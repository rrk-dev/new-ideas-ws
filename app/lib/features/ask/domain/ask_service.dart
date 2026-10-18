import 'dart:async';

import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/logging/logger.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/clock.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/features/ask/domain/ask_history.dart';
import 'package:vaultvoice/features/ask/domain/ask_models.dart';
import 'package:vaultvoice/features/ask/domain/ask_prompt.dart';
import 'package:vaultvoice/features/ask/domain/ask_query.dart';
import 'package:vaultvoice/features/ask/domain/ask_retriever.dart';
import 'package:vaultvoice/features/extraction/domain/model_residency.dart';
import 'package:vaultvoice/features/profiles/domain/profile_grammar.dart';

/// Catalog id of the model Ask uses (ASK-01). The 1B is never used for Ask
/// and there is no cloud fallback (ADR-ASK-02).
const String kAskModelId = 'llama-3.2-3b-instruct-q4_k_m';

/// Context Ask runs the 3B with (ADR-ASK-02: 8192 leaves 34 MiB under the
/// High RSS budget).
const int kAskContextSize = 6144;

/// Peak RSS of the 3B (ASK-01 host measurement, MiB), used for the
/// pre-load memory gate.
const int kAskModelEstimateMiB = 3718;

/// The Ask engine (ADR-ASK-02, ASK-03): deterministic retrieval, one
/// grammar-constrained generation by the 3B, validated citations.
///
/// Gates, in order, each a content-free [Failure] and never a cloud call:
/// device tier / 3B installed → `UnsupportedFeatureFailure('ask-device')` /
/// `ModelMissingFailure`. Then retrieval (always runs). Then the model
/// runs only when no pipeline job holds STT and memory allows; otherwise the
/// answer is [AskOutcome.retrievalOnly] with the passages.
///
/// PRODUCT-DECISION (human, 2026-10-17): Ask is Free (no `FeatureGate`) and
/// is unavailable on Mid/Low devices.
final class AskService implements AskEngine {
  AskService({
    required this.retriever,
    required this.engine,
    required this.grammarConverter,
    required this.residency,
    required this.deviceSupportsAsk,
    required this.modelInstalled,
    required this.pipelineBusy,
    this.log,
    this.history,
    this.saveHistory,
    this.availableBytes,
    this.countTokens = estimateAskTokens,
    this.contextSize = kAskContextSize,
    this.clock = const SystemClock(),
    this.queueWait = const Duration(minutes: 2),
    this.queuePoll = const Duration(milliseconds: 500),
    this.idleUnload = const Duration(seconds: 90),
    this.modelEstimateBytes = kAskModelEstimateMiB * 1024 * 1024,
    this.maxTokens = 400,
  });

  final AskRetriever retriever;
  final LlmEngine engine;
  final SchemaGrammarConverter grammarConverter;
  final ModelResidency residency;
  final bool Function() deviceSupportsAsk;
  final bool Function() modelInstalled;

  /// True while a pipeline job runs (STT or LLM step): Ask queues behind it.
  final bool Function() pipelineBusy;

  /// Content-free logging only: outcome, counts and durations — never the
  /// question, answer or passage text (SEC-01/03).
  final Logger? log;
  final AskHistoryStore? history;
  final bool Function()? saveHistory;

  /// Free RAM now; with it the LLM loads only when
  /// `available >= modelEstimateBytes * 1.2` (LLM-07).
  final int Function()? availableBytes;
  final int Function(String text) countTokens;
  final int contextSize;
  final Clock clock;
  final Duration queueWait;
  final Duration queuePoll;
  final Duration idleUnload;
  final int modelEstimateBytes;
  final int maxTokens;

  CancelToken? _active;
  Timer? _idleTimer;

  /// Hook for `ModelResidency.register(ResidentModel.llm, …)`: a pipeline
  /// STT acquire or memory pressure cancels a running Ask at its next token.
  void cancelActive() => _active?.cancel();

  @override
  Future<Result<AskAnswer>> ask(
    AskRequest request, {
    CancelToken? cancel,
  }) async {
    final watch = Stopwatch()..start();
    final result = await _ask(request, cancel);
    switch (result) {
      case Ok(:final value):
        log?.info(
          'ask',
          'answered',
          fields: {
            'outcome': value.outcome,
            'passages': value.passages.length,
            'citations': value.citations.length,
            'ms': watch.elapsedMilliseconds,
          },
        );
      case Err(:final failure):
        log?.failure('ask', failure, level: LogLevel.warning);
    }
    return result;
  }

  Future<Result<AskAnswer>> _ask(
    AskRequest request,
    CancelToken? cancel,
  ) async {
    if (!deviceSupportsAsk()) {
      return const Err(UnsupportedFeatureFailure('ask-device'));
    }
    if (!modelInstalled()) return const Err(ModelMissingFailure(kAskModelId));
    if (request.question.trim().isEmpty) {
      return const Err(UnsupportedFeatureFailure('ask-empty-question'));
    }
    final token = cancel ?? CancelToken();
    final query = AskQuery.parse(request, clock.now());
    final retrieved = await retriever.retrieve(query);
    if (retrieved case Err(:final failure)) return Err(failure);
    final ranked = (retrieved as Ok<List<AskPassage>>).value;
    if (ranked.isEmpty) return await _finish(request, _notFound(const []));

    final prompt = buildAskPrompt(
      request.question,
      ranked,
      budgetTokens: askPassageBudget(contextSize),
      countTokens: countTokens,
    );
    AskAnswer retrievalOnly() => AskAnswer(
      outcome: AskOutcome.retrievalOnly,
      answer: '',
      passages: prompt.passages,
    );

    if (!await _waitForPipeline(token)) {
      return token.isCancelled
          ? const Err(CancelledFailure())
          : await _finish(request, retrievalOnly(), save: false);
    }
    final free = availableBytes?.call();
    if (free != null && free < modelEstimateBytes * 1.2) {
      return await _finish(request, retrievalOnly(), save: false);
    }
    final grammar = await grammarConverter.toGbnf(prompt.schemaJson);
    if (grammar is Err<String>) return Err(grammar.failure);

    _idleTimer?.cancel();
    _active = token;
    final String raw;
    try {
      await residency.acquire(ResidentModel.llm);
      final generated = await engine.generate(
        LlmRequest(
          prompt: prompt.user,
          systemPrompt: prompt.system,
          grammar: (grammar as Ok<String>).value,
          maxTokens: maxTokens,
          sampling: const LlmSampling(preset: LlmPreset.deterministic),
        ),
        cancel: token,
      );
      switch (generated) {
        case Ok(:final value):
          raw = value;
        case Err(failure: OutOfMemoryFailure()):
          return await _finish(request, retrievalOnly(), save: false);
        case Err(:final failure):
          return Err(failure);
      }
    } on ModelResidencyException {
      return await _finish(request, retrievalOnly(), save: false);
    } finally {
      _active = null;
      _scheduleIdleUnload();
    }
    if (token.isCancelled) return const Err(CancelledFailure());

    final raw0 = parseAskAnswer(raw, prompt.passages);
    final parsed = raw0 == null
        ? null
        : groundAskAnswer(request.question, raw0, prompt.passages);
    if (parsed == null) {
      return await _finish(request, retrievalOnly(), save: false);
    }
    final answer = parsed.found
        ? AskAnswer(
            outcome: AskOutcome.answered,
            answer: parsed.answer,
            citations: parsed.citations,
            passages: prompt.passages,
          )
        : _notFound(prompt.passages);
    return await _finish(request, answer);
  }

  AskAnswer _notFound(List<AskPassage> passages) => AskAnswer(
    outcome: AskOutcome.notFound,
    answer: kAskNotFoundText,
    passages: passages,
  );

  /// Waits (never preempting) while a pipeline job holds the models.
  Future<bool> _waitForPipeline(CancelToken token) async {
    bool busy() =>
        pipelineBusy() || residency.loaded.contains(ResidentModel.stt);
    final deadline = clock.now().add(queueWait);
    while (busy()) {
      if (token.isCancelled || !clock.now().isBefore(deadline)) return false;
      await Future<void>.delayed(queuePoll);
    }
    return !token.isCancelled;
  }

  void _scheduleIdleUnload() {
    _idleTimer?.cancel();
    _idleTimer = Timer(idleUnload, () {
      if (_active == null) residency.releaseAll().ignore();
    });
  }

  Future<Result<AskAnswer>> _finish(
    AskRequest request,
    AskAnswer answer, {
    bool save = true,
  }) async {
    final store = history;
    if (!save ||
        store == null ||
        answer.outcome == AskOutcome.retrievalOnly ||
        !(saveHistory?.call() ?? true)) {
      return Ok(answer);
    }
    final saved = await store.saveTurn(
      threadId: request.threadId,
      recordingId: request.recordingId,
      question: request.question,
      answer: answer.answer,
      found: answer.outcome == AskOutcome.answered,
      citations: answer.citations,
    );
    return switch (saved) {
      Ok(:final value) => Ok(
        AskAnswer(
          outcome: answer.outcome,
          answer: answer.answer,
          citations: answer.citations,
          passages: answer.passages,
          threadId: value.threadId,
          turnId: value.turnId,
        ),
      ),
      // A failed save must not lose the answer the user is waiting for.
      Err() => Ok(answer),
    };
  }

  void dispose() => _idleTimer?.cancel();
}
