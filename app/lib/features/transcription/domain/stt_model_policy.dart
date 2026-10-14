import 'package:flutter/foundation.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement_service.dart';
import 'package:vaultvoice/features/licensing/domain/feature_access.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';

/// Whisper size classes (STT-07, `docs/models.md`).
enum SttModelSize { tiny, base, small, medium, largeTurbo, large }

/// What a catalog STT file is: size class, English-only or multilingual,
/// quantization. Parsed from the whisper.cpp file name
/// (`ggml-<size>[.en][-<quant>].bin`), which the catalog keeps verbatim.
@immutable
final class SttVariant {
  const SttVariant({
    required this.size,
    required this.englishOnly,
    this.quant,
  });

  /// Null for a file that is not a whisper.cpp model name we know.
  static SttVariant? fromFile(String file) {
    final m = _fileRe.firstMatch(file);
    if (m == null) return null;
    final size = switch (m.group(1)!) {
      'tiny' => SttModelSize.tiny,
      'base' => SttModelSize.base,
      'small' => SttModelSize.small,
      'medium' => SttModelSize.medium,
      'large-v3-turbo' => SttModelSize.largeTurbo,
      _ => SttModelSize.large, // large, large-v1/v2/v3
    };
    return SttVariant(
      size: size,
      englishOnly: m.group(2) != null,
      quant: m.group(3),
    );
  }

  static final _fileRe = RegExp(
    r'^ggml-(tiny|base|small|medium|large-v3-turbo|large(?:-v[123])?)'
    r'(\.en)?(?:-(q\d_[01k]|q\d_k|f16))?\.bin$',
  );

  final SttModelSize size;

  /// `.en` models: English only, `language` is forced to `en`.
  final bool englishOnly;

  /// `q5_0`, `q5_1`, `q8_0`, … or null for the f16 original.
  final String? quant;

  bool get multilingual => !englishOnly;

  @override
  bool operator ==(Object other) =>
      other is SttVariant &&
      other.size == size &&
      other.englishOnly == englishOnly &&
      other.quant == quant;

  @override
  int get hashCode => Object.hash(size, englishOnly, quant);
}

/// The LIC-01 feature that unlocks a size class (null = baseline, always
/// available). `small` vs `highAccuracyStt` is split so the open
/// PRODUCT-DECISION in `feature_matrix.dart` (is `small` Free?) stays a
/// one-cell change.
Feature? sttFeatureFor(SttModelSize size) => switch (size) {
  SttModelSize.tiny || SttModelSize.base => null,
  SttModelSize.small => Feature.smallStt,
  SttModelSize.medium ||
  SttModelSize.largeTurbo ||
  SttModelSize.large => Feature.highAccuracyStt,
};

/// Plan gate for STT models, backed by LIC-01's [EntitlementService]
/// ([SttPlanGate.entitlements]). Evaluated on every call so plan changes
/// and expiry apply immediately.
@immutable
final class SttPlanGate {
  const SttPlanGate({required this.has, required this.modelTier});

  /// The real gate.
  factory SttPlanGate.entitlements(EntitlementService entitlements) =>
      SttPlanGate(
        has: entitlements.has,
        modelTier: (tier) => entitlements.access.model(tier, installed: true),
      );

  /// Gate from a resolved snapshot (UI providers).
  factory SttPlanGate.access(FeatureAccess access) => SttPlanGate(
    has: access.has,
    modelTier: (tier) => access.model(tier, installed: true),
  );

  final bool Function(Feature feature) has;

  /// Catalog-tier access for an installed model (`full` = selectable).
  final AccessLevel Function(ModelTier tier) modelTier;
}

/// Whether the plan may *use* (select / transcribe with) [model]. Both
/// checks must pass: the size-class feature (LIC-01 matrix) and the
/// catalog `tier` (a mis-tagged catalog entry can only make a model *more*
/// restricted, never unlock it). Non-STT and unknown files are refused.
bool sttModelEntitled(CatalogModel model, SttPlanGate gate) {
  if (model.type != ModelType.stt) return false;
  final variant = SttVariant.fromFile(model.file);
  if (variant == null) return false;
  final feature = sttFeatureFor(variant.size);
  if (feature != null && !gate.has(feature)) return false;
  return gate.modelTier(model.tier) == AccessLevel.full;
}

/// Model-list access for [model]: [AccessLevel.full] = selectable,
/// [AccessLevel.readOnly] = installed but not selectable (downgrade keeps
/// files), [AccessLevel.disabled] = may not be downloaded.
AccessLevel sttModelAccess(
  CatalogModel model,
  SttPlanGate gate, {
  required bool installed,
}) {
  if (sttModelEntitled(model, gate)) return AccessLevel.full;
  return installed ? AccessLevel.readOnly : AccessLevel.disabled;
}

/// `auto` = whisper language auto-detect (multilingual models only).
const String kSttAutoLanguage = 'auto';

/// Whether [language] (an ISO 639-1 code or [kSttAutoLanguage]) needs a
/// multilingual model.
bool needsMultilingual(String language) => language != 'en';

/// The `language` passed to whisper for [variant]: `.en` models always
/// decode English; multilingual models get the user's choice (`auto`
/// detects per window).
String sttLanguageFor(SttVariant variant, String userLanguage) =>
    variant.englishOnly ? 'en' : userLanguage;

