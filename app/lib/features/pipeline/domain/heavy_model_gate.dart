import 'package:vaultvoice/features/pipeline/domain/pipeline_step.dart';

/// Releases a loaded model (unload whisper context / llama model).
typedef ModelRelease = Future<void> Function(HeavyModel model);

/// Ensures STT and LLM are never resident together: acquiring one releases
/// the other first. LLM-07 supplies the real release (engine unload).
class HeavyModelGate {
  HeavyModelGate({ModelRelease? release}) : _release = release;

  final ModelRelease? _release;
  HeavyModel? _loaded;

  /// The model currently considered loaded.
  HeavyModel? get loaded => _loaded;

  /// Makes [model] the only loaded model (no-op for null or the same one).
  Future<void> use(HeavyModel? model) async {
    if (model == null || model == _loaded) return;
    await releaseAll();
    _loaded = model;
  }

  /// Releases whatever is loaded.
  Future<void> releaseAll() async {
    final current = _loaded;
    if (current == null) return;
    _loaded = null;
    await _release?.call(current);
  }
}
