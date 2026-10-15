import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_guard.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/clock.dart';
import 'package:vaultvoice/core/utils/ids.dart';
import 'package:vaultvoice/features/pipeline/data/job_mapper.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_engines.dart';
import 'package:vaultvoice/features/pipeline/data/steps/extract_step.dart';
import 'package:vaultvoice/features/pipeline/data/steps/render_write_steps.dart';
import 'package:vaultvoice/features/pipeline/data/steps/step_support.dart';
import 'package:vaultvoice/features/pipeline/data/steps/transcribe_step.dart';
import 'package:vaultvoice/features/pipeline/domain/heavy_model_gate.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state_machine.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_client.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_step.dart';

/// Priority of user-initiated ("Process now") jobs.
const userPriority = 10;

/// The standard steps (diarize/classify are added by STT-05/PRF-06).
List<PipelineStep> defaultSteps({
  required VaultVoiceDatabase db,
  required StoragePaths paths,
  required PipelineEngines engines,
  PipelineConfig config = const PipelineConfig(),
}) => [
  TranscribeStep(
    db: db,
    paths: paths,
    stt: engines.stt,
    config: config,
    clock: engines.clock,
    activeModel: engines.activeModel,
  ),
  ExtractStep(
    db: db,
    llm: engines.llm,
    config: config,
    clock: engines.clock,
    activeModel: engines.activeModel,
    profiles: engines.profiles,
    grammars: engines.grammars,
    strategy: engines.extraction,
  ),
  RenderStep(
    db: db,
    paths: paths,
    renderer: engines.renderer,
    loader: engines.rendererLoader,
  ),
  WriteStep(
    db: db,
    paths: paths,
    vault: engines.vault,
    clock: engines.clock,
    vaultFor: engines.vaultFor,
    profiles: engines.profiles,
  ),
];

class _Run {
  _Run(this.jobId);

  final String jobId;
  final CancelToken token = CancelToken();
}

class _Superseded implements Exception {
  const _Superseded();
}

/// The persistent single-worker job queue (vv-pipeline-orchestrator).
///
/// Invariants: the new state is persisted before a step starts; a step's
/// outputs and the move to the next step are committed in one transaction;
/// writes are compare-and-set on the job's state so a concurrent cancel or
/// pause always wins; only one step (one heavy model) runs at a time; on
/// [start], jobs left active by a kill are recovered from their checkpoint.
class PipelineOrchestrator implements PipelineClient {
  PipelineOrchestrator({
    required this.db,
    required List<PipelineStep> steps,
    this.paths,
    this.clock = const SystemClock(),
    HeavyModelGate? gate,
    this.machine = const JobStateMachine(),
    this.metrics,
    String Function()? newId,
  }) : _steps = {for (final s in steps) s.id: s},
       gate = gate ?? HeavyModelGate(),
       _newId = newId ?? newUuidV4;

  /// The standard wiring from [engines].
  factory PipelineOrchestrator.withEngines({
    required VaultVoiceDatabase db,
    required StoragePaths paths,
    required PipelineEngines engines,
    PipelineConfig config = const PipelineConfig(),
    String Function()? newId,
  }) => PipelineOrchestrator(
    db: db,
    paths: paths,
    steps: defaultSteps(db: db, paths: paths, engines: engines, config: config),
    clock: engines.clock,
    gate: engines.gate,
    metrics: engines.metrics,
    newId: newId,
  );

  final VaultVoiceDatabase db;
  final StoragePaths? paths;
  final HeavyModelGate gate;
  final JobStateMachine machine;

  /// Per-step performance metrics (FND-07/FND-11); null records nothing.
  final StepMetrics? metrics;
  final Map<PipelineStepId, PipelineStep> _steps;
  final Clock clock;
  final String Function() _newId;
  final _events = StreamController<JobEvent>.broadcast();

  bool _started = false;
  bool _stopped = false;
  bool _idle = false;
  Future<void>? _loop;
  Completer<void>? _wake;
  Timer? _timer;
  _Run? _current;
  final List<Completer<void>> _idleWaiters = [];

  @override
  Stream<JobEvent> get events => _events.stream;

