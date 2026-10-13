import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/extraction/domain/llm_backend_policy.dart';

void main() {
  const policy = LlmBackendPolicy();

  group('LLM-02 iOS backend policy', () {
    test('foreground uses Metal with full offload and q8_0 KV', () {
      final c = policy.choose(platform: LlmPlatform.ios, foreground: true);
      expect(c.useGpu, isTrue);
      expect(c.gpuDevice, -1);
      expect(c.kvQuant, isTrue);
      expect(c.flashAttn, FlashAttn.auto);
      expect(c.reason, 'ios-foreground-metal');
    });

    test('background never attaches the GPU (CPU fallback)', () {
      final c = policy.choose(
        platform: LlmPlatform.ios,
        foreground: false,
        gpuDevice: 0,
      );
      expect(c.useGpu, isFalse);
      expect(c.gpuDevice, -1);
      expect(c.reason, 'ios-background-cpu');
    });

    test('a disabled GPU stays on CPU even in the foreground', () {
      final c = policy.choose(
        platform: LlmPlatform.ios,
        foreground: true,
        gpuAllowed: false,
      );
      expect(c.useGpu, isFalse);
    });
  });

  test('FlashAttn mirrors VV_LLM_FLASH_ATTN_* values', () {
    expect(FlashAttn.auto.native, -1);
    expect(FlashAttn.off.native, 0);
    expect(FlashAttn.on.native, 1);
  });
}
