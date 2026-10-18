import 'dart:async';
import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/features/licensing/data/managed_config_providers.dart';
import 'package:vaultvoice/features/licensing/domain/managed_config.dart';
import 'package:vaultvoice/features/profiles/data/profile_transfer_providers.dart';
import 'package:vaultvoice/features/profiles/data/profile_transfer_service.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

part 'managed_config_applier.g.dart';

enum ManagedLicenseState { none, installed, rejected }

/// What applying the MDM `license` and `profile_packs` did. Counts only:
/// never a licence, a pack or a profile name.
class ManagedApplyStatus {
  const ManagedApplyStatus({
    this.license = ManagedLicenseState.none,
    this.packsInstalled = 0,
    this.packsRejected = 0,
  });

  final ManagedLicenseState license;
  final int packsInstalled;
  final int packsRejected;

  bool get hasIssue =>
      license == ManagedLicenseState.rejected || packsRejected > 0;
}

/// Installs the managed licence and profile packs whenever the managed
/// configuration changes (and once at start). Started by
/// `ManagedConfigHost`; the other keys are enforced where they are used.
@riverpod
class ManagedConfigApplier extends _$ManagedConfigApplier {
  String? _fingerprint;

  @override
  ManagedApplyStatus build() {
    ref.listen(managedConfigProvider, (_, next) {
      final config = next.value;
      if (config != null) unawaited(_apply(config));
    }, fireImmediately: true);
    return const ManagedApplyStatus();
  }

  Future<void> _apply(ManagedConfig config) async {
    // The licence and the packs are applied only when they change.
    final key = '${config.license}|${config.profilePacks.join(',')}';
    if (key == _fingerprint) return;
    _fingerprint = key;
    var license = ManagedLicenseState.none;
    if (config.license case final text?) {
      final r = await ref
          .read(licenseSettingsPortProvider)
          .installEnterpriseLicense(text);
      license = r.isOk
          ? ManagedLicenseState.installed
          : ManagedLicenseState.rejected;
    }
    var installed = 0;
    var rejected = 0;
    if (config.profilePacks.isNotEmpty) {
      // After the licence: signed packs are verified against its org key.
      final service = await ref.read(profileTransferServiceProvider.future);
      for (final pack in config.profilePacks) {
        switch (await _install(service, pack)) {
          case true:
            installed++;
          case false:
            rejected++;
        }
      }
    }
    if (ref.mounted) {
      state = ManagedApplyStatus(
        license: license,
        packsInstalled: installed,
        packsRejected: rejected,
      );
    }
  }

  /// Managed packs must be organisation-signed (`bundle.managed`); an
  /// unsigned or unverifiable pack is refused, never installed as a user
  /// profile.
  static Future<bool> _install(
    ProfileTransferService service,
    String b64,
  ) async {
    final List<int> bytes;
    try {
      bytes = base64Decode(b64);
    } on FormatException {
      return false;
    }
    final check = await service.inspect(bytes);
    switch (check) {
      case ImportReady(:final bundle) when bundle.managed:
        return (await service.install(check)).isOk;
      case ImportRefused(:final reason)
          when reason == ImportRefusal.alreadyInstalled:
        return true;
      case _:
        return false;
    }
  }
}
