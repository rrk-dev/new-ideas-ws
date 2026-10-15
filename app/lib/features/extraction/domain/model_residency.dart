import 'dart:async';

/// Kinds of large models that compete for RAM.
enum ResidentModel { stt, llm }

/// The model of kind [stillResident] could not be unloaded, so the
/// requested model was not marked resident and must not be loaded (LLM-07).
/// Callers map it to a retryable `OutOfMemoryFailure`.
final class ModelResidencyException implements Exception {
  const ModelResidencyException(this.stillResident, this.errorType);

  final ResidentModel stillResident;

  /// `runtimeType` of the unloader's error (never its message).
  final String errorType;

  @override
  String toString() =>
      'ModelResidencyException(${stillResident.name}: $errorType)';
}

/// Enforces AGENTS.md "never hold STT and LLM models in memory at the same
/// time" (LLM-07): engines register an unloader; before loading model kind
/// X, [acquire] unloads every other registered kind **and awaits the
/// unload** (e.g. `WhisperSttEngine.unload` disposes on a helper isolate).
///
/// Transitions are serialized: concurrent [acquire]/[releaseAll] calls run
/// one after another, so two kinds are never marked resident together. If
/// an unloader throws, the other kind stays marked resident and [acquire]
/// throws [ModelResidencyException] — the caller must not load.
final class ModelResidency {
  final Map<ResidentModel, FutureOr<void> Function()> _unloaders = {};
  final Set<ResidentModel> _loaded = {};
  Future<void> _tail = Future<void>.value();

  /// Registers how to unload [kind] (e.g. `LlmService.unload`). May be
  /// asynchronous; it is awaited.
  void register(ResidentModel kind, FutureOr<void> Function() unload) =>
      _unloaders[kind] = unload;

  /// Await right before loading [kind]: unloads the others (awaited).
  Future<void> acquire(ResidentModel kind) => _serialized(() async {
    for (final other in ResidentModel.values) {
      if (other == kind || !_loaded.contains(other)) continue;
      await _unload(other);
    }
    _loaded.add(kind);
  });

  /// Call after [kind] was unloaded by its owner.
  void release(ResidentModel kind) => _loaded.remove(kind);

  /// Unloads everything (memory pressure, queue empty). Throws
  /// [ModelResidencyException] for the first unloader that failed.
  Future<void> releaseAll() => _serialized(() async {
    ModelResidencyException? first;
    for (final k in _loaded.toList()) {
      try {
        await _unload(k);
      } on ModelResidencyException catch (e) {
        first ??= e;
      }
    }
    if (first != null) throw first;
  });

  Set<ResidentModel> get loaded => Set.unmodifiable(_loaded);

  Future<void> _unload(ResidentModel kind) async {
    try {
      await _unloaders[kind]?.call();
    } on Object catch (e) {
      throw ModelResidencyException(kind, e.runtimeType.toString());
    }
    _loaded.remove(kind);
  }

  Future<void> _serialized(Future<void> Function() body) {
    final run = _tail.then((_) => body());
    // The chain must survive a failed transition.
    _tail = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }
}
