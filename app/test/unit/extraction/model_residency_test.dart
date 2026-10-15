import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/features/extraction/domain/llm_backend_policy.dart';
import 'package:vaultvoice/features/extraction/domain/llm_service.dart';
import 'package:vaultvoice/features/extraction/domain/model_residency.dart';

import '../../fakes/fake_llm_runtime.dart';

/// LLM-07 rework (Codex FAIL issue 1): the real STT unloader
/// (`WhisperSttEngine.unload`) is asynchronous; the LLM must not start
/// loading before that disposal has finished.
void main() {
  LlmService service(FakeLlmRuntime rt, ModelResidency residency) => LlmService(
    runtime: rt,
    modelPath: 'm',
    backend: () => const LlmBackendChoice(useGpu: false, reason: 't'),
    onBeforeLoad: () => residency.acquire(ResidentModel.llm),
  );

  group('[LLM-07/AC1] residency awaits asynchronous disposal', () {
    test('LLM load does not start until the async STT disposal completed; '
        'STT and LLM are never resident together', () async {
      final residency = ModelResidency();
      final disposal = Completer<void>();
      var sttResident = true;
      residency.register(ResidentModel.stt, () async {
        await disposal.future;
        sttResident = false;
      });
      await residency.acquire(ResidentModel.stt);

      final rt = FakeLlmRuntime();
      final s = service(rt, residency);
      residency.register(ResidentModel.llm, s.unload);

      var done = false;
      final run = s
          .generate(const LlmRequest(prompt: 'p'))
          .whenComplete(() => done = true);
      // Give the event loop plenty of turns while disposal is pending.
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(rt.loads, isEmpty, reason: 'LLM loaded while STT resident');
      expect(done, isFalse);
      expect(sttResident, isTrue);
      expect(residency.loaded, isNot(contains(ResidentModel.llm)));

      disposal.complete();
      expect((await run).valueOrNull, 'Hello!');
      expect(sttResident, isFalse);
      expect(rt.loads, hasLength(1));
      expect(residency.loaded, {ResidentModel.llm});
    });

    test('acquire() itself completes only after the other kind was '
        'disposed (delayed 20 ms, as in the verifier repro)', () async {
      final residency = ModelResidency();
      var sttResident = true;
      residency.register(ResidentModel.stt, () async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        sttResident = false;
      });
      await residency.acquire(ResidentModel.stt);
      await residency.acquire(ResidentModel.llm);
      expect(sttResident, isFalse);
      expect(residency.loaded, {ResidentModel.llm});
    });

    test('a throwing disposal never loads the other model: acquire throws '
        'ModelResidencyException, LLM run fails retryable (OOM), and a '
        'later attempt succeeds once disposal works', () async {
      final residency = ModelResidency();
      var fail = true;
      var sttUnloads = 0;
      residency.register(ResidentModel.stt, () async {
        await Future<void>.delayed(Duration.zero);
        if (fail) throw StateError('dispose failed');
        sttUnloads++;
      });
      await residency.acquire(ResidentModel.stt);
      await expectLater(
        residency.acquire(ResidentModel.llm),
        throwsA(
          isA<ModelResidencyException>().having(
            (e) => e.stillResident,
            'stillResident',
            ResidentModel.stt,
          ),
        ),
      );
      expect(residency.loaded, {ResidentModel.stt}, reason: 'still resident');

      final rt = FakeLlmRuntime();
      final s = service(rt, residency);
      final r = await s.generate(const LlmRequest(prompt: 'p'));
      expect(r.failureOrNull, isA<OutOfMemoryFailure>());
      expect(rt.loads, isEmpty, reason: 'never load over a resident STT');

      fail = false;
      expect((await s.generate(const LlmRequest(prompt: 'p'))).isOk, isTrue);
      expect(sttUnloads, 1);
      expect(rt.loads, hasLength(1));
      expect(residency.loaded, {ResidentModel.llm});
    });

    test('concurrent acquisitions are serialized: one kind at a time, '
        'unloads awaited in order', () async {
      final residency = ModelResidency();
      final events = <String>[];
      final overlaps = <Set<ResidentModel>>[];
      Future<void> unloader(ResidentModel k) async {
        events.add('unload-start ${k.name} resident=${residency.loaded}');
        await Future<void>.delayed(const Duration(milliseconds: 5));
        events.add('unload-end ${k.name}');
      }

      residency
        ..register(ResidentModel.stt, () => unloader(ResidentModel.stt))
        ..register(ResidentModel.llm, () => unloader(ResidentModel.llm));
      await residency.acquire(ResidentModel.stt);
      final timer = Timer.periodic(const Duration(milliseconds: 1), (_) {
        if (residency.loaded.length > 1) overlaps.add(residency.loaded);
      });
      await Future.wait([
        residency.acquire(ResidentModel.llm),
        residency.acquire(ResidentModel.stt),
      ]);
      timer.cancel();
      expect(overlaps, isEmpty);
      // The second transition starts only after the first finished: when
      // the LLM is unloaded, STT is no longer marked resident.
      expect(events, [
        'unload-start stt resident={ResidentModel.stt}',
        'unload-end stt',
        'unload-start llm resident={ResidentModel.llm}',
        'unload-end llm',
      ]);
      expect(residency.loaded, {ResidentModel.stt});
    });

    test('releaseAll awaits every unloader', () async {
      final residency = ModelResidency();
      var unloaded = false;
      residency.register(ResidentModel.llm, () async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        unloaded = true;
      });
      await residency.acquire(ResidentModel.llm);
      await residency.releaseAll();
      expect(unloaded, isTrue);
      expect(residency.loaded, isEmpty);
    });
  });
}
