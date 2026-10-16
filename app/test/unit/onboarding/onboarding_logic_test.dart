import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/routing/app_router.dart';
import 'package:vaultvoice/features/extraction/domain/device_tiering.dart';
import 'package:vaultvoice/features/models/data/model_install_waker.dart';
import 'package:vaultvoice/features/models/domain/model_bundle.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';

import '../../helpers/model_fixtures.dart';

const int _gib = 1024 * 1024 * 1024;

DeviceProfile _device(int ramGib) => DeviceProfile(
  platform: 'android',
  osVersion: 'test',
  totalRamBytes: ramGib * _gib,
  availableRamBytes: ramGib * _gib ~/ 2,
);

void main() {
  group('recommended model bundle (LLM-07 tiers over the MDL-01 catalog)', () {
    final smallLlm = seedLlm;
    final bigLlm = catalogModel(
      'llama-3b',
      type: ModelType.llm,
      size: 2000 * 1000 * 1000,
      minRamMb: 6144,
      tiers: const [DeviceTier.high],
    );
    final catalog = catalogOf([seedStt, smallLlm, bigLlm]);

    test('device check → STT + LLM with sizes for the device tier', () {
      final b = recommendBundle(_device(8), catalog, LlmPlanGate.free());
      expect(b.tier, DeviceTier.high);
      expect(b.deviceKnown, isTrue);
      expect(b.models.map((m) => m.id), [seedStt.id, smallLlm.id]);
      expect(b.totalBytes, seedStt.size + smallLlm.size);
    });

    test('a paid plan on a high-end device gets the large LLM', () {
      final b = recommendBundle(
        _device(8),
        catalog,
        LlmPlanGate(largeLlm: () => true),
      );
      expect(b.models.map((m) => m.id), [seedStt.id, bigLlm.id]);
    });

    test('unknown device → assumes a 4 GB phone (never overshoots)', () {
      final b = recommendBundle(
        null,
        catalog,
        LlmPlanGate(largeLlm: () => true),
      );
      expect(b.deviceKnown, isFalse);
      expect(b.tier, DeviceTier.low);
      expect(b.models.map((m) => m.id), [seedStt.id, smallLlm.id]);
    });

    test('remaining bytes and completeness follow installed ids', () {
      final b = recommendBundle(_device(4), catalog, LlmPlanGate.free());
      expect(b.remainingBytes({seedStt.id}), smallLlm.size);
      expect(b.isComplete({seedStt.id}), isFalse);
      expect(b.isComplete({seedStt.id, smallLlm.id}), isTrue);
      expect(b.remainingBytes({seedStt.id, smallLlm.id}), 0);
    });
  });

  group('onboarding redirect', () {
    test('required → every location goes to /onboarding', () {
      expect(
        onboardingRedirect(required: true, path: '/record'),
        '/onboarding',
      );
      expect(
        onboardingRedirect(required: true, path: '/library/recordings/x'),
        '/onboarding',
      );
      expect(onboardingRedirect(required: true, path: '/onboarding'), isNull);
    });

    test('completed but not ready → only Record is gated', () {
      expect(
        onboardingRedirect(
          required: false,
          path: '/record',
          recordingBlocked: true,
        ),
        '/onboarding',
      );
      for (final path in ['/library', '/settings', '/library/recordings/x']) {
        expect(
          onboardingRedirect(
            required: false,
            path: path,
            recordingBlocked: true,
          ),
          isNull,
        );
      }
      expect(onboardingRedirect(required: false, path: '/record'), isNull);
    });

    test('completed or unknown → no redirect', () {
      expect(onboardingRedirect(required: false, path: '/record'), isNull);
      expect(onboardingRedirect(required: null, path: '/record'), isNull);
      expect(onboardingRedirect(required: false, path: '/onboarding'), isNull);
    });
  });

  group('ModelInstallWaker (queue processing until models are ready)', () {
    test('a newly installed model resolves jobs waiting for a model', () async {
      final installed = StreamController<Set<String>>();
      final resolved = <String>[];
      var waiting = <String>['job-1', 'job-2'];
      final waker = ModelInstallWaker(
        installedIds: installed.stream,
        waitingJobIds: () async => waiting,
        resolve: (id) async => resolved.add(id),
      )..start();
      addTearDown(waker.dispose);

      installed.add({});
      await pumpEventQueue();
      expect(resolved, ['job-1', 'job-2'], reason: 'first snapshot re-checks');

      resolved.clear();
      waiting = ['job-3'];
      installed.add({}); // nothing new installed
      await pumpEventQueue();
      expect(resolved, isEmpty);

      installed.add({'whisper-tiny.en'});
      await pumpEventQueue();
      expect(resolved, ['job-3']);

      resolved.clear();
      installed.add({}); // a model was deleted: cannot unblock anything
      await pumpEventQueue();
      expect(resolved, isEmpty);
    });
  });
}
