import 'dart:async';
import 'dart:isolate';

import 'package:drift/isolate.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_engines.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_orchestrator.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_client.dart';

class _WorkerArgs {
  const _WorkerArgs(
    this.database,
    this.storageRoot,
    this.engines,
    this.config,
    this.toMain,
  );

  final DriftIsolate database;
  final String storageRoot;
  final PipelineEnginesFactory engines;
  final PipelineConfig config;
  final SendPort toMain;
}

class _Request {
  const _Request(this.op, this.args, this.reply);

  final String op;
  final List<Object?> args;
  final SendPort reply;
}

Object? _forward(void Function() notify) {
  notify();
  return null;
}

Future<void> _workerMain(_WorkerArgs args) async {
  final db = VaultVoiceDatabase(await args.database.connect());
  final paths = StoragePaths(args.storageRoot);
  final engines = args.engines(PipelineWorkerContext(db: db, paths: paths));
  final orchestrator = PipelineOrchestrator.withEngines(
    db: db,
    paths: paths,
    engines: engines,
    config: args.config,
  );
  final commands = ReceivePort('vv-pipeline commands');
  orchestrator.events.listen(args.toMain.send);
  await orchestrator.start();
  args.toMain.send(commands.sendPort);

  await for (final message in commands) {
    final req = message as _Request;
    Object? reply;
    try {
      reply = await _dispatch(orchestrator, engines, req);
    } on Object {
      // A throwing command must still be answered (the caller awaits the
      // reply) and must not end this loop; content-free by design.
      reply = req.op == 'foreground' || req.op == 'memoryPressure'
          ? null
          : const Err<void>(UnexpectedFailure('command failed'));
    }
    if (req.op == 'dispose') {
      await orchestrator.dispose();
      await engines.dispose?.call();
      await db.close();
      commands.close();
    }
    req.reply.send(reply);
  }
}

Future<Object?> _dispatch(
  PipelineOrchestrator orchestrator,
  PipelineEngines engines,
  _Request req,
) async {
  final a = req.args;
  return switch (req.op) {
    'enqueue' => await orchestrator.enqueue(
      a[0]! as String,
      userInitiated: a[1]! as bool,
      profileId: a[2] as String?,
    ),
    'processNow' => await orchestrator.processNow(a[0]! as String),
    'cancel' => await orchestrator.cancel(a[0]! as String),
    'retry' => await orchestrator.retry(a[0]! as String),
    'rerun' => await orchestrator.rerun(
      a[0]! as String,
      PipelineStepId.values[a[1]! as int],
      profileId: a[2] as String?,
    ),
    'pause' => await orchestrator.pause(a[0]! as String),
    'resume' => await orchestrator.resume(a[0]! as String),
    'resolveWaiting' => await orchestrator.resolveWaiting(a[0]! as String),
    'foreground' => _forward(
      () => engines.onForeground?.call(foreground: a[0]! as bool),
    ),
    'memoryPressure' => _forward(() => engines.onMemoryPressure?.call()),
    'dispose' => null,
    _ => const Err<void>(UnexpectedFailure('unknown command')),
  };
}

/// What callers get once the worker is gone (crash or abrupt exit).
const _workerStopped = Err<Never>(UnexpectedFailure('pipeline worker stopped'));

/// Tracks the worker's liveness and the commands waiting for a reply, so a
/// crash after startup fails them instead of leaving them hanging.
class _Lifecycle {
  final Set<Completer<Object?>> pending = {};
  final Completer<void> terminated = Completer();
  bool disposing = false;

  bool get dead => terminated.isCompleted;

  void terminate() {
    if (dead || disposing) return;
    terminated.complete();
    for (final c in pending) {
      if (!c.isCompleted) c.complete(_workerStopped);
    }
    pending.clear();
  }
}

/// Device conditions the UI isolate forwards to the worker's engines
/// (FND-11; FND-08 adds pausing/background tasks on top).
abstract interface class PipelineConditions {
  /// The app moved to the foreground (`resumed`) or away from it.
  Future<void> setForeground({required bool foreground});

  /// The OS reported memory pressure.
  Future<void> memoryPressure();
}

/// Runs the [PipelineOrchestrator] and its engines on a long-lived
/// background isolate so no pipeline work ever runs on the UI isolate. The
/// UI sends commands through this client and observes `jobs` through drift
/// streams (or [events]).
class PipelineIsolateClient implements PipelineClient, PipelineConditions {
  PipelineIsolateClient._(
    this._isolate,
    this._fromWorker,
    this._errors,
    this._exit,
    this._toWorker,
    this._events,
    this._life,
  );

