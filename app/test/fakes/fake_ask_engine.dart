import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/features/ask/domain/ask_models.dart';

/// Scripted [AskEngine] for UI and wiring tests.
class FakeAskEngine implements AskEngine {
  FakeAskEngine({this.answer, this.failure});

  AskAnswer? answer;
  Failure? failure;
  final List<AskRequest> requests = [];

  @override
  Future<Result<AskAnswer>> ask(
    AskRequest request, {
    CancelToken? cancel,
  }) async {
    requests.add(request);
    if (failure case final f?) return Err(f);
    return Ok(
      answer ??
          const AskAnswer(
            outcome: AskOutcome.notFound,
            answer: kAskNotFoundText,
          ),
    );
  }
}
