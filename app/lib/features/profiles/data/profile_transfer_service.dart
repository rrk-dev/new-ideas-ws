import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/repositories/profiles_repository.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/clock.dart';
import 'package:vaultvoice/features/profiles/data/custom_profile_service.dart';
import 'package:vaultvoice/features/profiles/data/profile_registry.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/domain/profile_bundle.dart';
import 'package:vaultvoice/features/templates/domain/template_generator.dart';

/// Why an import cannot proceed (the UI localizes it).
enum ImportRefusal {
  /// The bundle itself was rejected ([ImportRefused.bundle] says why).
  invalidBundle,

  /// The id belongs to a built-in profile or to a profile of another source.
  idTaken,

  /// The installed version is newer (downgrades are refused).
  olderVersion,

  /// Exactly this version is already installed.
  alreadyInstalled,

  /// Custom (Pro) or managed (Enterprise) profiles are not available.
  notEntitled,
}

/// What [ProfileTransferService.inspect] found.
sealed class ImportCheck {
  const ImportCheck();
}

/// The bundle can be installed; [installedVersion] non-null = update.
final class ImportReady extends ImportCheck {
  const ImportReady(this.bundle, {this.installedVersion});

  final ProfileBundle bundle;
  final int? installedVersion;

  bool get isUpdate => installedVersion != null;
}

final class ImportRefused extends ImportCheck {
  const ImportRefused(this.reason, {this.bundle});

  final ImportRefusal reason;

  /// Set for [ImportRefusal.invalidBundle].
  final BundleRejection? bundle;
}

/// `.vvprofile` export and import (PRF-08).
///
/// Import rules (vv-extraction-profiles → "Import/export"): signed packs
/// verified against the organization keys (LIC-03) become managed
/// (`enterprise`, read-only); unsigned bundles become user profiles (Pro).
/// Same id + higher version → update offered; same version → already
/// installed; lower → refused; ids of built-ins or of another source →
/// refused.
class ProfileTransferService {
  ProfileTransferService({
    required this.registry,
    required this.dao,
    required this.trustedKeys,
    required this.canImportCustom,
    required this.canImportManaged,
    required this.builtinTemplateSource,
    this.codec = const ProfileBundleCodec(),
    this.clock = const SystemClock(),
  });

  final ProfileRegistry registry;
  final ProfilesRepository dao;

  /// Organization profile keys from the enterprise license (LIC-03).
  final List<OrgProfileKey> Function() trustedKeys;
  final bool Function() canImportCustom;
  final bool Function() canImportManaged;

  /// Source of a built-in template asset (null = not a built-in id).
  final Future<String?> Function(String templateId) builtinTemplateSource;
  final ProfileBundleCodec codec;
  final Clock clock;

  /// Bundle bytes of profile [id] with its bound template (stored row,
  /// built-in asset, or a generated one).
  Future<Result<Uint8List>> export(
    String id, {
    required String createdBy,
  }) async {
    final got = await registry.get(id);
    if (got case Err(:final failure)) return Err(failure);
    final profile = got.valueOrNull!;
    final row = (await dao.getTemplate(profile.templateId)).valueOrNull;
    final template =
        row?.body ??
        await builtinTemplateSource(profile.templateId) ??
        generateTemplate(profile);
    return Ok(await codec.encode(profile, template, createdBy: createdBy));
  }

  /// Decodes, verifies and classifies [bytes] without changing anything.
  Future<ImportCheck> inspect(List<int> bytes) async {
    final ProfileBundle bundle;
    try {
      bundle = await codec.decode(bytes, trustedKeys: trustedKeys());
    } on BundleException catch (e) {
      return ImportRefused(ImportRefusal.invalidBundle, bundle: e.reason);
    }
    if (!(bundle.managed ? canImportManaged() : canImportCustom())) {
      return const ImportRefused(ImportRefusal.notEntitled);
    }
    final p = bundle.profile;
    if (registry.builtins[p.id] != null) {
      return const ImportRefused(ImportRefusal.idTaken);
    }
    // A new profile must not take over another profile's template row.
    final template = (await dao.getTemplate(p.templateId)).valueOrNull;
    if (template != null && template.profileId != p.id) {
      return const ImportRefused(ImportRefusal.idTaken);
    }
    final row = (await dao.getProfile(p.id)).valueOrNull;
    if (row == null) return ImportReady(bundle);
    if (row.source != p.source) {
      return const ImportRefused(ImportRefusal.idTaken);
    }
    if (p.version < row.version) {
      return const ImportRefused(ImportRefusal.olderVersion);
    }
    if (p.version == row.version) {
      return const ImportRefused(ImportRefusal.alreadyInstalled);
    }
    return ImportReady(bundle, installedVersion: row.version);
  }

  /// Installs a bundle [inspect] accepted: profile (keeping its version)
  /// and its template row.
  Future<Result<Profile>> install(ImportReady ready) async {
    final b = ready.bundle;
    final saved = await registry.save(
      b.profile.toJson(),
      source: b.profile.source,
    );
    if (saved case Err(:final failure)) return Err(failure);
    final profile = saved.valueOrNull!;
    // A profile bound to a built-in template uses the asset every install
    // ships; never store a row that would shadow it.
    if (await builtinTemplateSource(profile.templateId) != null) {
      return Ok(profile);
    }
    final stored = await dao.upsertTemplate(
      TemplatesCompanion.insert(
        id: profile.templateId,
        profileId: Value(profile.id),
        body: b.template,
        filenamePattern: profile.filenamePattern ?? kCustomFilenamePattern,
        updatedAt: clock.now(),
      ),
    );
    if (stored case Err(:final failure)) return Err(failure);
    return Ok(profile);
  }
}
