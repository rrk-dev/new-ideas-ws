import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/repositories/models_repository.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/clock.dart';
import 'package:vaultvoice/features/models/data/catalog_config.dart';
import 'package:vaultvoice/features/models/data/model_installer.dart';
import 'package:vaultvoice/features/models/domain/download_platform.dart';
import 'package:vaultvoice/features/models/domain/download_policy.dart';
import 'package:vaultvoice/features/models/domain/download_state.dart';
import 'package:vaultvoice/features/models/domain/download_transport.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';
import 'package:vaultvoice/features/models/domain/model_file_verifier.dart';

/// Checks a finished partial file against its catalog entry.
typedef ModelFileCheck = Future<Result<void>> Function(
  String path,
  CatalogModel model,
);

/// Streams [path] through SHA-256 + exact size check on a background isolate
/// (never the UI isolate — a 2 GB hash takes seconds).
Future<Result<void>> verifyModelFileInIsolate(
  String path,
  CatalogModel model,
) => Isolate.run(() => verifyModelBytes(File(path).openRead(), model));

/// Downloads catalog models into `<appSupport>/vv/models/` (MDL-02).
///
/// Layout: `models/.partial/<id>` (bytes so far; its length *is* the resume
/// offset, so a kill at any point loses nothing already written) +
/// `models/.partial/<id>.json` (which model/sha the bytes belong to, ETag).
/// Finished files are size + SHA-256 checked in an isolate, then atomically
/// renamed to `models/<id>/<file>` and recorded in `models_installed`.
///
/// Preconditions: free space ≥ `remaining × 1.1 + 200 MB`; an unmetered
/// network unless cellular is allowed; low-power mode needs an explicit OK.
/// Retries: every catalog URL per attempt, then 1 s → 60 s backoff, at most
/// [kMaxDownloadRetries] retries. A hash mismatch deletes the file and
/// re-downloads from zero once, then fails.
class ModelDownloader {
  ModelDownloader({
    required this._paths,
    required this._models,
    required this._transport,
    required this._device,
    this._keepAlive = const NoDownloadKeepAlive(),
    this._clock = const SystemClock(),
    Future<bool> Function()? cellularAllowedSetting,
    Future<bool> Function()? networkDisabled,
    this._verify = verifyModelFileInIsolate,
    Future<void> Function(Duration)? delay,
    this._headers = kAnonymousRequestHeaders,
  }) : _cellularSetting = cellularAllowedSetting ?? _no,
       _networkDisabled = networkDisabled ?? _no,
       _delay = delay ?? Future<void>.delayed;

  final StoragePaths _paths;
  final ModelsRepository _models;
  final DownloadTransport _transport;
  final DownloadDeviceInfo _device;
  final DownloadKeepAlive _keepAlive;
  final Clock _clock;
  final Future<bool> Function() _cellularSetting;

  /// `network_disabled` (user offline mode / MDM, MDL-04): refuse up front.
  final Future<bool> Function() _networkDisabled;
  final ModelFileCheck _verify;
  final Future<void> Function(Duration) _delay;
  final Map<String, String> _headers;

  static Future<bool> _no() async => false;

  /// Progress is re-emitted at most every this many bytes.
  static const int _progressStepBytes = 1024 * 1024;

  late final ModelInstaller _installer = ModelInstaller(
    paths: _paths,
    models: _models,
    device: _device,
    clock: _clock,
  );

  final _jobs = <String, _Job>{};
  final StreamController<DownloadProgress> _progress =
      StreamController.broadcast();
  final _latest = <String, DownloadProgress>{};

  /// Every progress change of every download.
  Stream<DownloadProgress> get progress => _progress.stream;

  /// Last known progress of [modelId], if a download ran in this process.
  DownloadProgress? latest(String modelId) => _latest[modelId];

  /// Whether [modelId] is downloading right now.
  bool isActive(String modelId) => _jobs.containsKey(modelId);

  String get _partialDir => p.join(_paths.modelsDir, '.partial');
  File _partial(String id) => File(p.join(_partialDir, _segment(id)));
  File _meta(String id) => File(p.join(_partialDir, '${_segment(id)}.json'));

