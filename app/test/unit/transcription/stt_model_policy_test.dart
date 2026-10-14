import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/licensing/data/local_entitlement_service.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/licensing/domain/feature_access.dart';
import 'package:vaultvoice/features/licensing/domain/feature_matrix.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';
import 'package:vaultvoice/features/transcription/domain/stt_model_policy.dart';

import '../../fakes/fake_clock.dart';

final _t0 = DateTime.utc(2026, 10, 14);

Entitlement _plan(Plan p, {DateTime? expiresAt}) => Entitlement(
  plan: p,
  verifiedAt: _t0,
  source: EntitlementSource.builtIn,
  expiresAt: expiresAt ?? _t0.add(const Duration(days: 365)),
);

SttPlanGate _gate(Plan p, {DistributionMode mode = DistributionMode.commercial}) =>
    SttPlanGate.access(FeatureAccess.resolve(_plan(p), now: _t0, mode: mode));

/// The bundled, signed catalog (STT-07 entries are real files: size and
/// sha256 computed from the downloaded models).
ModelCatalog _bundled() {
  final bytes = File('assets/catalog/catalog.json').readAsBytesSync();
  return switch (ModelCatalog.parse(bytes)) {
    Ok(:final value) => value,
    Err(:final failure) => throw StateError('$failure'),
  };
}

const _gib = 1024;

