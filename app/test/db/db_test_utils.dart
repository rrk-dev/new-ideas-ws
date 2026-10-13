import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/errors/result.dart';

/// A fresh in-memory database closed at test teardown.
VaultVoiceDatabase memoryDb() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final db = VaultVoiceDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

final t0 = DateTime.utc(2026, 10, 12, 9);

/// Inserts a minimal recording row.
Future<void> seedRecording(
  VaultVoiceDatabase db,
  String id, {
  DateTime? createdAt,
  RecordingSource source = RecordingSource.mic,
  RecordingStatus status = RecordingStatus.recorded,
}) async {
  expectOk(
    await db.recordingsRepository.create(
      RecordingsCompanion.insert(
        id: id,
        createdAt: createdAt ?? t0,
        status: status,
        source: source,
      ),
    ),
  );
}

/// Asserts [result] is [Ok] and returns its value.
T expectOk<T>(Result<T> result) {
  expect(
    result.isOk,
    isTrue,
    reason: 'expected Ok, got ${result.failureOrNull}',
  );
  return result.valueOrNull as T;
}

/// Records every event of a stream; [settled] waits for pending queries.
class StreamProbe<T> {
  StreamProbe(Stream<T> stream) {
    final sub = stream.listen(values.add, onError: errors.add);
    addTearDown(sub.cancel);
  }

  final List<T> values = [];
  final List<Object> errors = [];

  /// The latest value once the event queue is drained.
  Future<T> get settled async {
    await pumpEventQueue();
    expect(errors, isEmpty);
    return values.last;
  }
}

/// Asserts [result] is an [Err] whose failure message contains [message].
void expectErr<T>(Result<T> result, [String? message]) {
  expect(result.isOk, isFalse, reason: 'expected Err, got Ok');
  if (message != null) {
    expect(result.failureOrNull!.message, contains(message));
  }
}