  /// What downloading [model] needs right now (size up front, blocks).
  Future<DownloadPlan> plan(
    CatalogModel model, {
    bool? allowCellular,
    bool allowLowPower = false,
  }) async {
    final existing = await _validPartialLength(model);
    final required = requiredFreeBytes(model.size - existing);
    await Directory(_paths.modelsDir).create(recursive: true);
    final free = await _device.freeBytes(_paths.modelsDir);
    final disabled = await _networkDisabled();
    final net = disabled
        ? const NetworkStatus(connected: false, unmetered: false)
        : await _device.networkStatus();
    final cellular = allowCellular ?? await _cellularSetting();
    return DownloadPlan(
      modelId: model.id,
      totalBytes: model.size,
      alreadyDownloadedBytes: existing,
      requiredFreeBytes: required,
      freeBytes: free,
      blocks: {
        if (free == null || free < required)
          ModelDownloadBlock.insufficientSpace,
        if (!net.connected) ModelDownloadBlock.offline,
        if (net.connected && !net.unmetered && !cellular)
          ModelDownloadBlock.unmeteredNetworkRequired,
        if (net.lowPowerMode && !allowLowPower) ModelDownloadBlock.lowPowerMode,
      },
    );
  }

  /// Downloads, verifies and installs [model]. A second call for the same
  /// id while it runs returns the same future.
  ///
  /// [allowCellular]: per-download opt-in (after showing the size); null
  /// uses the saved setting (default false → Wi-Fi only).
  Future<Result<InstalledModelRow>> download(
    CatalogModel model, {
    bool? allowCellular,
    bool allowLowPower = false,
  }) {
    final running = _jobs[model.id];
    if (running != null) return running.result;
    final job = _Job();
    _jobs[model.id] = job;
    return job.result = _run(
      model,
      job.control,
      allowCellular,
      allowLowPower,
    ).whenComplete(() => _jobs.remove(model.id));
  }

  /// Stops [modelId] and keeps the partial file for a later resume.
  void pause(String modelId) => _jobs[modelId]?.control.pause();

  /// Stops [modelId] (if running) and deletes its partial file.
  Future<void> cancel(String modelId) async {
    final job = _jobs[modelId];
    if (job != null) {
      job.control.cancel();
      await job.result;
    } else {
      await _deletePartial(modelId);
    }
  }

  /// Ids with a partial download on disk (e.g. after the app was killed).
  Future<List<String>> pendingModelIds() async {
    final dir = Directory(_partialDir);
    if (!dir.existsSync()) return const [];
    return [
      await for (final e in dir.list())
        if (e is File && e.path.endsWith('.json'))
          p.basenameWithoutExtension(e.path),
    ]..sort();
  }

  /// Restarts every pending download that still matches [catalog] (same id
  /// and SHA-256) and deletes stale partials. Returns the started ids; the
  /// downloads continue in the background (watch [progress]).
  Future<List<String>> resumePending(ModelCatalog catalog) async {
    final started = <String>[];
    for (final id in await pendingModelIds()) {
      final model = catalog.byId(id);
      if (model == null || await _readMeta(model) == null) {
        await _deletePartial(id);
        continue;
      }
      started.add(id);
      unawaited(download(model));
    }
    return started;
  }

