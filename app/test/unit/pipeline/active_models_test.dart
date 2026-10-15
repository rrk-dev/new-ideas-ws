import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/extraction/domain/device_tiering.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/licensing/domain/feature_access.dart';
import 'package:vaultvoice/features/licensing/domain/feature_matrix.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';
import 'package:vaultvoice/features/pipeline/domain/active_models.dart';

const int _gib = 1024 * 1024 * 1024;
final DateTime _now = DateTime.utc(2026, 10, 14);

FeatureAccess _free() => FeatureAccess.resolve(
  Entitlement.free(_now),
  now: _now,
  mode: DistributionMode.commercial,
);

FeatureAccess _pro() => FeatureAccess.resolve(
  Entitlement(
    plan: Plan.proLifetime,
    verifiedAt: _now,
    source: EntitlementSource.appStore,
  ),
  now: _now,
  mode: DistributionMode.commercial,
);

CatalogModel _model(
  String id,
  ModelType type, {
  int size = 100 * 1000 * 1000,
  ModelTier tier = ModelTier.free,
  int minRamMb = 1024,
  List<DeviceTier> tiers = const [DeviceTier.low, DeviceTier.mid],
  String? file,
}) => CatalogModel(
  id: id,
  type: type,
  version: '1',
  displayName: id,
  tier: tier,
  file: file ?? '$id.bin',
  size: size,
  sha256: '0' * 64,
  minRamMb: minRamMb,
  recommendedDeviceTiers: tiers,
  license: 'MIT',
  licenseUrl: Uri.parse('https://example.invalid/license'),
  urls: [Uri.parse('https://example.invalid/$id')],
  companions: const [],
);

DeviceProfile _device(int ramGib) => DeviceProfile(
  platform: 'android',
  osVersion: '15',
  totalRamBytes: ramGib * _gib,
  availableRamBytes: ramGib * _gib ~/ 2,
);

InstalledModelInfo _installed(String id, EngineModelKind kind, int size) =>
    InstalledModelInfo(id: id, kind: kind, sizeBytes: size);

