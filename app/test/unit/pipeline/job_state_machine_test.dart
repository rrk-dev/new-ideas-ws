import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/features/pipeline/domain/heavy_model_gate.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state_machine.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_client.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_step.dart';

final DateTime t0 = DateTime.utc(2026, 10, 12, 9);
final DateTime t1 = t0.add(const Duration(seconds: 1));

JobSnapshot queued({PipelineStepId step = PipelineStepId.transcribe}) =>
    JobSnapshot(
      id: 'j1',
      recordingId: 'r1',
      state: step.restingBefore,
      step: step,
      createdAt: t0,
      updatedAt: t0,
    );

Matcher throwsInvalid = throwsA(isA<InvalidTransitionException>());

void main() {
  const m = JobStateMachine();

  group('[FND-05/AC3] step vocabulary', () {
    test('every step maps to its active and resting states', () {
      expect(
        [for (final s in PipelineStepId.values) s.activeState],
        [
          JobState.transcribing,
          JobState.diarizing,
          JobState.classifying,
          JobState.extracting,
          JobState.rendering,
          JobState.writing,
        ],
      );
      expect(
        [for (final s in PipelineStepId.values) s.restingBefore],
        [
          JobState.queued,
          JobState.transcribed,
          JobState.transcribed,
          JobState.transcribed,
          JobState.extracted,
          JobState.rendered,
        ],
      );
      expect(
        [for (final s in PipelineStepId.values) s.restingAfter],
        [
          JobState.transcribed,
          JobState.transcribed,
          JobState.transcribed,
          JobState.extracted,
          JobState.rendered,
          JobState.done,
        ],
      );
    });

    test('state classes are disjoint and runnable == resting', () {
      for (final s in JobState.values) {
        final classes = [s.isActive, s.isResting, s.isTerminal];
        expect(classes.where((c) => c).length, lessThanOrEqualTo(1));
      }
      expect(JobState.runnable, {
        for (final s in JobState.values)
          if (s.isResting) s,
      });
      expect(JobState.paused.isActive || JobState.paused.isResting, isFalse);
      expect(JobState.waiting.isTerminal, isFalse);
    });
  });

  group('[FND-05/AC3] happy path', () {
    test('queued → … → done through every step', () {
      var job = queued();
      final seen = <JobState>[job.state];
      PipelineStepId? next(PipelineStepId s) =>
          s.index + 1 < PipelineStepId.values.length
          ? PipelineStepId.values[s.index + 1]
          : null;
      while (job.state != JobState.done) {
        job = m.start(job, t1);
        seen.add(job.state);
        expect(job.attempts, 1);
        job = m.progress(job, 0.5, t1, checkpoint: {'n': 1});
        expect(job.progress, 0.5);
        expect(job.checkpoint, {'n': 1});
        job = m.complete(job, next(job.step), t1);
        seen.add(job.state);
        expect(job.attempts, 0);
        expect(job.checkpoint, isEmpty);
      }
      expect(seen, [
        JobState.queued,
        JobState.transcribing,
        JobState.transcribed,
        JobState.diarizing,
        JobState.transcribed,
        JobState.classifying,
        JobState.transcribed,
        JobState.extracting,
        JobState.extracted,
        JobState.rendering,
        JobState.rendered,
        JobState.writing,
        JobState.done,
      ]);
      expect(job.progress, 1);
      expect(job.updatedAt, t1);
    });

    test('progress clamps and needs an active state', () {
      final active = m.start(queued(), t1);
      expect(m.progress(active, 7, t1).progress, 1);
      expect(m.progress(active, -1, t1).progress, 0);
      expect(() => m.progress(queued(), 0.5, t1), throwsInvalid);
    });

    test('skip moves past disabled steps or finishes', () {
      final atDiarize = queued(step: PipelineStepId.diarize);
      final skipped = m.skip(atDiarize, PipelineStepId.extract, t1);
      expect(skipped.state, JobState.transcribed);
      expect(skipped.step, PipelineStepId.extract);
      final finished = m.skip(queued(step: PipelineStepId.write), null, t1);
      expect(finished.state, JobState.done);
      expect(
        () => m.skip(atDiarize, PipelineStepId.transcribe, t1),
        throwsInvalid,
      );
      expect(
        () => m.skip(m.start(atDiarize, t1), PipelineStepId.extract, t1),
        throwsInvalid,
      );
    });

    test('complete rejects going backwards and non-active jobs', () {
      final active = m.start(queued(step: PipelineStepId.extract), t1);
      expect(
        () => m.complete(active, PipelineStepId.transcribe, t1),
        throwsInvalid,
      );
      expect(() => m.complete(queued(), null, t1), throwsInvalid);
      expect(() => m.start(active, t1), throwsInvalid);
    });
  });

  group('[FND-05/AC3] failure and retry', () {
    test('retryable failures back off 30 s → 2 min → 10 min, then fail', () {
      var job = queued();
      final delays = <Duration?>[];
      for (var i = 0; i < 4; i++) {
        job = m.start(job, t0);
        job = m.progress(job, 0.3, t0, checkpoint: {'nextChunk': 2});
        job = m.fail(job, FailureKind.retryable, 'OutOfMemoryFailure', t0);
        delays.add(job.notBefore?.difference(t0));
        expect(job.checkpoint, {'nextChunk': 2}, reason: 'resume point kept');
        expect(job.failureKind, FailureKind.retryable);
        expect(job.errorDetail, 'OutOfMemoryFailure');
      }
      expect(delays, [
        const Duration(seconds: 30),
        const Duration(minutes: 2),
        const Duration(minutes: 10),
        null,
      ]);
      expect(job.state, JobState.failed);
      expect(job.attempts, 4);
    });

    test('a resting job with backoff restarts and clears notBefore', () {
      final failed = m.fail(
        m.start(queued(), t0),
        FailureKind.retryable,
        'x',
        t0,
      );
      expect(failed.state, JobState.queued);
      final restarted = m.start(failed, t1);
      expect(restarted.notBefore, isNull);
      expect(restarted.attempts, 2);
    });

    test('permanent failures fail at once; manual retry resets', () {
      final job = m.start(queued(step: PipelineStepId.extract), t0);
      final failed = m.fail(job, FailureKind.permanent, 'NativeFailure', t0);
      expect(failed.state, JobState.failed);
      expect(failed.notBefore, isNull);
      expect(
        () => m.fail(failed, FailureKind.permanent, 'x', t0),
        throwsInvalid,
      );
      final retried = m.retryNow(failed, t1);
      expect(retried.state, JobState.transcribed);
      expect(retried.step, PipelineStepId.extract);
      expect(retried.attempts, 0);
      expect(retried.failureKind, isNull);
      expect(retried.errorDetail, isNull);
      expect(() => m.retryNow(queued(), t1), throwsInvalid);
    });

    test('failures are classified by the retry policy', () {
      expect(
        classifyFailure(const OutOfMemoryFailure()),
        isA<RetryDisposition>(),
      );
      expect(
        classifyFailure(const StorageFailure('io')),
        isA<RetryDisposition>(),
      );
      expect(
        classifyFailure(const NetworkFailure('x')),
        isA<RetryDisposition>(),
      );
      expect(
        classifyFailure(const ModelMissingFailure('stt')),
        isA<WaitDisposition>().having(
          (d) => d.reason,
          'reason',
          WaitingReason.modelMissing,
        ),
      );
      expect(
        classifyFailure(const PermissionFailure('vault')),
        isA<WaitDisposition>().having(
          (d) => d.reason,
          'reason',
          WaitingReason.destination,
        ),
      );
      for (final f in <Failure>[
        const NativeFailure(-1, 'x'),
        const CancelledFailure(),
        const UnexpectedFailure('x'),
      ]) {
        expect(classifyFailure(f), isA<PermanentDisposition>(), reason: '$f');
      }
    });

    test('custom retry policy', () {
      const once = RetryPolicy(backoff: [Duration(seconds: 1)]);
      expect(once.delayAfter(0), isNull);
      expect(once.delayAfter(1), const Duration(seconds: 1));
      expect(once.delayAfter(2), isNull);
    });
  });

  group('[FND-05/AC3] cancel, pause, wait, rerun, recover', () {
    test('cancel from any non-final state; not from done/cancelled', () {
      final active = m.start(queued(), t0);
      for (final job in [
        queued(),
        active,
        m.pause(active, t0),
        m.wait(active, WaitingReason.review, t0),
        m.fail(active, FailureKind.permanent, 'x', t0),
      ]) {
        final c = m.cancel(job, t1);
        expect(c.state, JobState.cancelled, reason: job.state.name);
        expect(c.notBefore, isNull);
      }
      final done = m.complete(
        m.start(queued(step: PipelineStepId.write), t0),
        null,
        t0,
      );
      expect(() => m.cancel(done, t1), throwsInvalid);
      expect(() => m.cancel(m.cancel(queued(), t1), t1), throwsInvalid);
      // A cancelled job can be retried.
      expect(m.retryNow(m.cancel(active, t1), t1).state, JobState.queued);
    });

    test('pause / resume', () {
      final active = m.start(queued(step: PipelineStepId.render), t0);
      final paused = m.pause(active, t1);
      expect(paused.state, JobState.paused);
      expect(m.pause(queued(), t1).state, JobState.paused);
      final resumed = m.resume(paused, t1);
      expect(resumed.state, JobState.extracted);
      expect(() => m.resume(active, t1), throwsInvalid);
      expect(() => m.pause(paused, t1), throwsInvalid);
    });

    test('waiting(reason) and resolution', () {
      final active = m.start(queued(step: PipelineStepId.write), t0);
      final waiting = m.wait(active, WaitingReason.destination, t1);
      expect(waiting.state, JobState.waiting);
      expect(waiting.waitingReason, WaitingReason.destination);
      expect(
        m.wait(queued(), WaitingReason.modelMissing, t1).state,
        JobState.waiting,
      );
      final resolved = m.resolveWaiting(waiting, t1);
      expect(resolved.state, JobState.rendered);
      expect(resolved.waitingReason, isNull);
      expect(() => m.resolveWaiting(active, t1), throwsInvalid);
      expect(() => m.wait(waiting, WaitingReason.review, t1), throwsInvalid);
      // Starting clears a stale reason.
      expect(m.start(resolved, t1).waitingReason, isNull);
    });

    test('rerun from a step resets progress but not while running', () {
      final done = m.complete(
        m.start(queued(step: PipelineStepId.write), t0),
        null,
        t0,
      );
      final rerun = m.rerun(done, PipelineStepId.extract, t1);
      expect(rerun.state, JobState.transcribed);
      expect(rerun.step, PipelineStepId.extract);
      expect(rerun.progress, 0);
      expect(rerun.checkpoint, isEmpty);
      final failed = m.fail(
        m.start(queued(), t0),
        FailureKind.permanent,
        'x',
        t0,
      );
      expect(
        m.rerun(failed, PipelineStepId.transcribe, t1).failureKind,
        isNull,
      );
      expect(
        () => m.rerun(m.start(queued(), t0), PipelineStepId.extract, t1),
        throwsInvalid,
      );
    });

    test('recover puts a killed active job back before its step with its '
        'checkpoint', () {
      final active = m.progress(
        m.start(queued(), t0),
        0.5,
        t0,
        checkpoint: {'nextChunk': 2},
      );
      final recovered = m.recover(active, t1);
      expect(recovered.state, JobState.queued);
      expect(recovered.step, PipelineStepId.transcribe);
      expect(recovered.checkpoint, {'nextChunk': 2});
      expect(recovered.attempts, 1);
      expect(() => m.recover(queued(), t1), throwsInvalid);
    });
  });

  group('misc', () {
    test('toString is content-free', () {
      expect(queued().toString(), 'JobSnapshot(j1, queued, transcribe)');
      expect(
        JobEvent.of(m.progress(m.start(queued(), t0), 0.25, t0)).toString(),
        'JobEvent(j1, transcribing, transcribe, 25%)',
      );
      expect(
        const InvalidTransitionException(JobState.done, 'start').toString(),
        'InvalidTransitionException(start from done)',
      );
      expect(
        const StepAbort(CancelledFailure()).toString(),
        'StepAbort(CancelledFailure)',
      );
    });

    test('heavy model gate keeps one model loaded', () async {
      final released = <HeavyModel>[];
      final gate = HeavyModelGate(release: (m) async => released.add(m));
      await gate.use(null);
      expect(gate.loaded, isNull);
      await gate.use(HeavyModel.stt);
      await gate.use(HeavyModel.stt);
      expect(released, isEmpty);
      await gate.use(HeavyModel.llm);
      expect(released, [HeavyModel.stt]);
      expect(gate.loaded, HeavyModel.llm);
      await gate.releaseAll();
      await gate.releaseAll();
      expect(released, [HeavyModel.stt, HeavyModel.llm]);
      expect(gate.loaded, isNull);
    });
  });
}