/// Default transcription language for a device locale.
///
/// PRODUCT-DECISION: English locales default to `en` (English-only models,
/// best speed/accuracy); every other locale defaults to its own language
/// code with a multilingual model. `auto` is offered in Settings but not the
/// default because detection on the first 30 s can pick the wrong language
/// for mixed-language meetings.
String defaultSttLanguage(String localeLanguageCode) {
  final code = localeLanguageCode.toLowerCase();
  return code.isEmpty ? 'en' : code;
}

/// Recommended model ids in preference order per device tier, plan and
/// language family (STT-07 benchmark: `docs/models.md` → "Recommended
/// defaults"). The first id present in the catalog, entitled and fitting
/// the device RAM wins; Free lists are the fallback tail of the Pro lists so
/// a Pro user without the Pro file still gets a working default.
@visibleForTesting
const Map<(DeviceTier, bool pro, bool multilingual), List<String>>
kSttPreference = {
  // English, Free.
  (DeviceTier.low, false, false): [_baseEnQ5, _tinyEnQ5, _tinyEn],
  (DeviceTier.mid, false, false): [_baseEnQ5, _baseEn, _tinyEnQ5, _tinyEn],
  (DeviceTier.high, false, false): [_baseEn, _baseEnQ5, _tinyEnQ5, _tinyEn],
  // English, Pro.
  (DeviceTier.low, true, false): [_smallEnQ5, _baseEnQ5, _tinyEnQ5, _tinyEn],
  (DeviceTier.mid, true, false): [
    _smallEnQ8,
    _smallEnQ5,
    _baseEnQ5,
    _tinyEnQ5,
    _tinyEn,
  ],
  (DeviceTier.high, true, false): [
    _turboQ5,
    _smallEnQ8,
    _smallEnQ5,
    _baseEn,
    _baseEnQ5,
    _tinyEn,
  ],
  // Multilingual, Free.
  (DeviceTier.low, false, true): [_baseQ5],
  (DeviceTier.mid, false, true): [_baseQ5],
  (DeviceTier.high, false, true): [_baseQ5],
  // Multilingual, Pro.
  (DeviceTier.low, true, true): [_smallQ5, _baseQ5],
  (DeviceTier.mid, true, true): [_smallQ5, _baseQ5],
  (DeviceTier.high, true, true): [_turboQ5, _smallQ5, _baseQ5],
};

const _tinyEn = 'whisper-tiny.en';
const _tinyEnQ5 = 'whisper-tiny.en-q5_1';
const _baseEn = 'whisper-base.en';
const _baseEnQ5 = 'whisper-base.en-q5_1';
const _smallEnQ5 = 'whisper-small.en-q5_1';
const _smallEnQ8 = 'whisper-small.en-q8_0';
const _baseQ5 = 'whisper-base-q5_1';
const _smallQ5 = 'whisper-small-q5_1';
const _turboQ5 = 'whisper-large-v3-turbo-q5_0';

/// Per-device recommended default STT model for [language], or null when
/// the catalog has nothing usable (then the pipeline waits for a download:
/// `ModelMissingFailure`).
///
/// "Pro list" is used when the plan has [Feature.smallStt] (the first Pro
/// size class); every candidate is still checked with [sttModelEntitled],
/// so a High-tier user with `smallStt` but not `highAccuracyStt` skips
/// large-v3-turbo.
CatalogModel? recommendedSttModel({
  required DeviceTier tier,
  required int totalRamMb,
  required String language,
  required ModelCatalog catalog,
  required SttPlanGate gate,
}) {
  final multilingual = needsMultilingual(language);
  final pro = gate.has(Feature.smallStt) || gate.has(Feature.highAccuracyStt);
  final byId = {
    for (final m in catalog.models)
      if (m.type == ModelType.stt) m.id: m,
  };
  for (final id in kSttPreference[(tier, pro, multilingual)]!) {
    final m = byId[id];
    if (m == null || m.minRamMb > totalRamMb) continue;
    final v = SttVariant.fromFile(m.file);
    if (v == null || (multilingual && v.englishOnly)) continue;
    if (sttModelEntitled(m, gate)) return m;
  }
  return null;
}

/// The model the pipeline actually loads: the user's [selectedId] when it
/// is in the catalog, entitled, fits the device and matches the language
/// family; otherwise the recommended default. Downgrade rule
/// (vv-licensing-iap): a Pro-only model stays installed but is no longer
/// used — this resolver is the enforcement point the transcribe step and
/// the model picker both go through.
CatalogModel? resolveSttModel({
  required String? selectedId,
  required DeviceTier tier,
  required int totalRamMb,
  required String language,
  required ModelCatalog catalog,
  required SttPlanGate gate,
}) {
  if (selectedId != null) {
    for (final m in catalog.models) {
      if (m.id != selectedId || m.type != ModelType.stt) continue;
      final v = SttVariant.fromFile(m.file);
      final languageOk =
          v != null && (v.multilingual || !needsMultilingual(language));
      if (languageOk &&
          m.minRamMb <= totalRamMb &&
          sttModelEntitled(m, gate)) {
        return m;
      }
    }
  }
  return recommendedSttModel(
    tier: tier,
    totalRamMb: totalRamMb,
    language: language,
    catalog: catalog,
    gate: gate,
  );
}