void main() {
  final catalog = ModelCatalog(
    schema: 1,
    issuedAt: _now,
    minAppVersion: const SemVer(1, 0, 0),
    models: [
      _model('stt-base', ModelType.stt, size: 60 * 1000 * 1000),
      _model(
        'stt-small-pro',
        ModelType.stt,
        size: 190 * 1000 * 1000,
        tier: ModelTier.pro,
      ),
      _model('llm-1b', ModelType.llm, size: 800 * 1000 * 1000),
      _model(
        'llm-3b',
        ModelType.llm,
        size: 2000 * 1000 * 1000,
        tier: ModelTier.pro,
        minRamMb: 5000,
        tiers: const [DeviceTier.mid, DeviceTier.high],
      ),
    ],
  );
  final all = [
    _installed('stt-base', EngineModelKind.stt, 60 * 1000 * 1000),
    _installed('stt-small-pro', EngineModelKind.stt, 190 * 1000 * 1000),
    _installed('llm-1b', EngineModelKind.llm, 800 * 1000 * 1000),
    _installed('llm-3b', EngineModelKind.llm, 2000 * 1000 * 1000),
  ];

  group('[FND-11/AC1] active model selection (tier × plan × installed)', () {
    test('[STT-07/AC1] a preferred or default English-only STT model is not '
        'kept for a non-English language', () {
      final cat = ModelCatalog(
        schema: 1,
        issuedAt: _now,
        minAppVersion: const SemVer(1, 0, 0),
        models: [
          _model('stt-en', ModelType.stt, file: 'ggml-base.en.bin'),
          _model('stt-multi', ModelType.stt, file: 'ggml-base.bin'),
        ],
      );
      final inst = [
        _installed('stt-en', EngineModelKind.stt, 60 * 1000 * 1000),
        _installed('stt-multi', EngineModelKind.stt, 70 * 1000 * 1000),
      ];
      final de = selectActiveModels(
        installed: inst,
        access: _free(),
        catalog: cat,
        device: _device(6),
        preferredStt: 'stt-en',
        sttLanguage: 'de',
      );
      expect(de.stt, 'stt-multi');
      final en = selectActiveModels(
        installed: inst,
        access: _free(),
        catalog: cat,
        device: _device(6),
        preferredStt: 'stt-en',
      );
      expect(en.stt, 'stt-en');
    });

    test('nothing installed selects nothing', () {
      final s = selectActiveModels(installed: const [], access: _pro());
      expect(s.stt, isNull);
      expect(s.llm, isNull);
      expect(s.llmContext, kFallbackLlmContext);
    });

    test('Free is capped: no Pro-tier STT, no large LLM', () {
      final s = selectActiveModels(
        installed: all,
        access: _free(),
        catalog: catalog,
        device: _device(8),
      );
      expect(s.stt, 'stt-base');
      expect(s.llm, 'llm-1b');
      expect(s.llmContext, defaultContextFor(DeviceTier.high));
    });

    test('Pro on a mid-tier device gets the tier default', () {
      final s = selectActiveModels(
        installed: all,
        access: _pro(),
        catalog: catalog,
        device: _device(6),
      );
      expect(s.llm, 'llm-3b');
      expect(s.stt, 'stt-small-pro');
      expect(s.llmContext, defaultContextFor(DeviceTier.mid));
    });

    test('the min-RAM rule blocks a model that does not fit the device', () {
      final s = selectActiveModels(
        installed: all,
        access: _pro(),
        catalog: catalog,
        device: _device(4),
      );
      expect(s.llm, 'llm-1b');
    });

    test("the user's usable preference wins; an unusable one is ignored", () {
      final pro = selectActiveModels(
        installed: all,
        access: _pro(),
        catalog: catalog,
        device: _device(8),
        preferredLlm: 'llm-1b',
        preferredStt: 'stt-base',
      );
      expect(pro.llm, 'llm-1b');
      expect(pro.stt, 'stt-base');
      final free = selectActiveModels(
        installed: all,
        access: _free(),
        catalog: catalog,
        device: _device(8),
        preferredLlm: 'llm-3b',
      );
      expect(free.llm, 'llm-1b');
    });

    test('sideloaded models unknown to the catalog count as Free; a large '
        'file needs Pro', () {
      final installed = [
        _installed('custom-small', EngineModelKind.llm, 500 * 1000 * 1000),
        _installed('custom-big', EngineModelKind.llm, 3000 * 1000 * 1000),
        _installed('whisper-tiny', EngineModelKind.stt, 77 * 1000 * 1000),
      ];
      final free = selectActiveModels(installed: installed, access: _free());
      expect(free.llm, 'custom-small');
      expect(free.stt, 'whisper-tiny');
      final pro = selectActiveModels(installed: installed, access: _pro());
      // No catalog / device tier: the smallest usable model (conservative).
      expect(pro.llm, 'custom-small');
    });

    test('a not-recommended but usable model is still selected', () {
      final s = selectActiveModels(
        installed: [all.first],
        access: _free(),
        catalog: catalog,
        device: _device(8), // high tier: stt-base is recommended low/mid
      );
      expect(s.stt, 'stt-base');
    });
  });

  group('ActiveModelSelection JSON', () {
    test('round-trips and rejects malformed values', () {
      const s = ActiveModelSelection(stt: 'a', llm: 'b', llmContext: 6144);
      expect(ActiveModelSelection.fromJson(s.toJson()), s);
      expect(ActiveModelSelection.fromJson(null), const ActiveModelSelection());
      expect(
        ActiveModelSelection.fromJson(const {
          'stt': 3,
          'llm': '',
          'llm_context': 1,
        }),
        const ActiveModelSelection(),
      );
      expect(s.idOf(EngineModelKind.stt), 'a');
      expect(s.idOf(EngineModelKind.llm), 'b');
      expect(
        s.hashCode,
        const ActiveModelSelection(
          stt: 'a',
          llm: 'b',
          llmContext: 6144,
        ).hashCode,
      );
      expect('$s', contains('a'));
    });
  });
}