  Future<Result<InstalledModelRow>> _run(
    CatalogModel model,
    DownloadControl control,
    bool? allowCellularArg,
    bool allowLowPower,
  ) async {
    final id = model.id;
    _emit(model, DownloadPhase.checking, 0);
    try {
      await Directory(_partialDir).create(recursive: true);
      await _device.excludeFromBackup(_paths.modelsDir);
      final allowCellular = allowCellularArg ?? await _cellularSetting();
      final plan = await this.plan(
        model,
        allowCellular: allowCellular,
        allowLowPower: allowLowPower,
      );
      if (plan.blocks.isNotEmpty) {
        final block = _firstBlock(plan.blocks);
        return _fail(
          model,
          ModelDownloadFailure(
            id,
            block,
            requiredBytes: plan.requiredFreeBytes,
            freeBytes: plan.freeBytes,
          ),
          plan.alreadyDownloadedBytes,
        );
      }
      var meta = await _readMeta(model) ?? _PartialMeta.of(model);
      await _writeMeta(meta);

      await _keepAlive.start(model.displayName);
      var retry = 0;
      var integrityRetried = false;
      while (true) {
        if (control.isStopped) return await _stopped(model, control);
        var offset = await _length(_partial(id));
        if (offset > model.size) {
          await _partial(id).delete();
          offset = 0;
        }
        var completed = offset == model.size;
        var anyRetryable = false;
        Failure? last;
        var lastEmitted = offset;
        for (final uri in model.urls) {
          if (completed) break;
          _emit(model, DownloadPhase.downloading, offset, retry: retry);
          final outcome = await _transport.fetch(
            TransportRequest(
              modelId: id,
              uri: uri,
              partial: _partial(id),
              offset: offset,
              totalBytes: model.size,
              headers: _headers,
              allowCellular: allowCellular,
              ifRange: meta.etag,
            ),
            control: control,
            onProgress: (n) {
              if (n - lastEmitted >= _progressStepBytes || n == model.size) {
                lastEmitted = n;
                _emit(model, DownloadPhase.downloading, n, retry: retry);
                unawaited(_keepAlive.update(n, model.size));
              }
            },
            checkpoint: () => _networkCheckpoint(id, allowCellular),
          );
          switch (outcome) {
            case TransportCompleted(:final validator):
              completed = true;
              if (validator != meta.etag) {
                meta = meta.withEtag(validator);
                await _writeMeta(meta);
              }
            case TransportRangeNotSatisfiable():
              if (await _length(_partial(id)) == model.size) {
                completed = true;
              } else {
                await _partial(id).delete();
                anyRetryable = true;
                last = const NetworkFailure('http 416');
              }
            case TransportStopped():
              return await _stopped(model, control);
            case TransportBlocked(:final failure):
              final have = await _length(_partial(id));
              _emit(model, DownloadPhase.paused, have, failure: failure);
              return Err(failure);
            case TransportFailed(:final failure, :final retryable):
              last = failure;
              anyRetryable |= retryable;
          }
          offset = await _length(_partial(id));
        }

        if (completed) {
          _emit(model, DownloadPhase.verifying, model.size);
          final verified = await _verify(_partial(id).path, model);
          if (verified.isOk) return await _install(model);
          // Corrupt (hash or size mismatch): delete and re-download from
          // zero once; a second mismatch is an error.
          await _partial(id).delete();
          meta = _PartialMeta.of(model);
          await _writeMeta(meta);
          if (integrityRetried) {
            await _deletePartial(id);
            return _fail(model, verified.failureOrNull!, 0);
          }
          integrityRetried = true;
          continue;
        }
        final have = await _length(_partial(id));
        if (!anyRetryable) {
          return _fail(
            model,
            ModelDownloadFailure(
              id,
              ModelDownloadBlock.allUrlsRejected,
              cause: last,
            ),
            have,
          );
        }
        retry++;
        if (retry > kMaxDownloadRetries) {
          return _fail(
            model,
            ModelDownloadFailure(
              id,
              ModelDownloadBlock.retriesExhausted,
              cause: last,
            ),
            have,
          );
        }
        _emit(model, DownloadPhase.retrying, have, retry: retry, failure: last);
        await Future.any([_delay(retryDelay(retry)), control.stopped]);
      }
    } on FileSystemException catch (e) {
      return _fail(
        model,
        StorageFailure('model download io: ${e.osError?.errorCode ?? 0}'),
        0,
      );
    } finally {
      await _keepAlive.stop();
    }
  }

  Future<Failure?> _networkCheckpoint(String id, bool allowCellular) async {
    final net = await _device.networkStatus();
    if (net.connected && !net.unmetered && !allowCellular) {
      return ModelDownloadFailure(
        id,
        ModelDownloadBlock.unmeteredNetworkRequired,
      );
    }
    return null;
  }

  Future<Result<InstalledModelRow>> _install(CatalogModel model) async {
    _emit(model, DownloadPhase.installing, model.size);
    final installed = await _installer.install(model, _partial(model.id));
    if (!installed.isOk) {
      await _deletePartial(model.id);
      return _fail(model, installed.failureOrNull!, 0);
    }
    await _deleteIfExists(_meta(model.id));
    _emit(model, DownloadPhase.installed, model.size);
    return installed;
  }

