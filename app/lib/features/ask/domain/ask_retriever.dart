import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/ask/domain/ask_models.dart';
import 'package:vaultvoice/features/ask/domain/ask_query.dart';

/// Finds the passages a question may be answered from (ADR-ASK-02 option A:
/// FTS5 BM25). Passages come back in relevance order, neighbours of the best
/// hits right after them.
abstract interface class AskRetriever {
  Future<Result<List<AskPassage>>> retrieve(AskQuery query);
}
