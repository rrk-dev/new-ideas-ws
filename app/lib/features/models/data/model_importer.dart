import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/models/data/catalog_config.dart';
import 'package:vaultvoice/features/models/data/model_downloader.dart';
import 'package:vaultvoice/features/models/data/model_installer.dart';
import 'package:vaultvoice/features/models/domain/catalog_verifier.dart';
import 'package:vaultvoice/features/models/domain/custom_model_entitlement.dart';
import 'package:vaultvoice/features/models/domain/download_platform.dart';
import 'package:vaultvoice/features/models/domain/download_policy.dart';
import 'package:vaultvoice/features/models/domain/gguf_header.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';
import 'package:vaultvoice/features/models/domain/model_manifest.dart';

/// Settings key: the user turned on "Advanced: custom model" (also needs the
/// Pro entitlement).
const kAdvancedCustomModelKey = 'models.advanced_custom_model';

/// SHA-256 (lower-case hex) of a file, computed off the UI isolate.
Future<String> sha256OfFileInIsolate(String path) => Isolate.run(
  () async =>
      (await crypto.sha256.bind(File(path).openRead()).first).toString(),
);

/// Installs models from local files with zero network (MDL-04): USB, AirDrop,
/// MDM-pushed file, picked with the system file picker.
///
/// Signed path: model file + `<id>.json` (single-model manifest) +
/// `<id>.json.sig`, verified with the same pinned keys, the same size +
/// SHA-256 check (in an isolate) and the same [ModelInstaller] as an online
/// download. Unsigned GGUFs only with "Advanced: custom model" enabled *and*
/// the custom-model entitlement, after a GGUF header sanity check.
///
/// File names of picked files are user content: never logged or stored (a
/// custom model is installed as `custom.gguf` under a hash-derived id).
class ModelImporter {
  ModelImporter({
    required this._installer,
    required this._verifier,
    required this._device,
    this._entitlement = const DenyCustomModels(),
    Future<bool> Function()? advancedCustomModelSetting,
    this._verify = verifyModelFileInIsolate,
    this._sha256Of = sha256OfFileInIsolate,
    this._appVersion = kCatalogAppVersion,
  }) : _advancedSetting = advancedCustomModelSetting ?? _no;

  final ModelInstaller _installer;
  final CatalogVerifier _verifier;
  final DownloadDeviceInfo _device;
  final CustomModelEntitlement _entitlement;
  final Future<bool> Function() _advancedSetting;
  final ModelFileCheck _verify;
  final Future<String> Function(String path) _sha256Of;
  final SemVer _appVersion;

  static Future<bool> _no() async => false;

  /// Whether the "Advanced: custom model" option may be offered and used.
  Future<bool> customModelsEnabled() async =>
      await _entitlement.allowsCustomModels() && await _advancedSetting();

  /// Sorts picked [files] into model / manifest / signature and imports.
  /// [moveSource]: the files are app-private picker copies (file_selector
  /// copies into the app cache) and may be moved instead of copied.
  Future<Result<InstalledModelRow>> importPicked(
    List<File> files, {
    bool moveSource = true,
  }) async {
    File? manifest;
    File? signature;
    final models = <File>[];
    for (final f in files) {
      final name = p.basename(f.path).toLowerCase();
      if (name.endsWith('.sig')) {
        signature = f;
      } else if (name.endsWith('.json')) {
        manifest = f;
      } else {
        models.add(f);
      }
    }
    if (models.length != 1) {
      return Err(ModelImportFailure(ModelImportRejection.missingFiles));
    }
    if (manifest != null && signature != null) {
      return await importSigned(
        model: models.single,
        manifest: manifest,
        signature: signature,
        moveSource: moveSource,
      );
    }
    if (manifest != null || signature != null) {
      return Err(ModelImportFailure(ModelImportRejection.missingFiles));
    }
    return await importCustomGguf(model: models.single, moveSource: moveSource);
  }

  /// Imports a catalog model described by a signed single-model manifest.
  Future<Result<InstalledModelRow>> importSigned({
    required File model,
    required File manifest,
    required File signature,
    bool moveSource = false,
  }) async {
    final Result<CatalogModel> verified;
    try {
      if (await manifest.length() > kMaxCatalogBytes ||
          await signature.length() > kMaxCatalogBytes) {
        return Err(CatalogFailure(CatalogRejection.tooLarge));
      }
      verified = await verifySingleModelManifest(
        _verifier,
        manifestBytes: await manifest.readAsBytes(),
        signatureBytes: await signature.readAsBytes(),
        appVersion: _appVersion,
      );
    } on FileSystemException {
      return const Err(StorageFailure('model import: manifest unreadable'));
    }
    final entry = verified.valueOrNull;
    if (entry == null) return Err(verified.failureOrNull!);
    return await _stageVerifyInstall(
      entry,
      model,
      moveSource: moveSource,
      check: (staged) => _verify(staged.path, entry),
    );
  }

