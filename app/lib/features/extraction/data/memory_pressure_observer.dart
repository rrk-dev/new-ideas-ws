import 'package:flutter/widgets.dart';
import 'package:vaultvoice/features/extraction/domain/llm_service.dart';
import 'package:vaultvoice/features/extraction/domain/model_residency.dart';

/// Forwards OS memory warnings to the LLM (LLM-07).
///
/// Flutter delivers both platforms' signals as `didHaveMemoryPressure`:
/// iOS `UIApplicationDidReceiveMemoryWarningNotification` and Android
/// `onTrimMemory` (critical levels) / `onLowMemory` (the engine sends
/// `SystemChannels.system` "memoryPressure"; note `TRIM_MEMORY_RUNNING_*`
/// is not delivered on API 34+). Verified against Flutter 3.47.
final class LlmMemoryPressureObserver with WidgetsBindingObserver {
  LlmMemoryPressureObserver(this._service, {this.residency});

  final LlmService _service;
  final ModelResidency? residency;

  void attach() => WidgetsBinding.instance.addObserver(this);
  void detach() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didHaveMemoryPressure() {
    _service.onMemoryPressure();
    residency?.release(ResidentModel.llm);
  }
}