void main() {
  final catalog = _bundled();
  CatalogModel byId(String id) => catalog.byId(id)!;

  group('SttVariant.fromFile', () {
    test('parses whisper.cpp file names', () {
      expect(
        SttVariant.fromFile('ggml-base.en-q5_1.bin'),
        const SttVariant(
          size: SttModelSize.base,
          englishOnly: true,
          quant: 'q5_1',
        ),
      );
      expect(
        SttVariant.fromFile('ggml-large-v3-turbo-q5_0.bin'),
        const SttVariant(
          size: SttModelSize.largeTurbo,
          englishOnly: false,
          quant: 'q5_0',
        ),
      );
      expect(
        SttVariant.fromFile('ggml-tiny.en.bin'),
        const SttVariant(size: SttModelSize.tiny, englishOnly: true),
      );
      expect(SttVariant.fromFile('ggml-small-q5_1.bin')!.multilingual, isTrue);
      expect(SttVariant.fromFile('qwen2.5.gguf'), isNull);
      expect(SttVariant.fromFile('ggml-huge.bin'), isNull);
    });
  });

  group('[STT-07/AC2] Free vs Pro STT models through LIC-01 entitlements', () {
    test('size classes map to the LIC-01 features', () {
      expect(sttFeatureFor(SttModelSize.tiny), isNull);
      expect(sttFeatureFor(SttModelSize.base), isNull);
      expect(sttFeatureFor(SttModelSize.small), Feature.smallStt);
      expect(sttFeatureFor(SttModelSize.largeTurbo), Feature.highAccuracyStt);
      expect(sttFeatureFor(SttModelSize.medium), Feature.highAccuracyStt);
    });

    // One row per bundled STT model × plan (commercial build).
    const freeIds = {
      'whisper-tiny.en',
      'whisper-tiny.en-q5_1',
      'whisper-base.en',
      'whisper-base.en-q5_1',
      'whisper-base-q5_1',
    };
    for (final m in [
      for (final m in _bundled().models)
        if (m.type == ModelType.stt) m,
    ]) {
      for (final plan in Plan.values) {
        final expected = freeIds.contains(m.id) || plan != Plan.free;
        test('${m.id} on ${plan.name} → ${expected ? 'usable' : 'locked'}', () {
          expect(sttModelEntitled(m, _gate(plan)), expected);
          expect(
            sttModelAccess(m, _gate(plan), installed: true),
            expected ? AccessLevel.full : AccessLevel.readOnly,
          );
          expect(
            sttModelAccess(m, _gate(plan), installed: false),
            expected ? AccessLevel.full : AccessLevel.disabled,
          );
        });
      }
    }

    test('bundled catalog tier tags agree with the size-class features', () {
      for (final m in catalog.models.where((m) => m.type == ModelType.stt)) {
        final v = SttVariant.fromFile(m.file);
        expect(v, isNotNull, reason: m.id);
        final gated = sttFeatureFor(v!.size) != null;
        expect(
          m.tier,
          gated ? ModelTier.pro : ModelTier.free,
          reason: '${m.id} catalog tier',
        );
      }
    });

    test('a mis-tagged catalog entry cannot unlock a Pro size class', () {
      final mis = _copy(byId('whisper-small.en-q5_1'), tier: ModelTier.free);
      expect(sttModelEntitled(mis, _gate(Plan.free)), isFalse);
      // …and a Pro catalog tag locks even a baseline size class.
      final pro = _copy(byId('whisper-base.en'), tier: ModelTier.pro);
      expect(sttModelEntitled(pro, _gate(Plan.free)), isFalse);
    });

    test('personal build unlocks every STT model', () {
      for (final m in catalog.models.where((m) => m.type == ModelType.stt)) {
        expect(
          sttModelEntitled(
            m,
            _gate(Plan.free, mode: DistributionMode.personal),
          ),
          isTrue,
          reason: m.id,
        );
      }
    });

    test('non-STT models are never "STT entitled"', () {
      final llm = catalog.models.firstWhere((m) => m.type == ModelType.llm);
      expect(sttModelEntitled(llm, _gate(Plan.enterprise)), isFalse);
    });

    test('selection falls back to Free when Pro expires (downgrade, live '
        'EntitlementService)', () async {
      final clock = FakeClock(_t0);
      final service = LocalEntitlementService(
        clock: clock,
        mode: DistributionMode.commercial,
        initial: _plan(
          Plan.proAnnual,
          expiresAt: _t0.add(const Duration(hours: 1)),
        ),
      );
      addTearDown(service.dispose);
      final gate = SttPlanGate.entitlements(service);
      CatalogModel? resolve() => resolveSttModel(
        selectedId: 'whisper-small.en-q8_0',
        tier: DeviceTier.mid,
        totalRamMb: 6 * _gib,
        language: 'en',
        catalog: catalog,
        gate: gate,
      );
      expect(resolve()!.id, 'whisper-small.en-q8_0');
      clock.advance(const Duration(hours: 2));
      expect(resolve()!.id, 'whisper-base.en-q5_1');
      unawaited(service.dispose());
    });
  });

  group('[STT-07/AC1] per-device recommended default', () {
    String? rec(
      DeviceTier tier,
      Plan plan, {
      String language = 'en',
      int ramMb = 8 * _gib,
    }) => recommendedSttModel(
      tier: tier,
      totalRamMb: ramMb,
      language: language,
      catalog: catalog,
      gate: _gate(plan),
    )?.id;

    test('English, Free', () {
      expect(rec(DeviceTier.low, Plan.free, ramMb: 4 * _gib), 'whisper-base.en-q5_1');
      expect(rec(DeviceTier.mid, Plan.free), 'whisper-base.en-q5_1');
      expect(rec(DeviceTier.high, Plan.free), 'whisper-base.en');
    });

    test('English, Pro', () {
      expect(
        rec(DeviceTier.low, Plan.proAnnual, ramMb: 4 * _gib),
        'whisper-small.en-q5_1',
      );
      expect(rec(DeviceTier.mid, Plan.proLifetime), 'whisper-small.en-q8_0');
      expect(rec(DeviceTier.high, Plan.proAnnual), kHighTierEnglishPro);
    });

    test('multilingual: Free base, Pro small / large-v3-turbo', () {
      for (final lang in ['de', 'fr', 'auto']) {
        expect(rec(DeviceTier.low, Plan.free, language: lang), 'whisper-base-q5_1');
        expect(
          rec(DeviceTier.mid, Plan.proAnnual, language: lang),
          'whisper-small-q5_1',
        );
        expect(
          rec(DeviceTier.high, Plan.proAnnual, language: lang),
          'whisper-large-v3-turbo-q5_0',
        );
      }
    });

    test('min_ram_mb filters a model the device cannot hold', () {
      final turbo = byId('whisper-large-v3-turbo-q5_0');
      expect(
        rec(DeviceTier.high, Plan.proAnnual, language: 'de', ramMb: turbo.minRamMb - 1),
        'whisper-small-q5_1',
      );
    });

    test('every preference id is in the bundled catalog', () {
      for (final ids in kSttPreference.values) {
        for (final id in ids) {
          expect(catalog.byId(id), isNotNull, reason: id);
        }
      }
    });

    test('an empty catalog recommends nothing (pipeline waits)', () {
      final llmOnly = ModelCatalog(
        schema: 1,
        issuedAt: _t0,
        minAppVersion: const SemVer(1, 0, 0),
        models: catalog.models.where((m) => m.type != ModelType.stt).toList(),
      );
      expect(
        recommendedSttModel(
          tier: DeviceTier.high,
          totalRamMb: 8 * _gib,
          language: 'en',
          catalog: llmOnly,
          gate: _gate(Plan.enterprise),
        ),
        isNull,
      );
    });
  });

  group('language handling', () {
    test('.en models always decode English; multilingual follow the user', () {
      final en = SttVariant.fromFile('ggml-base.en-q5_1.bin')!;
      final multi = SttVariant.fromFile('ggml-base-q5_1.bin')!;
      expect(sttLanguageFor(en, 'de'), 'en');
      expect(sttLanguageFor(multi, 'de'), 'de');
      expect(sttLanguageFor(multi, kSttAutoLanguage), 'auto');
    });

    test('needsMultilingual: only explicit English uses .en models', () {
      expect(needsMultilingual('en'), isFalse);
      expect(needsMultilingual('de'), isTrue);
      expect(needsMultilingual(kSttAutoLanguage), isTrue);
    });

    test('default language follows the device locale', () {
      expect(defaultSttLanguage('en'), 'en');
      expect(defaultSttLanguage('DE'), 'de');
      expect(defaultSttLanguage(''), 'en');
    });

    test('resolve: a selected .en model is replaced for a German user', () {
      final m = resolveSttModel(
        selectedId: 'whisper-base.en',
        tier: DeviceTier.mid,
        totalRamMb: 6 * _gib,
        language: 'de',
        catalog: catalog,
        gate: _gate(Plan.free),
      );
      expect(m!.id, 'whisper-base-q5_1');
    });

    test('resolve: unknown selection falls back to the recommendation', () {
      final m = resolveSttModel(
        selectedId: 'whisper-gone',
        tier: DeviceTier.low,
        totalRamMb: 4 * _gib,
        language: 'en',
        catalog: catalog,
        gate: _gate(Plan.free),
      );
      expect(m!.id, 'whisper-base.en-q5_1');
    });
  });
}

CatalogModel _copy(CatalogModel m, {required ModelTier tier}) => CatalogModel(
  id: m.id,
  type: m.type,
  version: m.version,
  displayName: m.displayName,
  tier: tier,
  file: m.file,
  size: m.size,
  sha256: m.sha256,
  minRamMb: m.minRamMb,
  recommendedDeviceTiers: m.recommendedDeviceTiers,
  license: m.license,
  licenseUrl: m.licenseUrl,
  urls: m.urls,
  companions: m.companions,
);