  /// Spawns the worker. [database] comes from
  /// `VaultVoiceDatabase.serializableConnection()` (the worker shares the
  /// process's single connection); [engines] runs inside the worker.
  static Future<PipelineIsolateClient> spawn({
    required DriftIsolate database,
    required String storageRoot,
    required PipelineEnginesFactory engines,
    PipelineConfig config = const PipelineConfig(),
  }) async {
    final fromWorker = ReceivePort('vv-pipeline events');
    final errors = ReceivePort('vv-pipeline errors');
    final events = StreamController<JobEvent>.broadcast();
    final ready = Completer<SendPort>();
    fromWorker.listen((m) {
      if (m is SendPort && !ready.isCompleted) {
        ready.complete(m);
      } else if (m is JobEvent) {
        events.add(m);
      }
    });
    // A crash before the worker is ready fails the spawn instead of hanging;
    // a crash or exit afterwards fails pending and later commands and
    // completes `terminated`. Content-free: the error itself is not logged.
    final life = _Lifecycle();
    final exitPort = ReceivePort('vv-pipeline exit');
    void onDown(Object? e) {
      if (!ready.isCompleted) {
        ready.completeError(
          StateError('pipeline worker failed to start'),
          StackTrace.fromString(e is List && e.length > 1 ? '${e[1]}' : ''),
        );
      } else {
        life.terminate();
      }
    }

    errors.listen(onDown);
    exitPort.listen(onDown);
    final isolate = await Isolate.spawn(
      _workerMain,
      _WorkerArgs(database, storageRoot, engines, config, fromWorker.sendPort),
      debugName: 'vv-pipeline',
      onError: errors.sendPort,
      onExit: exitPort.sendPort,
    );
    final SendPort toWorker;
    try {
      toWorker = await ready.future;
    } on Object {
      isolate.kill(priority: Isolate.immediate);
      fromWorker.close();
      errors.close();
      exitPort.close();
      await events.close();
      rethrow;
    }
    return PipelineIsolateClient._(
      isolate,
      fromWorker,
      errors,
      exitPort,
      toWorker,
      events,
      life,
    );
  }

  final Isolate _isolate;
  final ReceivePort _fromWorker;
  final ReceivePort _errors;
  final ReceivePort _exit;
  final SendPort _toWorker;
  final StreamController<JobEvent> _events;
  final _Lifecycle _life;
  bool _disposed = false;

  @override
  Stream<JobEvent> get events => _events.stream;

  /// Completes when the worker isolate crashed or exited unexpectedly after
  /// startup (never on [dispose]). Every pending and later command then
  /// returns an [UnexpectedFailure]; the owner spawns a new client (startup
  /// recovery resumes the interrupted job from its checkpoint).
  Future<void> get terminated => _life.terminated.future;

  Future<T> _call<T>(String op, List<Object?> args) async {
    if (_disposed) {
      return const Err<Never>(UnexpectedFailure('disposed')) as T;
    }
    if (_life.dead) return _workerStopped as T;
    final reply = ReceivePort();
    final done = Completer<Object?>();
    _life.pending.add(done);
    reply.listen((m) {
      if (!done.isCompleted) done.complete(m);
    });
    _toWorker.send(_Request(op, args, reply.sendPort));
    try {
      return (await done.future) as T;
    } finally {
      _life.pending.remove(done);
      reply.close();
    }
  }

  @override
  Future<Result<String>> enqueue(
    String recordingId, {
    bool userInitiated = false,
    String? profileId,
  }) =>
      _call<Result<String>>('enqueue', [recordingId, userInitiated, profileId]);

  @override
  Future<Result<void>> processNow(String jobId) =>
      _call<Result<void>>('processNow', [jobId]);

  @override
  Future<Result<void>> cancel(String jobId) =>
      _call<Result<void>>('cancel', [jobId]);

  @override
  Future<Result<void>> retry(String jobId) =>
      _call<Result<void>>('retry', [jobId]);

  @override
  Future<Result<void>> rerun(
    String jobId,
    PipelineStepId from, {
    String? profileId,
  }) => _call<Result<void>>('rerun', [jobId, from.index, profileId]);

  @override
  Future<Result<void>> pause(String jobId) =>
      _call<Result<void>>('pause', [jobId]);

  @override
  Future<Result<void>> resume(String jobId) =>
      _call<Result<void>>('resume', [jobId]);

  @override
  Future<Result<void>> resolveWaiting(String jobId) =>
      _call<Result<void>>('resolveWaiting', [jobId]);

  @override
  Future<void> setForeground({required bool foreground}) async {
    if (_disposed) return;
    await _call<Object?>('foreground', [foreground]);
  }

  @override
  Future<void> memoryPressure() async {
    if (_disposed) return;
    await _call<Object?>('memoryPressure', const []);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    if (!_life.dead) await _call<Object?>('dispose', const []);
    _disposed = true;
    _life.disposing = true;
    _fromWorker.close();
    _errors.close();
    _exit.close();
    _isolate.kill();
    await _events.close();
  }
}
