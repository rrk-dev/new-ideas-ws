import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/features/extraction/data/preview_llm_engine.dart';
import 'package:vaultvoice/features/extraction/domain/llm_backend_policy.dart';
import 'package:vaultvoice/features/extraction/domain/llm_service.dart';
import 'package:vaultvoice/features/pipeline/data/active_engines.dart';

import '../../fakes/fake_llm_runtime.dart';

void main() {
  test('[LLM-04/AC1] backgrounding while a profile preview is loading on '
      'the GPU: generation runs on the CPU', () async {
    final gate = Completer<void>();
    final rt = FakeLlmRuntime()..loadDelay = gate.future;
    final engine = PreviewLlmEngine(
      pipelineBusy: () async => false,
      resolve: () async =>
          const ActiveModel(id: 'm', path: '/m.gguf', sizeBytes: 1),
      create: (m) => LlmService(
        runtime: rt,
        modelPath: m.path,
        backend: () => const LlmBackendChoice(useGpu: true, reason: 'gpu'),
        contextSize: 2048,
      ),
    );
    final pending = engine.generate(const LlmRequest(prompt: 'p'));
    await pumpEventQueue();
    expect(rt.loads.single.useGpu, isTrue);
    engine.setForeground(foreground: false);
    rt.loadDelay = null;
    gate.complete();
    expect((await pending).isOk, isTrue);
    final ran = rt.sessions.where((s) => s.prompts.isNotEmpty).toList();
    expect(ran.single.usedGpu, isFalse);
  });
}
