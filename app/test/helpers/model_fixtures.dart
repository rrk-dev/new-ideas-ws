import 'package:vaultvoice/features/models/domain/model_catalog.dart';

/// A catalog entry for UI/unit tests (never downloaded).
CatalogModel catalogModel(
  String id, {
  ModelType type = ModelType.stt,
  int size = 100 * 1000 * 1000,
  ModelTier tier = ModelTier.free,
  int minRamMb = 2048,
  List<DeviceTier> tiers = DeviceTier.values,
  String version = '1',
  String? displayName,
}) => CatalogModel(
  id: id,
  type: type,
  version: version,
  displayName: displayName ?? 'Model $id',
  tier: tier,
  file: '$id.bin',
  size: size,
  sha256: '0' * 64,
  minRamMb: minRamMb,
  recommendedDeviceTiers: tiers,
  license: 'MIT',
  licenseUrl: Uri.parse('https://example.com/license'),
  urls: [Uri.parse('https://example.com/$id')],
  companions: const [],
);

ModelCatalog catalogOf(List<CatalogModel> models, {DateTime? issuedAt}) =>
    ModelCatalog(
      schema: 1,
      issuedAt: issuedAt ?? DateTime.utc(2026, 10, 13),
      minAppVersion: const SemVer(1, 0, 0),
      models: models,
    );

/// Whisper tiny + a 0.5 B LLM, like the bundled seed catalog.
final CatalogModel seedStt = catalogModel(
  'whisper-tiny.en',
  size: 77704715,
  displayName: 'Whisper Tiny (English)',
);
final CatalogModel seedLlm = catalogModel(
  'qwen2.5-0.5b',
  type: ModelType.llm,
  size: 491400032,
  minRamMb: 3072,
  displayName: 'Qwen2.5 0.5B Instruct',
);
