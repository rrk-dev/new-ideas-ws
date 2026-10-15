import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/stt_engine.dart';
import 'package:vaultvoice/features/extraction/domain/device_tiering.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/licensing/domain/feature_access.dart';
import 'package:vaultvoice/features/licensing/domain/feature_matrix.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';
import 'package:vaultvoice/features/models/domain/model_management.dart';
import 'package:vaultvoice/features/pipeline/data/active_engines.dart';
import 'package:vaultvoice/features/pipeline/domain/active_models.dart';
import 'package:vaultvoice/features/transcription/domain/stt_model_policy.dart';

/// Integration wave 3: cross-branch wiring that no single task owned.
void main() {
  final t0 = DateTime.utc(2026, 10, 14);
  FeatureAccess access(Plan plan) => FeatureAccess.resolve(
    Entitlement(
      plan: plan,
      verifiedAt: t0,
      source: EntitlementSource.builtIn,
      expiresAt: t0.add(const Duration(days: 365)),
    ),
    now: t0,
    mode: DistributionMode.commercial,
  );
  final catalog = switch (ModelCatalog.parse(
    File('assets/catalog/catalog.json').readAsBytesSync(),
  )) {
    Ok(:final value) => value,
    Err(:final failure) => throw StateError('$failure'),
  };
  const mid = DeviceProfile(
    platform: 'ios',
    osVersion: 'test',
    totalRamBytes: 6 * 1024 * 1024 * 1024,
    availableRamBytes: 3 * 1024 * 1024 * 1024,
  );

  test('MDL-03 writes the preferred-model keys FND-11 reads', () {
    expect(ActiveModelKeys.stt, kPreferredSttModelKey);
    expect(ActiveModelKeys.llm, kPreferredLlmModelKey);
  });

  test('LLM-07 defaultsFor picks the STT default with STT-07 '
      'recommendedSttModel (tier × plan × language)', () {
    for (final plan in [Plan.free, Plan.proAnnual]) {
      final a = access(plan);
      final gate = SttPlanGate.access(a);
      final llm = LlmPlanGate(largeLlm: () => a.has(Feature.largeLlm));
      for (final language in ['en', 'de']) {
        final want = recommendedSttModel(
          tier: tierForRam(mid.totalRamBytes),
          totalRamMb: mid.totalRamBytes ~/ (1024 * 1024),
          language: language,
          catalog: catalog,
          gate: gate,
        );
        expect(want, isNotNull, reason: '$plan $language');
        final d = defaultsFor(
          mid,
          catalog,
          llm,
          stt: gate,
          sttLanguage: language,
        );
        expect(d.stt?.id, want!.id, reason: '$plan $language');
      }
    }
  });

  test(
    'FND-11 selection uses the STT-07 default when nothing is preferred',
    () {
      final a = access(Plan.free);
      final want = recommendedSttModel(
        tier: tierForRam(mid.totalRamBytes),
        totalRamMb: mid.totalRamBytes ~/ (1024 * 1024),
        language: 'en',
        catalog: catalog,
        gate: SttPlanGate.access(a),
      )!;
      final installed = [
        for (final m in catalog.models)
          if (m.type == ModelType.stt)
            InstalledModelInfo(
              id: m.id,
              kind: EngineModelKind.stt,
              sizeBytes: m.size,
            ),
      ];
      final s = selectActiveModels(
        installed: installed,
        access: a,
        catalog: catalog,
        device: mid,
      );
      expect(s.stt, want.id);
    },
  );

  test('ActiveSttEngine decodes English with .en models and keeps the '
      'requested language for multilingual ones (STT-07 sttLanguageFor)', () {
    const auto = SttOptions(language: 'auto', vadModelPath: '/v.bin');
    final en = sttOptionsForModelFile('/m/ggml-base.en-q5_1.bin', auto);
    expect(en.language, 'en');
    expect(en.vadModelPath, '/v.bin');
    expect(
      sttOptionsForModelFile('/m/ggml-base-q5_1.bin', auto).language,
      'auto',
    );
    expect(sttOptionsForModelFile('/m/custom.bin', auto), same(auto));
  });
}
