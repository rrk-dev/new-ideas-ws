import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/features/extraction/data/device_profile_probe.dart';
import 'package:vaultvoice/features/extraction/domain/device_tiering.dart';
import 'package:vaultvoice/features/extraction/domain/llm_backend_policy.dart';
import 'package:vaultvoice/features/extraction/domain/llm_service.dart';
import 'package:vaultvoice/features/extraction/domain/memory_planner.dart';
import 'package:vaultvoice/features/extraction/domain/model_residency.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';

import '../../fakes/fake_llm_runtime.dart';

const int _gib = 1024 * 1024 * 1024;

DeviceProfile _device(double ramGib, {String platform = 'ios'}) =>
    DeviceProfile(
      platform: platform,
      osVersion: 'test',
      totalRamBytes: (ramGib * _gib).round(),
      availableRamBytes: (ramGib * _gib * 0.5).round(),
    );

CatalogModel _model(
  String id,
  ModelType type,
  int size, {
  ModelTier tier = ModelTier.free,
  int minRamMb = 2048,
  List<DeviceTier> tiers = DeviceTier.values,
}) => CatalogModel(
  id: id,
  type: type,
  version: '1',
  displayName: id,
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

final _catalog = ModelCatalog(
  schema: 1,
  issuedAt: DateTime.utc(2026, 10, 13),
  minAppVersion: const SemVer(1, 0, 0),
  models: [
    _model('whisper-base', ModelType.stt, 148 * 1000 * 1000),
    _model(
      'whisper-small',
      ModelType.stt,
      488 * 1000 * 1000,
      tiers: [DeviceTier.mid, DeviceTier.high],
    ),
    _model('llama-3.2-1b-q4_k_m', ModelType.llm, 807694464, minRamMb: 3072),
    _model(
      'llama-3.2-3b-q4_k_m',
      ModelType.llm,
      2019377696,
      tier: ModelTier.pro,
      minRamMb: 5120,
      tiers: [DeviceTier.mid, DeviceTier.high],
    ),
  ],
);

void main() {
  group('[LLM-07/AC2] tier detection with mocked device profiles', () {
    test('reported RAM -> Low / Mid / High', () {
      // iPhone 11 / 4 GB Android report ≈ 3.7 GiB.
      expect(tierForRam(_device(3.7).totalRamBytes), DeviceTier.low);
      expect(tierForRam(_device(4.99).totalRamBytes), DeviceTier.low);
      // 6 GB devices report ≈ 5.6 GiB.
      expect(tierForRam(_device(5).totalRamBytes), DeviceTier.mid);
      expect(tierForRam(_device(5.6).totalRamBytes), DeviceTier.mid);
      expect(tierForRam(_device(6.99).totalRamBytes), DeviceTier.mid);
      // 8 GB devices report ≈ 7.3 GiB; 12/16 GB flagships.
      expect(tierForRam(_device(7).totalRamBytes), DeviceTier.high);
      expect(tierForRam(_device(7.3).totalRamBytes), DeviceTier.high);
      expect(tierForRam(_device(15.2).totalRamBytes), DeviceTier.high);
      expect(defaultContextFor(DeviceTier.low), 4096);
      expect(defaultContextFor(DeviceTier.high), 8192);
    });

    test('tier x plan defaults: Free is capped at the 1B class everywhere', () {
      for (final ram in [3.7, 5.6, 7.3, 11.0]) {
        final d = defaultsFor(_device(ram), _catalog, LlmPlanGate.free());
        expect(d.llm!.id, 'llama-3.2-1b-q4_k_m', reason: '$ram GiB free');
      }
      const pro = LlmPlanGate(largeLlm: _yes);
      expect(
        defaultsFor(_device(3.7), _catalog, pro).llm!.id,
        'llama-3.2-1b-q4_k_m',
      );
      expect(
        defaultsFor(_device(5.6), _catalog, pro).llm!.id,
        'llama-3.2-3b-q4_k_m',
      );
      expect(
        defaultsFor(_device(7.3), _catalog, pro).llm!.id,
        'llama-3.2-3b-q4_k_m',
      );
      expect(defaultsFor(_device(3.7), _catalog, pro).stt!.id, 'whisper-base');
      expect(defaultsFor(_device(7.3), _catalog, pro).stt!.id, 'whisper-small');
      expect(defaultsFor(_device(7.3), _catalog, pro).contextSize, 8192);
    });

    test('tier cache: keyed by RAM + OS version', () {
      final dir = Directory.systemTemp.createTempSync('vv_tier');
      addTearDown(() => dir.deleteSync(recursive: true));
      final cache = DeviceTierCache(File('${dir.path}/vv/device_tier.json'));
      expect(cache.tierFor(_device(3.7)), DeviceTier.low);
      expect(cache.tierFor(_device(3.7)), DeviceTier.low); // cached
      expect(cache.tierFor(_device(7.3)), DeviceTier.high); // new key
      File('${dir.path}/vv/device_tier.json').writeAsStringSync('{broken');
      expect(cache.tierFor(_device(5.6)), DeviceTier.mid);
    });
  });

  group('memory planning (LLM-07)', () {
    test('estimate follows the vv-llm-inference memory math', () {
      final e1 = LlmMemoryEstimate.of(
        modelFileBytes: 807694464,
        contextSize: 8192,
        kvQuant: false,
      );
      expect(e1.kvBytes, 8192 * 32 * 1024); // 256 MiB f16 for 1B @ 8k
      final e3 = LlmMemoryEstimate.of(
        modelFileBytes: 2019377696,
        contextSize: 8192,
        kvQuant: false,
      );
      expect(e3.kvBytes / (1 << 20), closeTo(900, 30)); // ≈ 0.9 GB f16
      final q8 = LlmMemoryEstimate.of(
        modelFileBytes: 2019377696,
        contextSize: 8192,
      );
      expect(q8.kvBytes / (1 << 20), closeTo(480, 20)); // ≈ 0.48 GB q8_0
    });

    test('pre-load check keeps, reduces or refuses the context', () {
      const threeB = 2019377696;
      final fits = planLlmLoad(
        modelFileBytes: threeB,
        availableBytes: 5 * _gib,
        requestedContext: 8192,
      );
      expect(
        (fits.allowed, fits.contextSize, fits.reason),
        (true, 8192, 'fits'),
      );
      final reduced = planLlmLoad(
        modelFileBytes: threeB,
        availableBytes: (3.15 * _gib).round(),
        requestedContext: 8192,
      );
      expect(reduced.allowed, isTrue);
      expect(reduced.contextSize, lessThan(8192));
      expect(reduced.reason, 'reduced-context');
      final refused = planLlmLoad(
        modelFileBytes: threeB,
        availableBytes: 2 * _gib,
        requestedContext: 8192,
      );
      expect(refused.allowed, isFalse);
      expect(refused.reason, 'insufficient-memory');
    });

    test('model fit: block 3B on a 4 GB phone, warn on 6 GB, ok on 8 GB', () {
      ModelFit fit(double ram) => assessModelFit(
        modelFileBytes: 2019377696,
        minRamMb: 3072,
        device: _device(ram),
      );
      expect(fit(3.7), ModelFit.block);
      expect(fit(5.6), ModelFit.warn);
      expect(fit(7.3), ModelFit.ok);
      expect(
        assessModelFit(
          modelFileBytes: 807694464,
          minRamMb: 3072,
          device: _device(3.7),
        ),
        ModelFit.ok,
      );
      expect(
        assessModelFit(
          modelFileBytes: 807694464,
          minRamMb: 8192,
          device: _device(7.3),
        ),
        ModelFit.block,
      );
    });
  });

  group('residency + memory pressure (LLM-07)', () {
    test('loading the LLM unloads STT first; never both', () async {
      final residency = ModelResidency();
      var sttUnloads = 0;
      residency
        ..register(ResidentModel.stt, () => sttUnloads++)
        ..acquire(ResidentModel.stt);
      final rt = FakeLlmRuntime();
      final s = LlmService(
        runtime: rt,
        modelPath: 'm',
        backend: () => const LlmBackendChoice(useGpu: false, reason: 't'),
        onBeforeLoad: () => residency.acquire(ResidentModel.llm),
      );
      residency.register(ResidentModel.llm, s.unload);
      await s.generate(const LlmRequest(prompt: 'p'));
      expect(sttUnloads, 1);
      expect(residency.loaded, {ResidentModel.llm});
      residency.acquire(ResidentModel.stt); // pipeline moves on to STT
      expect(s.isLoaded, isFalse);
      expect(residency.loaded, {ResidentModel.stt});
    });

    test('load gate refusal -> OutOfMemoryFailure, nothing loaded', () async {
      final rt = FakeLlmRuntime();
      final s = LlmService(
        runtime: rt,
        modelPath: 'm',
        backend: () => const LlmBackendChoice(useGpu: false, reason: 't'),
        loadGate: (_) => const Err(OutOfMemoryFailure()),
      );
      final r = await s.generate(const LlmRequest(prompt: 'p'));
      expect(r.failureOrNull, isA<OutOfMemoryFailure>());
      expect(rt.loads, isEmpty);
      final reduced = LlmService(
        runtime: rt,
        modelPath: 'm',
        backend: () => const LlmBackendChoice(useGpu: false, reason: 't'),
        contextSize: 8192,
        loadGate: (ctx) => Ok(ctx ~/ 2),
      );
      await reduced.generate(const LlmRequest(prompt: 'p'));
      expect(rt.sessions.single.contextSize, 4096);
    });

    test('memory pressure mid-run: stop, unload, OOM, halve context', () async {
      final rt = FakeLlmRuntime(
        chunks: List.filled(100, 'z'),
        perChunk: const Duration(milliseconds: 2),
      );
      final s = LlmService(
        runtime: rt,
        modelPath: 'm',
        backend: () => const LlmBackendChoice(useGpu: false, reason: 't'),
        contextSize: 8192,
      );
      rt.onFirstChunk = (_) => s.onMemoryPressure();
      final r = await s.generate(const LlmRequest(prompt: 'p'));
      expect(r.failureOrNull, isA<OutOfMemoryFailure>());
      expect(s.isLoaded, isFalse);
      expect(rt.sessions.single.disposed, isTrue);
      expect(s.effectiveContextSize, 4096);
      rt.onFirstChunk = null;
      final again = await s.generate(const LlmRequest(prompt: 'p'));
      expect(again.isOk, isTrue);
      expect(rt.sessions.last.contextSize, 4096);
      s
        ..onMemoryPressure() // idle: just unload
        ..onMemoryPressure()
        ..onMemoryPressure();
      expect(s.isLoaded, isFalse);
      expect(s.effectiveContextSize, 2048); // floor
    });
  });
}

bool _yes() => true;
