import 'dart:async';

import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/models/data/model_downloader.dart';
import 'package:vaultvoice/features/models/domain/download_state.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';

/// Scriptable [ModelDownloader] for UI tests: [blocks] decide the plan,
/// [download] records the call and emits a `downloading` progress event;
/// tests finish downloads with [complete].
class FakeModelDownloader implements ModelDownloader {
  FakeModelDownloader({
    this.blocks = const {},
    this.freeBytes = 64 * 1000 * 1000 * 1000,
  });

  Set<ModelDownloadBlock> blocks;
  int? freeBytes;

  final started = <({String id, bool? allowCellular, bool allowLowPower})>[];
  final paused = <String>[];
  final cancelled = <String>[];
  final _results = <String, Completer<Result<InstalledModelRow>>>{};
  final _progress = StreamController<DownloadProgress>.broadcast();
  final _latest = <String, DownloadProgress>{};

  void emit(DownloadProgress p) {
    _latest[p.modelId] = p;
    _progress.add(p);
  }

  /// Finishes the download of [id] with [result] (default: a failure-free
  /// placeholder failure is not used — pass an [Err] to fail it).
  void complete(String id, Result<InstalledModelRow> result) =>
      _results.remove(id)?.complete(result);

  @override
  void pauseAll() => paused.addAll(_results.keys);

  @override
  Stream<DownloadProgress> get progress => _progress.stream;

  @override
  DownloadProgress? latest(String modelId) => _latest[modelId];

  @override
  bool isActive(String modelId) => _results.containsKey(modelId);

  @override
  Future<DownloadPlan> plan(
    CatalogModel model, {
    bool? allowCellular,
    bool allowLowPower = false,
  }) async => DownloadPlan(
    modelId: model.id,
    totalBytes: model.size,
    alreadyDownloadedBytes: 0,
    requiredFreeBytes: model.size,
    freeBytes: freeBytes,
    blocks: {
      for (final b in blocks)
        if (!(b == ModelDownloadBlock.unmeteredNetworkRequired &&
                allowCellular == true) &&
            !(b == ModelDownloadBlock.lowPowerMode && allowLowPower))
          b,
    },
  );

  @override
  Future<Result<InstalledModelRow>> download(
    CatalogModel model, {
    bool? allowCellular,
    bool allowLowPower = false,
  }) {
    final running = _results[model.id];
    if (running != null) return running.future;
    started.add((
      id: model.id,
      allowCellular: allowCellular,
      allowLowPower: allowLowPower,
    ));
    final c = _results[model.id] = Completer<Result<InstalledModelRow>>();
    emit(
      DownloadProgress(
        modelId: model.id,
        phase: DownloadPhase.downloading,
        receivedBytes: model.size ~/ 4,
        totalBytes: model.size,
      ),
    );
    return c.future;
  }

  @override
  void pause(String modelId) {
    paused.add(modelId);
    complete(modelId, const Err(CancelledFailure()));
  }

  @override
  Future<void> cancel(String modelId) async {
    cancelled.add(modelId);
    complete(modelId, const Err(CancelledFailure()));
  }

  @override
  Future<List<String>> pendingModelIds() async => const [];

  @override
  Future<List<String>> resumePending(ModelCatalog catalog) async => const [];
}
