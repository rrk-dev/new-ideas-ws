import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/network/model_hosts.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/features/licensing/data/licensing_providers.dart';
import 'package:vaultvoice/features/licensing/data/managed_config_providers.dart';
import 'package:vaultvoice/features/models/data/catalog_providers.dart';
import 'package:vaultvoice/features/models/data/download_providers.dart';
import 'package:vaultvoice/features/models/data/model_importer.dart';
import 'package:vaultvoice/features/models/data/model_installer.dart';
import 'package:vaultvoice/features/models/domain/custom_model_entitlement.dart';

part 'model_import_providers.g.dart';

/// Lets the user pick model files (+ manifest + signature).
abstract interface class ModelFilePicker {
  /// Picked files as app-private copies, or empty when cancelled.
  Future<List<File>> pick();
}

/// System picker via `file_selector` (Android `ACTION_OPEN_DOCUMENT` /
/// iOS `UIDocumentPickerViewController` in import mode — both hand back a
/// copy inside the app's cache/tmp, which the importer then moves).
class FileSelectorModelPicker implements ModelFilePicker {
  const FileSelectorModelPicker();

  @override
  Future<List<File>> pick() async {
    final files = await openFiles(confirmButtonText: 'Import');
    return [for (final f in files) File(f.path)];
  }
}

@Riverpod(keepAlive: true)
ModelFilePicker modelFilePicker(Ref ref) => const FileSelectorModelPicker();

/// Custom-model entitlement from LIC-01 (`Feature.sideloadCustomModel`).
@Riverpod(keepAlive: true)
CustomModelEntitlement customModelEntitlement(Ref ref) =>
    EntitlementCustomModels(
      ref.watch(entitlementServiceProvider),
      // MDM `disable_custom_models` (LIC-04), read at the moment of import.
      isManagedOff: () async =>
          (await readManagedConfig(ref)).disableCustomModels,
    );

/// `network_disabled` (offline mode / MDM): the UI hides downloads and
/// offers import only.
@Riverpod(keepAlive: true)
Stream<bool> networkDisabled(Ref ref) {
  final managed = ref
      .watch(managedConfigProvider)
      .whenData((c) => c.networkDisabled)
      .value;
  if (managed == true) return Stream.value(true);
  return ref
      .watch(settingsRepositoryProvider)
      .watch(kNetworkDisabledKey)
      .map((v) => v == true);
}

@Riverpod(keepAlive: true)
Future<ModelImporter> modelImporter(Ref ref) async {
  final paths = await ref.watch(storagePathsProvider.future);
  final platform = ref.watch(modelDownloadPlatformProvider);
  final settings = ref.watch(settingsRepositoryProvider);
  return ModelImporter(
    installer: ModelInstaller(
      paths: paths,
      models: ref.watch(modelsRepositoryProvider),
      device: platform,
      clock: ref.watch(clockProvider),
    ),
    verifier: ref.watch(catalogVerifierProvider),
    device: platform,
    entitlement: ref.watch(customModelEntitlementProvider),
    advancedCustomModelSetting: () async =>
        (await settings.get(kAdvancedCustomModelKey)).valueOrNull == true,
  );
}
