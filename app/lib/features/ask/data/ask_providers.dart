import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/db/enums.dart' show ModelType;
import 'package:vaultvoice/core/diagnostics/diagnostics_providers.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/backend_policy.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/features/ask/data/ask_llm_engine.dart';
import 'package:vaultvoice/features/ask/data/db_ask_history.dart';
import 'package:vaultvoice/features/ask/data/db_ask_retriever.dart';
import 'package:vaultvoice/features/ask/domain/ask_availability.dart';
import 'package:vaultvoice/features/ask/domain/ask_history.dart';
import 'package:vaultvoice/features/ask/domain/ask_models.dart';
import 'package:vaultvoice/features/ask/domain/ask_service.dart';
import 'package:vaultvoice/features/extraction/data/ffi_llm_runtime.dart';
import 'package:vaultvoice/features/extraction/data/native_device_capabilities.dart';
import 'package:vaultvoice/features/extraction/domain/device_tiering.dart';
import 'package:vaultvoice/features/extraction/domain/llm_backend_policy.dart';
import 'package:vaultvoice/features/extraction/domain/llm_service.dart';
import 'package:vaultvoice/features/extraction/domain/memory_planner.dart';
import 'package:vaultvoice/features/extraction/domain/model_residency.dart';
import 'package:vaultvoice/features/models/data/model_state_providers.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart'
    hide ModelType;
import 'package:vaultvoice/features/pipeline/data/active_engines.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_providers.dart';
import 'package:vaultvoice/features/profiles/data/profile_providers.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';
import 'package:vv_native/vv_native.dart';

part 'ask_providers.g.dart';

/// `ask.enabled` (default off on iOS/Android, on for macOS): the whole Ask
/// entry is hidden while false. PRODUCT-DECISION (ASK-04): the ASK-03
/// quality gates are not met; the owner enabled it on macOS (2026-10-18).
@riverpod
bool askEnabled(Ref ref) =>
    ref.watch(settingStateProvider(SettingKeys.askEnabled)).value?.value ==
    true;

/// `ask.save_history` (default on, PRODUCT-DECISION human 2026-10-17).
@riverpod
bool askSaveHistoryEnabled(Ref ref) =>
    ref.watch(settingStateProvider(SettingKeys.askSaveHistory)).value?.value !=
    false;

/// Device tier × installed 3B (ADR-ASK-02).
@riverpod
Future<AskAvailability> askAvailabilityState(Ref ref) async {
  final device = await ref.watch(deviceProfileProvider.future);
  final installed = await ref.watch(installedModelsProvider.future);
  return askAvailability(
    tier: device == null ? null : tierForRam(device.totalRamBytes),
    modelInstalled: installed.any((m) => m.id == kAskModelId),
  );
}

/// The catalog entry of the Ask model (size for the download prompt), or
/// null when the active catalog does not list it.
@riverpod
Future<CatalogModel?> askModelEntry(Ref ref) async {
  final catalog = await ref.watch(activeCatalogProvider.future);
  if (catalog == null) return null;
  for (final m in catalog.models) {
    if (m.id == kAskModelId) return m;
  }
  return null;
}

@Riverpod(keepAlive: true)
AskHistoryStore askHistoryStore(Ref ref) =>
    DbAskHistory(ref.watch(vaultVoiceDatabaseProvider));

/// Saved chats, newest first.
@riverpod
Future<List<AskThread>> askThreads(Ref ref) async {
  final store = ref.watch(askHistoryStoreProvider);
  await store.deleteOlderThan(DateTime.now().subtract(kAskHistoryExpiry));
  return (await store.threads()).valueOrNull ?? const [];
}

/// The Ask engine: retrieval over the encrypted DB, the 3B on this device,
/// no network. Rebuilt when the tier or the installed model changes.
@riverpod
Future<AskEngine> askEngine(Ref ref) async {
  final availability = await ref.watch(askAvailabilityStateProvider.future);
  final db = ref.watch(vaultVoiceDatabaseProvider);
  final hostPath = ref.watch(nativeLibraryPathProvider);
  VvNative? native;
  VvNative open() => native ??= VvNative.open(hostPath: hostPath);

  final llm = AskLlmEngine(
    resolve: () async {
      final paths = await ref.read(storagePathsProvider.future);
      final row = (await db.modelsRepository.get(kAskModelId)).valueOrNull;
      if (row == null || row.type != ModelType.llm) return null;
      if (p.isAbsolute(row.path)) return null;
      final path = p.normalize(p.join(paths.root, row.path));
      if (!p.isWithin(paths.root, path) || !File(path).existsSync()) {
        return null;
      }
      return ActiveModel(
        id: row.id,
        path: path,
        sizeBytes: row.size,
        contextSize: kAskContextSize,
      );
    },
    create: (m) {
      final vv = open();
      final caps = NativeDeviceCapabilities(vv);
      return LlmService(
        runtime: FfiLlmRuntime(vv),
        modelPath: m.path,
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
  final residency = ModelResidency();
  late final AskService service;
  residency.register(ResidentModel.llm, () {
    service.cancelActive();
    llm.unload();
  });
  service = AskService(
    retriever: DbAskRetriever(db),
    engine: llm,
    grammarConverter: ref.watch(schemaGrammarConverterProvider),
    residency: residency,
    deviceSupportsAsk: () => availability != AskAvailability.deviceTooLow,
    modelInstalled: () => availability == AskAvailability.ready,
    pipelineBusy: () =>
        ref
            .read(processingViewsProvider)
            .value
            ?.any((v) => v.job.state.isActive) ??
        false,
    availableBytes: () => open().deviceMemory.$2,
    log: ref.watch(loggerProvider),
    history: ref.watch(askHistoryStoreProvider),
    saveHistory: () => ref.read(askSaveHistoryEnabledProvider),
  );
  final observer = _AskMemoryObserver(service, llm)..attach();
  ref.onDispose(() {
    observer.detach();
    service.cancelActive();
    llm.unload();
  });
  return service;
}

DevicePlatform _platform() => Platform.isIOS
    ? DevicePlatform.ios
    : Platform.isAndroid
    ? DevicePlatform.android
    : DevicePlatform.host;

/// OS memory warning: cancel a running Ask and free the 3B (LLM-07).
final class _AskMemoryObserver with WidgetsBindingObserver {
  _AskMemoryObserver(this._service, this._llm);

  final AskService _service;
  final AskLlmEngine _llm;

  void attach() => WidgetsBinding.instance.addObserver(this);
  void detach() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didHaveMemoryPressure() {
    _service.cancelActive();
    _llm
      ..onMemoryPressure()
      ..unload();
  }
}
