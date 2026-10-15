import 'package:vaultvoice/features/licensing/domain/feature_access.dart';
import 'package:vaultvoice/features/models/data/model_import_providers.dart';
import 'package:vaultvoice/features/models/data/model_management_providers.dart';
import 'package:vaultvoice/features/models/data/model_state_providers.dart';
import 'package:vaultvoice/features/models/domain/installed_model.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';
import 'package:vaultvoice/features/models/domain/model_management.dart';
import 'package:vaultvoice/features/models/presentation/models_screen.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

import '../fakes/fake_settings_store.dart';
import '../helpers/golden.dart';
import '../helpers/model_fixtures.dart';

ModelEntry _entry(
  CatalogModel m, {
  bool installed = false,
  bool active = false,
  bool recommended = false,
  String? installedVersion,
}) => ModelEntry(
  model: m,
  installed: installed
      ? InstalledModel(
          id: m.id,
          version: installedVersion ?? m.version,
          size: m.size,
          relativePath: 'models/${m.id}/${m.file}',
          installedAt: DateTime.utc(2026),
        )
      : null,
  access: AccessLevel.full,
  compatible: true,
  recommended: recommended,
  active: active,
);

void main() {
  goldenTest(
    '[MDL-03] Models screen',
    fileName: 'models_screen',
    overrides: [
      settingsStoreProvider.overrideWith((ref) => FakeSettingsStore()),
      modelEntriesProvider.overrideWith(
        (ref) async => [
          _entry(
            seedStt,
            installed: true,
            active: true,
            recommended: true,
            installedVersion: '0',
          ),
          _entry(
            catalogModel(
              'whisper-small',
              size: 488 * 1000 * 1000,
              tier: ModelTier.pro,
              displayName: 'Whisper Small (English)',
            ),
          ),
          _entry(seedLlm, installed: true, active: true, recommended: true),
        ],
      ),
      storageUsageProvider.overrideWith(
        (ref) => Stream.value(
          const StorageUsage(
            modelBytes: 569 * 1000 * 1000,
            audioBytes: 115 * 1000 * 1000,
            transcriptBytes: 42 * 1000,
          ),
        ),
      ),
      modelDownloadProgressProvider.overrideWith(
        (ref) => Stream.value(const {}),
      ),
      networkDisabledProvider.overrideWith((ref) => Stream.value(false)),
    ],
    builder: (_) => const ModelsScreen(),
  );
}
