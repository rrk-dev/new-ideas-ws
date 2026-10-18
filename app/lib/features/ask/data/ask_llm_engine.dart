import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/features/ask/domain/ask_service.dart';
import 'package:vaultvoice/features/extraction/domain/llm_service.dart';
import 'package:vaultvoice/features/pipeline/data/active_engines.dart';

/// The UI-isolate LLM behind Ask: always the 3B (`kAskModelId`), kept loaded
/// between questions until [unload] (the `AskService` idle timer and the
/// residency hook call it). Never the user's active extraction model.
final class AskLlmEngine implements LlmEngine {
  AskLlmEngine({required this.resolve, required this.create});

  final Future<ActiveModel?> Function() resolve;
  final LlmService Function(ActiveModel model) create;

  LlmService? _service;
  String? _path;
  bool _foreground = true;

  @override
  Future<Result<String>> generate(
    LlmRequest request, {
    CancelToken? cancel,
    void Function(String token)? onToken,
  }) async {
    final model = await resolve();
    if (model == null) return const Err(ModelMissingFailure(kAskModelId));
    var service = _service;
    if (service == null || _path != model.path) {
      service?.unload();
      service = _service = create(model);
      _path = model.path;
      if (!_foreground) service.onBackgrounded();
    }
    return await service.generate(request, cancel: cancel, onToken: onToken);
  }

  void unload() => _service?.unload();

  void onMemoryPressure() => _service?.onMemoryPressure();

  void setForeground({required bool foreground}) {
    _foreground = foreground;
    if (foreground) {
      _service?.onForegrounded();
    } else {
      _service?.onBackgrounded();
    }
  }
}
