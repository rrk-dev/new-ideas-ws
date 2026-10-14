/// Kinds of large models that compete for RAM.
enum ResidentModel { stt, llm }

/// Enforces AGENTS.md "never hold STT and LLM models in memory at the same
/// time" (LLM-07): engines register an unloader; before loading model kind
/// X, [acquire] unloads every other registered kind.
final class ModelResidency {
  final Map<ResidentModel, void Function()> _unloaders = {};
  final Set<ResidentModel> _loaded = {};

  /// Registers how to unload [kind] (e.g. `LlmService.unload`).
  void register(ResidentModel kind, void Function() unload) =>
      _unloaders[kind] = unload;

  /// Call right before loading [kind]: unloads the others.
  void acquire(ResidentModel kind) {
    for (final other in ResidentModel.values) {
      if (other != kind && _loaded.remove(other)) _unloaders[other]?.call();
    }
    _loaded.add(kind);
  }

  /// Call after [kind] was unloaded by its owner.
  void release(ResidentModel kind) => _loaded.remove(kind);

  /// Unloads everything (memory pressure, queue empty).
  void releaseAll() {
    for (final k in _loaded.toList()) {
      _unloaders[k]?.call();
    }
    _loaded.clear();
  }

  Set<ResidentModel> get loaded => Set.unmodifiable(_loaded);
}
