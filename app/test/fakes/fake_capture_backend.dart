// failWith mirrors the vv-testing fake contract; a setter reads poorly.
// ignore_for_file: use_setters_to_change_properties

import 'dart:async';

import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/audio_recorder.dart';
import 'package:vaultvoice/features/recording/domain/capture_backend.dart';

/// One call made on [FakeCaptureBackend].
sealed class CaptureCall {
  const CaptureCall();
}

final class OpenCall extends CaptureCall {
  const OpenCall();
}

final class SuspendCall extends CaptureCall {
  const SuspendCall(this.gap, this.discardFrom);

  final GapKind gap;
  final DateTime? discardFrom;
}

final class ResumeCall extends CaptureCall {
  const ResumeCall();
}

final class CloseCall extends CaptureCall {
  const CloseCall([this.cause = StopCause.user]);

  final StopCause cause;
}

/// Records every call so tests can assert the exact capture sequence.
/// `micOpen` models whether the microphone input is open.
class FakeCaptureBackend implements CaptureBackend {
  final calls = <CaptureCall>[];
  bool micOpen = false;
  Failure? _failure;

  /// Runs inside [openMicrophone] / [resumeCapture] before they complete.
  void Function()? onOpen;

  void failWith(Failure failure) => _failure = failure;

  List<SuspendCall> get suspends => calls.whereType<SuspendCall>().toList();

  @override
  Future<Result<void>> openMicrophone({bool Function()? mayOpen}) async {
    calls.add(const OpenCall());
    if (_failure case final f?) return Err(f);
    await openGate?.future;
    if (mayOpen != null && !mayOpen()) {
      return Err(RecordingBlockedFailure(RecordingBlockReason.inCall));
    }
    onOpen?.call();
    micOpen = true;
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> suspend({
    required GapKind gap,
    DateTime? discardFrom,
  }) async {
    calls.add(SuspendCall(gap, discardFrom));
    micOpen = false;
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> resumeCapture({bool Function()? mayOpen}) async {
    calls.add(const ResumeCall());
    onOpen?.call();
    micOpen = true;
    return const Ok<void>(null);
  }

  /// When set, [openMicrophone] waits for it (slow storage/permission work).
  Completer<void>? openGate;

  /// When set, [close] waits for it (models slow chunk finalization).
  Completer<void>? closeGate;

  final _notices = StreamController<CaptureNotice>.broadcast(sync: true);

  /// Raises a capture notice (low storage, OS interruption, failure).
  void notify(CaptureNotice notice) => _notices.add(notice);

  @override
  Stream<CaptureNotice> get notices => _notices.stream;

  @override
  Future<Result<RecordedAudio>> close({
    StopCause cause = StopCause.user,
  }) async {
    calls.add(CloseCall(cause));
    await closeGate?.future;
    micOpen = false;
    return const Ok(
      RecordedAudio(path: 'fake/rec.wav', duration: Duration.zero),
    );
  }
}
