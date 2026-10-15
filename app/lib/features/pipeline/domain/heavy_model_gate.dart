import 'package:vaultvoice/features/pipeline/domain/pipeline_step.dart';

/// Releases a loaded model (unload whisper context / llama model).
typedef ModelRelease = Future<void> Function(HeavyModel model);

/// Ensures STT and LLM are never resident together: acquiring one releases
/// the other first. LLM-07 supplies the real release (engine unload).
class HeavyModelGate {
  HeavyModelGate({this.release, this.isBlocked});

  /// True while another isolate (the profile preview) holds a heavy model;
  /// [use] then refuses so two models are never resident together.
  final Future<bool> Function()? isBlocked;

  /// Called with the model being unloaded.
  final ModelRelease? release;
  HeavyModel? _loaded;

  /// The model currently considered loaded.
  HeavyModel? get loaded => _loaded;

  /// Makes [model] the only loaded model (no-op for null or the same one).
  /// Throws (leaving the previous model loaded) when its release fails.
  Future<void> use(HeavyModel? model) async {
    if (model == null) return;
    if (await isBlocked?.call() ?? false) throw const HeavyModelBusyException();
    if (model == _loaded) return;
    await releaseAll();
    _loaded = model;
  }

  /// Releases whatever is loaded.
  ///
  /// If the release throws, the model is still considered loaded (it may
  /// still be resident) and the error is rethrown, so the next [use] or
  /// [releaseAll] tries the release again and the other model is never
  /// loaded beside it.
  Future<void> releaseAll() async {
    final current = _loaded;
    if (current == null) return;
    _loaded = null;
    try {
      await release?.call(current);
    } on Object {
      _loaded = current;
      rethrow;
    }
  }
}

/// A heavy model is in use outside the worker (profile preview); the step is
/// retried later.
class HeavyModelBusyException implements Exception {
  const HeavyModelBusyException();

  @override
  String toString() => 'HeavyModelBusyException';
}