  /// Recovers jobs interrupted by a kill, then starts the worker loop.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    final active = await db.jobsRepository.findByStatus({
      for (final s in JobState.values)
        if (s.isActive) s.name,
    });
    for (final row in active.valueOrNull ?? const <JobRow>[]) {
      final job = jobFromRow(row);
      await _saveIf(job, machine.recover(job, clock.now()));
    }
    _loop = _workLoop();
  }

  /// Wakes the worker (after the clock passed a retry's `notBefore`).
  void poke() {
    _idle = false;
    final wake = _wake;
    _wake = null;
    _timer?.cancel();
    if (wake != null && !wake.isCompleted) wake.complete();
  }

  /// Completes when the worker has nothing runnable left.
  Future<void> whenIdle() {
    if (_idle || _stopped) return Future.value();
    final c = Completer<void>();
    _idleWaiters.add(c);
    return c.future;
  }

  @override
  Future<void> dispose() async {
    if (_stopped) return;
    _stopped = true;
    _current?.token.cancel();
    poke();
    await _loop;
    for (final c in _idleWaiters) {
      if (!c.isCompleted) c.complete();
    }
    await _events.close();
  }

  // ---------------------------------------------------------------- commands

  @override
  Future<Result<String>> enqueue(
    String recordingId, {
    bool userInitiated = false,
    String? profileId,
  }) async {
    final rec = await db.recordingsRepository.get(recordingId);
    if (rec case Err(:final failure)) return Err(failure);
    if (profileId != null) {
      final set = await _setProfile(recordingId, profileId);
      if (set case Err(:final failure)) return Err(failure);
    }
    final existing = await db.jobsRepository
        .watchForRecording(recordingId)
        .first;
    for (final row in existing) {
      final job = jobFromRow(row);
      if (!job.state.isTerminal) {
        if (userInitiated) await processNow(job.id);
        return Ok(job.id);
      }
    }
    final first = _firstStep;
    if (first == null) return const Err(UnexpectedFailure('no steps'));
    final now = clock.now();
    final job = JobSnapshot(
      id: _newId(),
      recordingId: recordingId,
      state: first.restingBefore,
      step: first,
      priority: userInitiated ? userPriority : 0,
      createdAt: now,
      updatedAt: now,
    );
    final created = await db.jobsRepository.create(jobToCompanion(job));
    if (created case Err(:final failure)) return Err(failure);
    _emit(job);
    poke();
    return Ok(job.id);
  }

  @override
  Future<Result<void>> processNow(String jobId) =>
      _command(jobId, 'processNow', (job, now) {
        if (job.state.isTerminal) {
          throw InvalidTransitionException(job.state, 'processNow');
        }
        return job.copyWith(priority: userPriority, updatedAt: now);
      });

  @override
  Future<Result<void>> cancel(String jobId) =>
      _command(jobId, 'cancel', machine.cancel, interrupt: true);

  @override
  Future<Result<void>> pause(String jobId) =>
      _command(jobId, 'pause', machine.pause, interrupt: true);

  @override
  Future<Result<void>> resume(String jobId) =>
      _command(jobId, 'resume', machine.resume);

  @override
  Future<Result<void>> retry(String jobId) =>
      _command(jobId, 'retry', machine.retryNow);

  @override
  Future<Result<void>> resolveWaiting(String jobId) =>
      _command(jobId, 'resolveWaiting', machine.resolveWaiting);

  @override
  Future<Result<void>> rerun(
    String jobId,
    PipelineStepId from, {
    String? profileId,
  }) async {
    final loaded = await db.jobsRepository.get(jobId);
    if (loaded case Err(:final failure)) return Err(failure);
    final job = jobFromRow(loaded.valueOrNull!);
    if (job.state.isActive) return Err(_invalid(job.state, 'rerun'));
    if (!_steps.containsKey(from)) return Err(_invalid(job.state, 'rerun'));
    if (from != PipelineStepId.transcribe) {
      // Later steps build on the transcript, which a re-run never discards.
      final transcript = await db.transcriptsRepository.latestFor(
        job.recordingId,
      );
      if (transcript.valueOrNull == null) {
        return const Err(StorageFailure('no transcript'));
      }
    }
    if (profileId != null) {
      final set = await _setProfile(job.recordingId, profileId);
      if (set case Err(:final failure)) return Err(failure);
    }
    await _clearOutputs(job, from);
    return await _command(
      jobId,
      'rerun',
      (j, now) => machine.rerun(j, from, now),
    );
  }

  // ------------------------------------------------------------------ worker

  PipelineStepId? get _firstStep => _nextStep(null);

  PipelineStepId? _nextStep(PipelineStepId? after) {
    for (final id in PipelineStepId.values) {
      if ((after == null || id.index > after.index) && _steps.containsKey(id)) {
        return id;
      }
    }
    return null;
  }

  Future<void> _workLoop() async {
    while (!_stopped) {
      final (job, wakeAt) = await _nextRunnable();
      if (_stopped) break;
      if (job == null) {
        // Queue empty: free the loaded model (vv-llm-inference → unload the
        // LLM when the queue is empty).
        await gate.releaseAll();
        if (_stopped) break;
        await _sleep(wakeAt);
        continue;
      }
      await _process(job);
    }
  }

  Future<(JobSnapshot?, DateTime?)> _nextRunnable() async {
    final rows = await db.jobsRepository.findByStatus({
      for (final s in JobState.runnable) s.name,
    });
    final now = clock.now();
    DateTime? earliest;
    for (final row in rows.valueOrNull ?? const <JobRow>[]) {
      final job = jobFromRow(row);
      final at = job.notBefore;
      if (at == null || !at.isAfter(now)) return (job, null);
      if (earliest == null || at.isBefore(earliest)) earliest = at;
    }
    return (null, earliest);
  }

  Future<void> _sleep(DateTime? wakeAt) async {
    final wake = _wake = Completer<void>();
    _idle = true;
    for (final c in _idleWaiters) {
      if (!c.isCompleted) c.complete();
    }
    _idleWaiters.clear();
    if (wakeAt != null) {
      _timer = Timer(wakeAt.difference(clock.now()), poke);
    }
    await wake.future;
  }

  Future<void> _process(JobSnapshot job) async {
    final step = _steps[job.step];
    if (step == null || !step.canRun(job)) {
      await _saveIf(job, machine.skip(job, _nextStep(job.step), clock.now()));
      return;
    }
    // Persist before act.
    final active = machine.start(job, clock.now());
    if (!await _saveIf(job, active)) return;
    await gate.use(step.model);

    final run = _current = _Run(active.id);
    final ctx = _Context(this, run, active);
    final measurement = await _beginMetrics(active, step);
    StepResult result;
    try {
      result = await step.run(ctx);
    } on StepAbort catch (e) {
      result = StepFailed(e.failure);
    } on Object catch (e) {
      result = StepFailed(dbFailure(e));
    }
    _current = null;
    await _finishMetrics(
      measurement,
      succeeded: result is StepSucceeded && !_stopped,
    );
    // Killed / disposed: leave the persisted active state for recovery.
    if (_stopped) return;
    final current = ctx.job;
    final now = clock.now();
    switch (result) {
      case StepSucceeded(:final commit):
        try {
          await db.transaction(() async {
            await commit?.call();
            final next = machine.complete(current, _nextStep(step.id), now);
            if (!await _casWrite(current, next)) throw const _Superseded();
          });
          _emit(machine.complete(current, _nextStep(step.id), now));
        } on _Superseded {
          return; // cancelled/paused meanwhile: discard outputs
        } on StepAbort catch (e) {
          await _onFailure(current, e.failure, null, now);
        } on Object catch (e) {
          await _onFailure(current, dbFailure(e), null, now);
        }
      case StepFailed(:final failure, :final kind):
        await _onFailure(current, failure, kind, now);
      case StepWaiting(:final reason):
        await _saveIf(current, machine.wait(current, reason, now));
    }
  }

  Future<StepMeasurement?> _beginMetrics(
    JobSnapshot job,
    PipelineStep step,
  ) async {
    try {
      return await metrics?.begin(job, step);
    } on Object {
      return null; // metrics never fail a job
    }
  }

  Future<void> _finishMetrics(
    StepMeasurement? measurement, {
    required bool succeeded,
  }) async {
    try {
      await measurement?.finish(succeeded: succeeded);
    } on Object {
      // metrics never fail a job
    }
  }

  Future<void> _onFailure(
    JobSnapshot job,
    Failure failure,
    FailureKind? kind,
    DateTime now,
  ) async {
    final detail = failure.runtimeType.toString();
    final disposition = switch (kind) {
      FailureKind.permanent => const PermanentDisposition(),
      FailureKind.retryable => const RetryDisposition(),
      null => classifyFailure(failure),
    };
    final next = switch (disposition) {
      WaitDisposition(:final reason) => machine.wait(job, reason, now),
      RetryDisposition() => machine.fail(
        job,
        FailureKind.retryable,
        detail,
        now,
      ),
      PermanentDisposition() => machine.fail(
        job,
        FailureKind.permanent,
        detail,
        now,
      ),
    };
    await _saveIf(job, next);
  }

  // ------------------------------------------------------------- persistence

  /// Writes [next] only if the stored job is still in [expected]'s state.
  Future<bool> _casWrite(JobSnapshot expected, JobSnapshot next) async {
    final n =
        await (db.update(db.jobs)..where(
              (j) =>
                  j.id.equals(expected.id) &
                  j.status.equals(expected.state.name),
            ))
            .write(jobToCompanion(next));
    return n == 1;
  }

  Future<bool> _saveIf(JobSnapshot expected, JobSnapshot next) async {
    final ok = await guardDb(() => _casWrite(expected, next));
    final written = ok.valueOrNull ?? false;
    if (written) _emit(next);
    return written;
  }

  Future<Result<void>> _command(
    String jobId,
    String name,
    JobSnapshot Function(JobSnapshot job, DateTime now) transition, {
    bool interrupt = false,
  }) async {
    final loaded = await db.jobsRepository.get(jobId);
    if (loaded case Err(:final failure)) return Err(failure);
    final job = jobFromRow(loaded.valueOrNull!);
    final JobSnapshot next;
    try {
      next = transition(job, clock.now());
    } on InvalidTransitionException {
      return Err(_invalid(job.state, name));
    }
    if (!await _saveIf(job, next)) {
      return Err(_invalid(job.state, name)); // raced with the worker
    }
    final running = _current;
    if (interrupt && running != null && running.jobId == jobId) {
      running.token.cancel();
    }
    poke();
    return const Ok<void>(null);
  }

  Future<Result<void>> _setProfile(String recordingId, String profileId) =>
      db.recordingsRepository.updateFields(
        recordingId,
        RecordingsCompanion(profileId: Value(profileId)),
      );

  /// Clears outputs of [from] and later steps (never the transcript unless
  /// re-running transcription, which overwrites it).
  Future<void> _clearOutputs(JobSnapshot job, PipelineStepId from) async {
    if (from.index <= PipelineStepId.extract.index) {
      await db.extractionsRepository.deleteById(extractionIdFor(job.id));
    }
    final p = paths;
    if (p != null && from.index <= PipelineStepId.render.index) {
      final rendered = File(p.renderedFile(job.recordingId));
      if (rendered.existsSync()) await rendered.delete();
    }
  }

  void _emit(JobSnapshot job) {
    if (!_events.isClosed) _events.add(JobEvent.of(job));
  }

  static Failure _invalid(JobState from, String transition) =>
      UnexpectedFailure('invalid transition $transition from ${from.name}');
}

class _Context implements StepContext {
  _Context(this._o, this._run, this._job);

  final PipelineOrchestrator _o;
  final _Run _run;
  JobSnapshot _job;

  @override
  JobSnapshot get job => _job;

  @override
  CancelToken get cancel => _run.token;

  @override
  void reportProgress(double fraction) {
    if (_o._stopped || _run.token.isCancelled) return;
    _o._emit(_o.machine.progress(_job, fraction, _o.clock.now()));
  }

  @override
  Future<void> saveCheckpoint(
    Map<String, Object?> checkpoint, {
    double? progress,
    Future<void> Function()? writes,
  }) async {
    if (_o._stopped || _run.token.isCancelled) {
      throw const StepAbort(CancelledFailure());
    }
    final next = _o.machine.progress(
      _job,
      progress ?? _job.progress,
      _o.clock.now(),
      checkpoint: checkpoint,
    );
    try {
      await _o.db.transaction(() async {
        await writes?.call();
        if (!await _o._casWrite(_job, next)) throw const _Superseded();
      });
    } on _Superseded {
      throw const StepAbort(CancelledFailure());
    }
    _job = next;
    _o._emit(next);
  }
}
