import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/backend_policy.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/features/extraction/data/ffi_llm_runtime.dart';
import 'package:vaultvoice/features/extraction/data/native_device_capabilities.dart';
import 'package:vaultvoice/features/extraction/domain/llm_backend_policy.dart';
import 'package:vaultvoice/features/extraction/domain/llm_service.dart';
import 'package:vaultvoice/features/extraction/domain/memory_planner.dart';
import 'package:vaultvoice/features/pipeline/data/active_engines.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_step.dart';
import 'package:vv_native/vv_native.dart';

part 'preview_llm_engine.g.dart';

/// The UI-isolate LLM behind `llmEngineProvider` in the real app
/// (integration wave 3): the PRF-07 profile editor's "Test on a recording"
/// preview.
///
/// Runs the active installed LLM (the selection FND-11 publishes for the
/// worker), loads it per preview run and unloads it right after, and refuses
/// while the pipeline has a job in an active step — the worker may hold the
/// STT or LLM model then, and two heavy models must never be resident
/// together (AGENTS.md memory rule). PRODUCT-DECISION: the preview reports
/// "not enough memory" ([OutOfMemoryFailure]) instead of queueing.
final class PreviewLlmEngine implements LlmEngine {
  PreviewLlmEngine({
    required this.resolve,
    required this.create,
    required this.pipelineBusy,
  });

  final Future<ActiveModel?> Function() resolve;
  final LlmService Function(ActiveModel model) create;

  /// True while a pipeline job is in an active (model-using) state.
  final Future<bool> Function() pipelineBusy;

  @override
  Future<Result<String>> generate(
    LlmRequest request, {
    CancelToken? cancel,
    void Function(String token)? onToken,
  }) async {
    if (await pipelineBusy()) return const Err(OutOfMemoryFailure());
    final model = await resolve();
    if (model == null) return const Err(ModelMissingFailure('llm'));
    final service = create(model);
    try {
      return await service.generate(request, cancel: cancel, onToken: onToken);
    } finally {
      service.unload();
    }
  }
}

/// Whether any job of [db] is in an active pipeline state.
Future<bool> pipelineHasActiveJob(VaultVoiceDatabase db) async {
  final active = {
    for (final s in JobState.values)
      if (s.isActive) s.name,
  };
  final jobs = await db.select(db.jobs).get();
  return jobs.any((j) => active.contains(j.status));
}

/// Production `llmEngineProvider` override (see `bootstrap`).
@Riverpod(keepAlive: true)
LlmEngine previewLlmEngine(Ref ref) {
  final db = ref.watch(vaultVoiceDatabaseProvider);
  final hostPath = ref.watch(nativeLibraryPathProvider);
  VvNative? native;
  VvNative open() => native ??= VvNative.open(hostPath: hostPath);
  return PreviewLlmEngine(
    pipelineBusy: () => pipelineHasActiveJob(db),
    resolve: () async {
      final paths = await ref.read(storagePathsProvider.future);
      return await InstalledModelResolver(
        db: db,
        paths: paths,
      ).resolve(HeavyModel.llm);
    },
    create: (m) {
      final vv = open();
      final caps = NativeDeviceCapabilities(vv);
      return LlmService(
        runtime: FfiLlmRuntime(vv),
        modelPath: m.path,
        // The editor is on screen: foreground policy (iOS Metal allowed).
        backend: () =>
            chooseLlmBackend(
              caps: caps,
              platform: _platform(),
              foreground: true,
            ) ??
            const LlmBackendChoice(useGpu: false, reason: 'cpu-unsupported'),
        contextSize: m.contextSize,
        loadGate: (requested) {
          final plan = planLlmLoad(
            modelFileBytes: m.sizeBytes,
            availableBytes: vv.deviceMemory.$2,
            requestedContext: requested,
          );
          return plan.allowed
              ? Ok(plan.contextSize)
              : const Err(OutOfMemoryFailure());
        },
      );
    },
  );
}

DevicePlatform _platform() => Platform.isIOS
    ? DevicePlatform.ios
    : Platform.isAndroid
    ? DevicePlatform.android
    : DevicePlatform.host;
