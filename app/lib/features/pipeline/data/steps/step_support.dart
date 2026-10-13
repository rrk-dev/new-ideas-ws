import 'dart:io';

import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_step.dart';

/// Returns the value or throws [StepAbort] (rolls back the enclosing
/// transaction).
T unwrap<T>(Result<T> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw StepAbort(failure),
};

/// Deterministic output ids keyed by job, so re-running overwrites.
String transcriptIdFor(String jobId) => '$jobId.transcript';
String extractionIdFor(String jobId) => '$jobId.extraction';

/// Segment `seq` for segment [index] of audio chunk [chunkSeq]: unique per
/// (chunk, segment) so a re-transcribed chunk overwrites its own segments.
int segmentSeq(int chunkSeq, int index) => chunkSeq * 100000 + index;

/// Writes [content] to [path] atomically (temp file + rename).
Future<void> writeFileAtomic(String path, String content) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  final tmp = File('$path.tmp');
  await tmp.writeAsString(content, flush: true);
  await tmp.rename(path);
}
