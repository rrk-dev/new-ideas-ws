import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/features/licensing/data/licensing_providers.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/profiles/data/profile_providers.dart';
import 'package:vaultvoice/features/profiles/data/profile_transfer_service.dart';
import 'package:vaultvoice/features/profiles/domain/profile_bundle.dart';
import 'package:vaultvoice/features/templates/domain/builtin_templates.dart';

part 'profile_transfer_providers.g.dart';

/// Organization keys allowed to sign managed profile packs.
///
/// LIC-03 (enterprise license, not built yet) overrides this with the
/// license's `org_profile_pubkey`; until then no key is trusted and signed
/// packs are refused (`untrustedKey`). PRODUCT-DECISION: no built-in key.
@Riverpod(keepAlive: true)
List<OrgProfileKey> orgProfileKeys(Ref ref) => const [];

/// Picks one `.vvprofile` file (system picker, import mode).
abstract interface class ProfileBundlePicker {
  /// Bundle bytes, or null when cancelled. Refuses files > 2 MB unread.
  Future<List<int>?> pick();
}

class FileSelectorBundlePicker implements ProfileBundlePicker {
  const FileSelectorBundlePicker();

  @override
  Future<List<int>?> pick() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'VaultVoice profile',
          extensions: [kBundleExtension],
          uniformTypeIdentifiers: [kBundleUti],
          mimeTypes: [
            kBundleMime,
            'application/zip',
            'application/octet-stream',
          ],
        ),
      ],
    );
    if (file == null) return null;
    if (await file.length() > BundleLimits.maxBundleBytes) return const [];
    return await file.readAsBytes();
  }
}

@Riverpod(keepAlive: true)
ProfileBundlePicker profileBundlePicker(Ref ref) =>
    const FileSelectorBundlePicker();

/// Where exported bundles are written before the share sheet (app cache).
@Riverpod(keepAlive: true)
Future<Directory> profileExportDir(Ref ref) async {
  final dir = Directory(
    p.join((await getTemporaryDirectory()).path, 'profile-export'),
  );
  return await dir.create(recursive: true);
}

@riverpod
Future<ProfileTransferService> profileTransferService(Ref ref) async {
  final dao = ref.watch(profilesRepositoryProvider);
  final clock = ref.watch(clockProvider);
  final keys = ref.watch(orgProfileKeysProvider);
  final custom = ref.watch(featureProvider(Feature.customProfiles));
  final managed = ref.watch(featureProvider(Feature.managedProfiles));
  final load = ref.watch(profileAssetLoaderProvider);
  final registry = ref.watch(profileRegistryProvider.future);
  return ProfileTransferService(
    registry: await registry,
    dao: dao,
    trustedKeys: () => keys,
    canImportCustom: () => custom,
    canImportManaged: () => managed,
    builtinTemplateSource: (id) async {
      for (final t in kBuiltinTemplates) {
        if (t.id == id) {
          try {
            return await load(t.assetPath);
          } on Object {
            // Missing asset: not available as a built-in here.
            return null;
          }
        }
      }
      return null;
    },
    clock: clock,
  );
}
