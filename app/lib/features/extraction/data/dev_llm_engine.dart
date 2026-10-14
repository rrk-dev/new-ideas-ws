import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/features/extraction/data/ffi_llm_runtime.dart';
import 'package:vaultvoice/features/extraction/data/memory_pressure_observer.dart';
import 'package:vaultvoice/features/extraction/domain/llm_backend_policy.dart';
import 'package:vaultvoice/features/extraction/domain/llm_service.dart';
import 'package:vaultvoice/features/extraction/domain/memory_planner.dart';
import 'package:vaultvoice/features/extraction/domain/model_residency.dart';
import 'package:vv_native/vv_native.dart';

/// Dev-flavor wiring of the real LLM engine (LLM-04) for the debug screen
/// and device rows: `--dart-define=VV_DEV_LLM_MODEL=<file in Documents>`.
/// Production wiring (active model from MDL-*, tiering LLM-07) replaces this.
Future<List<Override>> devLlmOverrides() async {
  const name = String.fromEnvironment('VV_DEV_LLM_MODEL');
  if (name.isEmpty) return const [];
  final docs = await getApplicationDocumentsDirectory();
  final path = name.startsWith('/') ? name : '${docs.path}/$name';
  if (!File(path).existsSync()) return const [];
  final service = llmServiceForPlatform(VvNative.open(), path);
  return [llmEngineProvider.overrideWithValue(service)];
}

/// An [LlmService] whose backend follows [LlmBackendPolicy] and the app
/// lifecycle (iOS background ⇒ CPU; restart on CPU mid-run), with the
/// LLM-07 pre-load memory check, STT/LLM residency and memory-pressure
/// handling.
LlmService llmServiceForPlatform(
  VvNative native,
  String modelPath, {
  int contextSize = 4096,
  ModelResidency? residency,
}) {
  final modelBytes = File(modelPath).lengthSync();
  var foreground = true;
  final platform = Platform.isIOS
      ? LlmPlatform.ios
      : Platform.isAndroid
      ? LlmPlatform.android
      : LlmPlatform.host;
  late final LlmService service;
  service = LlmService(
    runtime: FfiLlmRuntime(native),
    modelPath: modelPath,
    // Android: CPU until a GPU is allowlisted (ADR-LLM-03); LLM-07 adds the
    // tiering + guard wiring.
    backend: () => const LlmBackendPolicy().choose(
      platform: platform,
      foreground: foreground,
      gpuAllowed: platform != LlmPlatform.android,
    ),
    contextSize: contextSize,
    loadGate: (requested) {
      final plan = planLlmLoad(
        modelFileBytes: modelBytes,
        availableBytes: native.deviceMemory.$2,
        requestedContext: requested,
      );
      return plan.allowed
          ? Ok(plan.contextSize)
          : const Err(OutOfMemoryFailure());
    },
    onBeforeLoad: () => residency?.acquire(ResidentModel.llm),
  );
  residency?.register(ResidentModel.llm, service.unload);
  LlmMemoryPressureObserver(service, residency: residency).attach();
  AppLifecycleListener(
    onHide: () {
      foreground = false;
      service.onBackgrounded();
    },
    onShow: () {
      foreground = true;
      service.onForegrounded();
    },
  );
  return service;
}