  /// Imports an unsigned GGUF ("Advanced: custom model").
  Future<Result<InstalledModelRow>> importCustomGguf({
    required File model,
    bool moveSource = false,
  }) async {
    if (!await _advancedSetting()) {
      return Err(ModelImportFailure(ModelImportRejection.unknownModel));
    }
    if (!await _entitlement.allowsCustomModels()) {
      return Err(ModelImportFailure(ModelImportRejection.entitlementRequired));
    }
    final int size;
    final List<int> head;
    try {
      size = await model.length();
      final raf = await model.open();
      try {
        head = await raf.read(kGgufHeaderBytes);
      } finally {
        await raf.close();
      }
    } on FileSystemException {
      return const Err(StorageFailure('model import: file unreadable'));
    }
    final header = checkGgufHeader(head, size);
    if (!header.isOk) return Err(header.failureOrNull!);

    // The id is derived from the content, so it is only known after
    // hashing; stage under a temporary name first.
    final staged = await _stage('custom-import', model, size, moveSource);
    if (staged case Err(:final failure)) return Err(failure);
    final file = staged.valueOrNull!;
    final sha = await _sha256Of(file.path);
    final entry = customCatalogModel(sha256: sha, size: size);
    final named = File(p.join(_installer.stagingDir, '${entry.id}.import'));
    await file.rename(named.path);
    return await _install(entry, named);
  }

  /// Catalog-shaped entry for a custom GGUF with content hash [sha256].
  static CatalogModel customCatalogModel({
    required String sha256,
    required int size,
  }) => CatalogModel(
    id: 'custom-${sha256.substring(0, 16)}',
    type: ModelType.llm,
    version: 'custom',
    displayName: 'Custom model',
    tier: ModelTier.pro,
    file: 'custom.gguf',
    size: size,
    sha256: sha256,
    minRamMb: 0,
    recommendedDeviceTiers: const [
      DeviceTier.low,
      DeviceTier.mid,
      DeviceTier.high,
    ],
    license: 'unknown (user-supplied)',
    licenseUrl: Uri(),
    urls: const [],
    companions: const [],
  );

  Future<Result<InstalledModelRow>> _stageVerifyInstall(
    CatalogModel entry,
    File source, {
    required bool moveSource,
    required Future<Result<void>> Function(File staged) check,
  }) async {
    final int size;
    try {
      size = await source.length();
    } on FileSystemException {
      return const Err(StorageFailure('model import: file unreadable'));
    }
    if (size != entry.size) {
      return Err(ModelIntegrityFailure(entry.id, sizeMismatch: true));
    }
    final staged = await _stage('${entry.id}.import', source, size, moveSource);
    if (staged case Err(:final failure)) return Err(failure);
    final file = staged.valueOrNull!;
    final ok = await check(file);
    if (!ok.isOk) {
      await _deleteQuietly(file);
      return Err(ok.failureOrNull!);
    }
    return await _install(entry, file);
  }

  Future<Result<InstalledModelRow>> _install(
    CatalogModel entry,
    File staged,
  ) async {
    try {
      return await _installer.install(entry, staged);
    } on FileSystemException catch (e) {
      await _deleteQuietly(staged);
      return Err(
        StorageFailure('model import io: ${e.osError?.errorCode ?? 0}'),
      );
    }
  }

  /// Moves (same volume) or copies [source] into the staging dir.
  Future<Result<File>> _stage(
    String name,
    File source,
    int size,
    bool moveSource,
  ) async {
    final dir = Directory(_installer.stagingDir);
    await dir.create(recursive: true);
    final target = File(p.join(dir.path, name));
    await _deleteQuietly(target);
    if (moveSource) {
      try {
        return Ok(await source.rename(target.path));
      } on FileSystemException {
        // Different volume: fall back to copy + delete.
      }
    }
    final free = await _device.freeBytes(dir.path);
    final required = requiredFreeBytes(size);
    if (free == null || free < required) {
      return Err(
        ModelDownloadFailure(
          'import',
          ModelDownloadBlock.insufficientSpace,
          requiredBytes: required,
          freeBytes: free,
        ),
      );
    }
    try {
      await source.openRead().pipe(target.openWrite());
      if (moveSource) await _deleteQuietly(source);
      return Ok(target);
    } on FileSystemException catch (e) {
      await _deleteQuietly(target);
      return Err(
        StorageFailure('model import io: ${e.osError?.errorCode ?? 0}'),
      );
    }
  }

  static Future<void> _deleteQuietly(File f) async {
    try {
      if (f.existsSync()) await f.delete();
    } on FileSystemException {
      // Best effort.
    }
  }
}
