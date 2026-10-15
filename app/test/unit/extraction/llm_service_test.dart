import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/features/extraction/domain/llm_backend_policy.dart';
import 'package:vaultvoice/features/extraction/domain/llm_runtime.dart';
import 'package:vaultvoice/features/extraction/domain/llm_service.dart';

import '../../fakes/fake_llm_runtime.dart';

void main() {
  const gpu = LlmBackendChoice(useGpu: true, reason: 'test-gpu');
  const cpu = LlmBackendChoice(useGpu: false, reason: 'test-cpu');

  LlmService service(
    FakeLlmRuntime rt, {
    LlmBackendChoice choice = gpu,
    void Function()? onRestart,
    List<LlmRunStats>? stats,
  }) => LlmService(
    runtime: rt,
    modelPath: '/models/m.gguf',
    backend: () => choice,
    contextSize: 2048,
    pollInterval: const Duration(milliseconds: 5),
    onRestart: onRestart,
    onStats: stats?.add,
  );

  group('LlmService as LlmTokenizer (LLM-06)', () {
    test('counts tokens / templated prompts on the loaded session and '
        'forwards reusePrefix', () async {
      final rt = FakeLlmRuntime();
      final s = service(rt);
      expect((await s.countTokens('a b c')).valueOrNull, 3);
      expect(
        (await s.countPromptTokens('u v', systemPrompt: 'sys')).valueOrNull,
        // '<system>sys<user>u v' -> 2 words in the fake
        2,
      );
      expect((await s.contextWindow()).valueOrNull, 2048);
      expect(rt.loads, hasLength(1), reason: 'one load for all counts');
      await s.generate(const LlmRequest(prompt: 'x', reusePrefix: true));
      await s.generate(const LlmRequest(prompt: 'y'));
      expect(rt.sessions.single.reusePrefix, [true, false]);
    });

    test('a refused load surfaces as the failure', () async {
      final rt = FakeLlmRuntime(loadError: -3);
      final r = await service(rt).countTokens('a');
      expect(r.failureOrNull, isA<OutOfMemoryFailure>());
    });
  });

  group('LlmService (LLM-04)', () {
    test('loads lazily, applies the chat template, streams tokens', () async {
      final rt = FakeLlmRuntime();
      final stats = <LlmRunStats>[];
      final s = service(rt, stats: stats);
      expect(s.isLoaded, isFalse);
      final tokens = <String>[];
      final r = await s.generate(
        const LlmRequest(prompt: 'hi', systemPrompt: 'sys', grammar: 'g'),
        onToken: tokens.add,
      );
      expect(r.valueOrNull, 'Hello!');
      expect(tokens, ['Hel', 'lo', '!']);
      expect(rt.loads.single.useGpu, isTrue);
      expect(rt.sessions.single.prompts.single, '<system>sys<user>hi');
      expect(rt.sessions.single.grammars.single, 'g');
      expect(stats.single.generatedTokens, 3);
      // Second request reuses the loaded session.
      await s.generate(const LlmRequest(prompt: 'again', templated: true));
      expect(rt.loads, hasLength(1));
      expect(rt.sessions.single.prompts.last, 'again');
    });

    test(
      'a cancelled token stops the run and returns CancelledFailure',
      () async {
        final rt = FakeLlmRuntime(
          chunks: List.filled(200, 'x'),
          perChunk: const Duration(milliseconds: 2),
        );
        final cancel = CancelToken();
        rt.onFirstChunk = (_) => cancel.cancel();
        final r = await service(rt)
            .generate(const LlmRequest(prompt: 'p'), cancel: cancel);
        expect(r.failureOrNull, isA<CancelledFailure>());
        expect(rt.sessions.single.prompts, hasLength(1));
      },
    );

    test(
      'backgrounded during a GPU run -> restarted on a CPU session',
      () async {
        final rt = FakeLlmRuntime(
          chunks: List.filled(50, 'y'),
          perChunk: const Duration(milliseconds: 2),
        );
        var restarts = 0;
        final s = service(rt, onRestart: () => restarts++);
        rt.onFirstChunk = (run) {
          if (rt.sessions.length == 1) s.onBackgrounded();
        };
        final r = await s.generate(const LlmRequest(prompt: 'p'));
        expect(r.isOk, isTrue);
        expect(restarts, 1);
        expect(rt.loads.map((c) => c.useGpu), [true, false]);
        expect(rt.sessions.first.disposed, isTrue);
        expect(s.usesGpu, isFalse);
        s
          ..onForegrounded()
          ..unload();
        await s.generate(const LlmRequest(prompt: 'p2'));
        expect(rt.loads.last.useGpu, isTrue, reason: 'GPU again in foreground');
      },
    );

    test('[LLM-04/AC1] backgrounded while the GPU model is still loading '
        '-> no GPU generation; the run uses a CPU session', () async {
      // Regression for the Codex FAIL (2026-10-14): onBackgrounded() was a
      // no-op while `_session == null`, so the in-flight GPU load was
      // installed and generation started on the GPU in the background.
      final gate = Completer<void>();
      final rt = FakeLlmRuntime()..loadDelay = gate.future;
      final s = service(rt);
      final pending = s.generate(const LlmRequest(prompt: 'p'));
      await pumpEventQueue();
      expect(rt.loads.single.useGpu, isTrue, reason: 'GPU load in flight');
      s.onBackgrounded();
      rt.loadDelay = null;
      gate.complete();
      final r = await pending;
      expect(r.valueOrNull, 'Hello!');
      final ran = rt.sessions.where((x) => x.prompts.isNotEmpty).toList();
      expect(ran, hasLength(1));
      expect(ran.single.usedGpu, isFalse, reason: 'no GPU work in background');
      expect(rt.sessions.first.disposed, isTrue, reason: 'GPU session freed');
      expect(s.usesGpu, isFalse);
    });

    test('[LLM-04/AC1] backgrounded before any load -> the first load is CPU; '
        'the next foreground load uses the GPU', () async {
      final rt = FakeLlmRuntime();
      final s = service(rt)..onBackgrounded();
      await s.generate(const LlmRequest(prompt: 'p'));
      expect(rt.loads.single.useGpu, isFalse);
      // A loaded CPU session is kept; the next load uses the GPU again.
      s
        ..onForegrounded()
        ..unload();
      await s.generate(const LlmRequest(prompt: 'p2'));
      expect(rt.loads.map((c) => c.useGpu), [false, true]);
    });

    test('[LLM-04/AC1] concurrent callers awaiting a GPU load that finishes '
        'in the background never get the GPU session', () async {
      final gate = Completer<void>();
      final rt = FakeLlmRuntime()..loadDelay = gate.future;
      final s = service(rt);
      final count = s.countTokens('a b');
      final gen = s.generate(const LlmRequest(prompt: 'p'));
      await pumpEventQueue();
      s.onBackgrounded();
      rt.loadDelay = null;
      gate.complete();
      expect((await count).valueOrNull, 2);
      expect((await gen).isOk, isTrue);
      expect(
        rt.sessions.where((x) => x.prompts.isNotEmpty).map((x) => x.usedGpu),
        [false],
      );
    });

    test('VV_E_BACKEND on the GPU retries once on CPU; then fails', () async {
      final rt = FakeLlmRuntime(gpuStatus: LlmRunStatus.backend);
      final r = await service(rt).generate(const LlmRequest(prompt: 'p'));
      expect(r.valueOrNull, 'Hello!');
      expect(rt.loads.map((c) => c.useGpu), [true, false]);

      final rt2 = FakeLlmRuntime(
        gpuStatus: LlmRunStatus.backend,
        cpuStatus: LlmRunStatus.backend,
      );
      final r2 = await service(rt2).generate(const LlmRequest(prompt: 'p'));
      expect(r2.failureOrNull, isA<NativeFailure>());
    });

    test(
      'CPU choice never loads the GPU; OOM on load maps to Failure',
      () async {
        final rt = FakeLlmRuntime();
        await service(rt, choice: cpu).generate(const LlmRequest(prompt: 'p'));
        expect(rt.loads.single.useGpu, isFalse);

        final oom = FakeLlmRuntime(loadError: -3);
        final r = await service(oom).generate(const LlmRequest(prompt: 'p'));
        expect(r.failureOrNull, isA<OutOfMemoryFailure>());
        final missing = FakeLlmRuntime(loadError: -2);
        final r2 = await service(missing)
            .generate(const LlmRequest(prompt: 'p'));
        expect(r2.failureOrNull, isA<NativeFailure>());
      },
    );

    test('invalid grammar and pre-cancelled tokens fail fast', () async {
      final rt = FakeLlmRuntime();
      final s = service(rt);
      final bad = await s.generate(
        const LlmRequest(prompt: 'p', grammar: 'bad'),
      );
      expect(bad.failureOrNull, isA<NativeFailure>());
      final pre = CancelToken()..cancel();
      final r = await s.generate(const LlmRequest(prompt: 'p'), cancel: pre);
      expect(r, isA<Err<String>>());
    });

    test('unload disposes the session; the next request reloads', () async {
      final rt = FakeLlmRuntime();
      final s = service(rt);
      await s.load();
      s.unload();
      expect(rt.sessions.single.disposed, isTrue);
      expect(s.isLoaded, isFalse);
      await s.generate(const LlmRequest(prompt: 'p'));
      expect(rt.loads, hasLength(2));
    });

    test('[LLM-04/AC1] unload during an in-flight load disposes that load; '
        'nothing stays installed', () async {
      final gate = Completer<void>();
      final rt = FakeLlmRuntime()..loadDelay = gate.future;
      final s = service(rt);
      final pending = s.generate(const LlmRequest(prompt: 'p'));
      await pumpEventQueue();
      s.unload();
      gate.complete();
      final r = await pending;
      expect(r.isOk, isFalse);
      expect(s.isLoaded, isFalse);
      expect(rt.sessions.single.disposed, isTrue);
      expect(rt.sessions.single.prompts, isEmpty);
    });

    test('[LLM-07/AC1] memory pressure during a load discards it and returns '
        'OutOfMemoryFailure; no generation on the old context', () async {
      final gate = Completer<void>();
      final rt = FakeLlmRuntime()..loadDelay = gate.future;
      final s = service(rt);
      final pending = s.generate(const LlmRequest(prompt: 'p'));
      await pumpEventQueue();
      s.onMemoryPressure();
      gate.complete();
      final r = await pending;
      expect(r.failureOrNull, isA<OutOfMemoryFailure>());
      expect(s.isLoaded, isFalse);
      expect(rt.sessions.single.disposed, isTrue);
      expect(rt.sessions.single.prompts, isEmpty);
    });
  });
}
