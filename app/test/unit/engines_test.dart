import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/core/platform/stt_engine.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';
import 'package:vaultvoice/features/recording/data/recording_providers.dart';
import 'package:vaultvoice/features/recording/domain/capture_backend.dart';

import '../fakes/fake_capture_backend.dart';
import '../fakes/fake_llm_engine.dart';
import '../fakes/fake_stt_engine.dart';
import '../fakes/fake_vault_writer.dart';
import '../helpers/test_container.dart';

void main() {
  group('SttEngine fake', () {
    test(
      '[FND-02/AC2] transcribes via provider override with progress',
      () async {
        final stt = FakeSttEngine(
          segments: const [
            TranscriptSegment(
              start: Duration.zero,
              end: Duration(seconds: 1),
              text: 'a',
            ),
            TranscriptSegment(
              start: Duration(seconds: 1),
              end: Duration(seconds: 2),
              text: 'b',
            ),
          ],
        );
        final c = createContainer(overrides: fakeEngineOverrides(stt: stt));
        final progress = <double>[];

        final result = await c
            .read(sttEngineProvider)
            .transcribe('x.wav', onProgress: progress.add);

        expect(result.valueOrNull?.text, 'a b');
        expect(progress, [0.5, 1.0]);
        expect(stt.calls, ['x.wav']);
      },
    );

    test('[FND-02/AC2] honours cancellation and injected failure', () async {
      final stt = FakeSttEngine();
      final c = createContainer(overrides: fakeEngineOverrides(stt: stt));
      final token = CancelToken()..cancel();

      final cancelled = await c
          .read(sttEngineProvider)
          .transcribe('x.wav', cancel: token);
      expect(cancelled.failureOrNull, isA<CancelledFailure>());

      stt.failWith(const ModelMissingFailure('whisper-tiny'));
      final failed = await c.read(sttEngineProvider).transcribe('x.wav');
      expect(failed.failureOrNull, isA<ModelMissingFailure>());
    });
  });

  group('LlmEngine fake', () {
    test('[FND-02/AC2] streams tokens and returns joined output', () async {
      final llm = FakeLlmEngine();
      final c = createContainer(overrides: fakeEngineOverrides(llm: llm));
      final tokens = <String>[];

      final result = await c
          .read(llmEngineProvider)
          .generate(const LlmRequest(prompt: 'p'), onToken: tokens.add);

      expect(result.valueOrNull, '{"ok":true}');
      expect(tokens, hasLength(4));
      expect(llm.requests.single.prompt, 'p');
    });

    test('[FND-02/AC2] honours cancellation and injected failure', () async {
      final llm = FakeLlmEngine();
      final c = createContainer(overrides: fakeEngineOverrides(llm: llm));
      final token = CancelToken()..cancel();

      final cancelled = await c
          .read(llmEngineProvider)
          .generate(const LlmRequest(prompt: 'p'), cancel: token);
      expect(cancelled.failureOrNull, isA<CancelledFailure>());

      llm.failWith(const OutOfMemoryFailure());
      final failed = await c
          .read(llmEngineProvider)
          .generate(const LlmRequest(prompt: 'p'));
      expect(failed.failureOrNull, isA<OutOfMemoryFailure>());
    });
  });

  group('CaptureBackend fake', () {
    test('[FND-02/AC2] records the capture sequence and failures', () async {
      final capture = FakeCaptureBackend();
      final c = createContainer(
        overrides: fakeEngineOverrides(capture: capture),
      );
      final backend = c.read(captureBackendProvider);

      expect((await backend.openMicrophone()).isOk, isTrue);
      expect(capture.micOpen, isTrue);
      final notices = <CaptureNotice>[];
      final sub = backend.notices.listen(notices.add);
      capture.notify(CaptureNotice.lowStorageWarning);
      await sub.cancel();
      expect(notices, [CaptureNotice.lowStorageWarning]);
      await backend.suspend(gap: GapKind.userPause);
      expect(capture.micOpen, isFalse);
      final closed = await backend.close(cause: StopCause.maxDuration);
      expect(closed.isOk, isTrue);
      expect(capture.calls.last, isA<CloseCall>());
      expect((capture.calls.last as CloseCall).cause, StopCause.maxDuration);

      capture.failWith(const PermissionFailure('microphone'));
      expect(
        (await backend.openMicrophone()).failureOrNull,
        isA<PermissionFailure>(),
      );
    });
  });

  group('VaultWriter fake', () {
    test('[FND-02/AC2] stores notes and surfaces failures', () async {
      final vault = FakeVaultWriter();
      final c = createContainer(overrides: fakeEngineOverrides(vault: vault));
      final writer = c.read(vaultWriterProvider);

      final ok = await writer.write(
        const NoteDraft(relativePath: 'a/b.md', markdown: '# hi'),
      );
      expect(ok.valueOrNull?.location, 'fake://a/b.md');
      expect(vault.notes['a/b.md'], '# hi');

      vault.failWith(const StorageFailure('disk full'));
      final failed = await writer.write(
        const NoteDraft(relativePath: 'c.md', markdown: ''),
      );
      expect(failed.failureOrNull, isA<StorageFailure>());
    });
  });

  test('[FND-02/AC2] engine providers have no default implementation', () {
    final c = createContainer();
    expect(() => c.read(sttEngineProvider), throwsA(anything));
  });
}
