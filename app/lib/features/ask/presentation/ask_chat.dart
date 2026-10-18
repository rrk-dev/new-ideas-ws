import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/features/app_lock/presentation/app_lock_providers.dart';
import 'package:vaultvoice/features/ask/data/ask_providers.dart';
import 'package:vaultvoice/features/ask/domain/ask_history.dart';
import 'package:vaultvoice/features/ask/domain/ask_models.dart';

part 'ask_chat.g.dart';

/// Why a question ended without an answer.
enum AskIssue { cancelled, modelMissing, deviceTooLow, memory, failed }

/// One question and what became of it. Holds user content: never log it.
@immutable
final class AskChatTurn {
  const AskChatTurn({required this.question, this.answer, this.issue});

  final String question;
  final AskAnswer? answer;
  final AskIssue? issue;

  bool get pending => answer == null && issue == null;
}

@immutable
final class AskChatState {
  const AskChatState({this.turns = const [], this.threadId, this.busy = false});

  final List<AskChatTurn> turns;

  /// The stored thread follow-up questions are appended to.
  final String? threadId;
  final bool busy;

  AskChatState copyWith({
    List<AskChatTurn>? turns,
    String? threadId,
    bool? busy,
  }) => AskChatState(
    turns: turns ?? this.turns,
    threadId: threadId ?? this.threadId,
    busy: busy ?? this.busy,
  );
}

AskIssue askIssueFor(Failure failure) => switch (failure) {
  CancelledFailure() => AskIssue.cancelled,
  ModelMissingFailure() => AskIssue.modelMissing,
  UnsupportedFeatureFailure() => AskIssue.deviceTooLow,
  OutOfMemoryFailure() => AskIssue.memory,
  _ => AskIssue.failed,
};

/// The conversation on screen: library-wide ([recordingId] null) or about
/// one recording. Locking the app cancels a running question and clears the
/// screen (SEC-03: nothing stays readable behind the lock).
@riverpod
class AskChat extends _$AskChat {
  CancelToken? _token;
  bool _disposed = false;

  @override
  AskChatState build(String? recordingId) {
    // Holds the engine (and the 3B in memory) only while a chat is open.
    ref
      ..listen(askEngineProvider, (previous, next) {})
      ..onDispose(() {
        _disposed = true;
        _token?.cancel();
      })
      ..listen(appLockProvider, (previous, next) {
        if (next.locked && !(previous?.locked ?? false)) {
          _drop();
          state = const AskChatState();
        }
      });
    return const AskChatState();
  }

  Future<void> ask(String question) async {
    final text = question.trim();
    if (text.isEmpty || state.busy) return;
    final token = _token = CancelToken();
    state = state.copyWith(
      turns: [
        ...state.turns,
        AskChatTurn(question: text),
      ],
      busy: true,
    );
    final engine = await ref.read(askEngineProvider.future);
    final result = await engine.ask(
      AskRequest(
        question: text,
        recordingId: recordingId,
        threadId: state.threadId,
      ),
      cancel: token,
    );
    if (_disposed || token != _token) return;
    final turns = [...state.turns];
    switch (result) {
      case Ok(:final value):
        turns[turns.length - 1] = AskChatTurn(question: text, answer: value);
        state = AskChatState(
          turns: turns,
          threadId: value.threadId ?? state.threadId,
        );
      case Err(:final failure):
        turns[turns.length - 1] = AskChatTurn(
          question: text,
          issue: askIssueFor(failure),
        );
        state = AskChatState(turns: turns, threadId: state.threadId);
    }
  }

  /// Stops a running question ("Stop").
  void cancel() => _token?.cancel();

  /// Cancels and forgets the running question: its result is ignored.
  void _drop() {
    _token?.cancel();
    _token = null;
  }

  void newChat() {
    _drop();
    state = const AskChatState();
  }

  /// Shows a stored chat and continues it.
  void load(AskThread thread) {
    _drop();
    state = AskChatState(
      threadId: thread.id,
      turns: [
        for (final t in thread.turns)
          AskChatTurn(
            question: t.question,
            answer: AskAnswer(
              outcome: t.found ? AskOutcome.answered : AskOutcome.notFound,
              answer: t.found ? t.answer : kAskNotFoundText,
              citations: t.citations,
            ),
          ),
      ],
    );
  }
}