  Future<Result<InstalledModelRow>> _stopped(
    CatalogModel model,
    DownloadControl control,
  ) async {
    if (control.isCancelled) {
      await _deletePartial(model.id);
      _emit(model, DownloadPhase.cancelled, 0);
      return const Err(CancelledFailure());
    }
    _emit(model, DownloadPhase.paused, await _length(_partial(model.id)));
    return const Err(CancelledFailure());
  }

  Err<InstalledModelRow> _fail(CatalogModel model, Failure f, int have) {
    _emit(model, DownloadPhase.failed, have, failure: f);
    return Err(f);
  }

  void _emit(
    CatalogModel model,
    DownloadPhase phase,
    int received, {
    int retry = 0,
    Failure? failure,
  }) {
    final progress = DownloadProgress(
      modelId: model.id,
      phase: phase,
      receivedBytes: received,
      totalBytes: model.size,
      retry: retry,
      failure: failure,
    );
    _latest[model.id] = progress;
    _progress.add(progress);
  }

  /// Length of the partial when it belongs to [model], else 0.
  Future<int> _validPartialLength(CatalogModel model) async {
    if (await _readMeta(model) == null) return 0;
    final len = await _length(_partial(model.id));
    return len > model.size ? 0 : len;
  }

  /// The partial's metadata when it matches [model] (same sha/size/file);
  /// a mismatching partial (older catalog version) is deleted.
  Future<_PartialMeta?> _readMeta(CatalogModel model) async {
    final f = _meta(model.id);
    if (!f.existsSync()) {
      await _deleteIfExists(_partial(model.id));
      return null;
    }
    final meta = _PartialMeta.tryParse(await f.readAsString());
    if (meta == null ||
        meta.sha256 != model.sha256 ||
        meta.size != model.size ||
        meta.file != model.file) {
      await _deletePartial(model.id);
      return null;
    }
    return meta;
  }

  Future<void> _writeMeta(_PartialMeta meta) async {
    final tmp = File('${_meta(meta.id).path}.tmp');
    await tmp.writeAsString(meta.encode(), flush: true);
    await tmp.rename(_meta(meta.id).path);
  }

  Future<void> _deletePartial(String id) async {
    await _deleteIfExists(_partial(id));
    await _deleteIfExists(_meta(id));
  }

  static Future<void> _deleteIfExists(File f) async {
    if (f.existsSync()) await f.delete();
  }

  static Future<int> _length(File f) async =>
      f.existsSync() ? await f.length() : 0;

  static String _segment(String id) => ModelInstaller.segment(id);

  static ModelDownloadBlock _firstBlock(Set<ModelDownloadBlock> blocks) {
    for (final b in ModelDownloadBlock.values) {
      if (blocks.contains(b)) return b;
    }
    throw StateError('no block');
  }
}

class _Job {
  final control = DownloadControl();
  late Future<Result<InstalledModelRow>> result;
}

/// Sidecar of a partial download: which catalog entry the bytes belong to.
class _PartialMeta {
  const _PartialMeta({
    required this.id,
    required this.sha256,
    required this.size,
    required this.file,
    this.etag,
  });

  factory _PartialMeta.of(CatalogModel m) =>
      _PartialMeta(id: m.id, sha256: m.sha256, size: m.size, file: m.file);

  static _PartialMeta? tryParse(String s) {
    try {
      final j = jsonDecode(s);
      if (j is! Map<String, Object?> || j['v'] != 1) return null;
      final id = j['id'];
      final sha = j['sha256'];
      final size = j['size'];
      final file = j['file'];
      final etag = j['etag'];
      if (id is! String || sha is! String || size is! int || file is! String) {
        return null;
      }
      return _PartialMeta(
        id: id,
        sha256: sha,
        size: size,
        file: file,
        etag: etag is String ? etag : null,
      );
    } on FormatException {
      return null;
    }
  }

  final String id;
  final String sha256;
  final int size;
  final String file;
  final String? etag;

  _PartialMeta withEtag(String? e) =>
      _PartialMeta(id: id, sha256: sha256, size: size, file: file, etag: e);

  String encode() => jsonEncode({
    'v': 1,
    'id': id,
    'sha256': sha256,
    'size': size,
    'file': file,
    if (etag != null) 'etag': etag,
  });
}
