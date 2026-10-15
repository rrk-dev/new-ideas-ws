import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_providers.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';

part 'model_install_waker.g.dart';

/// Lets recordings made while models were still downloading process as soon
/// as a model is installed (APP-01 "queue processing until ready"): every
/// change of the installed-model set re-checks jobs parked in
/// `waiting(model_missing)` and resolves them. A job whose model is still
/// missing simply waits again.
class ModelInstallWaker {
  ModelInstallWaker({
    required Stream<Set<String>> installedIds,
    required Future<List<String>> Function() waitingJobIds,
    required this._resolve,
  }) : _installed = installedIds,
       _waiting = waitingJobIds;

  final Stream<Set<String>> _installed;
  final Future<List<String>> Function() _waiting;
  final Future<void> Function(String jobId) _resolve;
  StreamSubscription<Set<String>>? _sub;
  Set<String>? _last;

  void start() {
    _sub ??= _installed.listen((ids) async {
      final previous = _last;
      _last = ids;
      // Only a newly installed model can unblock a waiting job.
      if (previous != null && ids.difference(previous).isEmpty) return;
      for (final id in await _waiting()) {
        await _resolve(id);
      }
    });
  }

  Future<void> dispose() async => await _sub?.cancel();
}

@Riverpod(keepAlive: true)
ModelInstallWaker modelInstallWaker(Ref ref) {
  final jobs = ref.watch(jobsRepositoryProvider);
  final waker = ModelInstallWaker(
    installedIds: ref
        .watch(modelsRepositoryProvider)
        .watchAll()
        .map((rows) => {for (final r in rows) r.id}),
    waitingJobIds: () async {
      final rows =
          (await jobs.findByStatus({JobState.waiting.name})).valueOrNull ??
          const [];
      return [
        for (final r in rows)
          if (r.waitingReason == WaitingReason.modelMissing.name) r.id,
      ];
    },
    resolve: (jobId) async {
      try {
        final client = await ref.read(pipelineClientProvider.future);
        await client.resolveWaiting(jobId);
      } on Object {
        // Worker unavailable: the job stays waiting until the next install.
      }
    },
  );
  ref.onDispose(waker.dispose);
  return waker;
}
