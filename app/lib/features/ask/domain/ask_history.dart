import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/ask/domain/ask_models.dart';

/// Stored chats expire after this long (PRODUCT-DECISION, human 2026-10-17).
const Duration kAskHistoryExpiry = Duration(days: 30);

class AskThread {
  const AskThread({
    required this.id,
    required this.recordingId,
    required this.updatedAt,
    required this.turns,
  });

  final String id;
  final String? recordingId;
  final DateTime updatedAt;
  final List<AskTurn> turns;
}

class AskTurn {
  const AskTurn({
    required this.id,
    required this.question,
    required this.answer,
    required this.found,
    required this.citations,
    required this.createdAt,
  });

  final String id;
  final String question;
  final String answer;
  final bool found;
  final List<Citation> citations;
  final DateTime createdAt;
}

/// Persisted Ask chats (encrypted DB). Citations are references, so a
/// deleted recording takes every turn citing it with it.
abstract interface class AskHistoryStore {
  /// Appends a turn (new thread when [threadId] is null).
  Future<Result<({String threadId, String turnId})>> saveTurn({
    required String question,
    required String answer,
    required bool found,
    required List<Citation> citations,
    String? threadId,
    String? recordingId,
  });

  Future<Result<List<AskThread>>> threads();

  Future<Result<void>> deleteThread(String threadId);

  Future<Result<void>> clearAll();

  /// Deletes threads not touched since [cutoff]; returns how many.
  Future<Result<int>> deleteOlderThan(DateTime cutoff);
}
