import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/backend_policy.dart';
import 'package:vaultvoice/core/platform/device_capabilities.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/features/extraction/domain/device_tiering.dart'
    show ThermalState;
import 'package:vaultvoice/features/extraction/domain/llm_backend_policy.dart';
import 'package:vaultvoice/features/extraction/domain/llm_service.dart';
import 'package:vaultvoice/features/extraction/domain/model_residency.dart';
import 'package:vaultvoice/features/pipeline/data/active_engines.dart';
import 'package:vaultvoice/features/pipeline/data/background_guard.dart';
import 'package:vaultvoice/features/pipeline/data/method_channel_background_processing.dart';
import 'package:vaultvoice/features/pipeline/domain/background_platform.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_client.dart';
import 'package:vaultvoice/features/pipeline/domain/processing_conditions.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';

import '../../db/db_test_utils.dart';
import '../../fakes/fake_device_capabilities.dart';
import '../../fakes/fake_llm_runtime.dart';

class _Platform implements BackgroundProcessingPlatform {
  final events$ = StreamController<BackgroundEvent>.broadcast();
  DeviceConditions now = const DeviceConditions(charging: true);
  final calls = <String>[];

  @override
  Stream<BackgroundEvent> get events => events$.stream;

  @override
  Future<DeviceConditions> conditions() async => now;

  @override
  Future<void> beginProcessing({
    required String title,
    required String text,
  }) async => calls.add('begin:$title');

  @override
  Future<void> updateProgress(int percent) async =>
      calls.add('progress:$percent');

  @override
  Future<void> endProcessing() async => calls.add('end');

  @override
  Future<void> scheduleDeferred() async => calls.add('schedule');

  @override
  Future<void> completeDeferred({required bool success}) async =>
      calls.add('complete:$success');
}

class _Client implements PipelineClient {
  final calls = <String>[];

  @override
  Future<Result<void>> pause(String jobId) async {
    calls.add('pause:$jobId');
    return const Ok(null);
  }

  @override
  Future<Result<void>> resume(String jobId) async {
    calls.add('resume:$jobId');
    return const Ok(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

JobSnapshot _job(
  String id,
  JobState state, {
  int priority = 0,
  double progress = 0,
}) => JobSnapshot(
  id: id,
  recordingId: 'r-$id',
  state: state,
  step: PipelineStepId.transcribe,
  priority: priority,
  progress: progress,
  createdAt: t0,
  updatedAt: t0,
);

void main() {
  group('[FND-08/AC1] [FND-08/AC2] hold rules (thermal, power, charging)', () {
    test('holdReason table', () {
      const cool = DeviceConditions(charging: true);
      expect(holdReason(cool, chargeOnly: true, userForced: false), isNull);
      expect(
        holdReason(
          const DeviceConditions(thermal: ThermalState.critical),
          chargeOnly: false,
          userForced: true,
        ),
        HoldReason.thermal,
      );
      const hot = DeviceConditions(
        charging: true,
        thermal: ThermalState.serious,
      );
      expect(
        holdReason(hot, chargeOnly: false, userForced: false),
        HoldReason.thermal,
      );
      expect(holdReason(hot, chargeOnly: false, userForced: true), isNull);
      expect(
        holdReason(
          cool,
          chargeOnly: false,
          userForced: true,
          backgroundExpired: true,
        ),
        HoldReason.backgroundTimeExpired,
      );
      const saver = DeviceConditions(charging: true, lowPower: true);
      expect(
        holdReason(saver, chargeOnly: false, userForced: false),
        HoldReason.lowPower,
      );
      expect(holdReason(saver, chargeOnly: false, userForced: true), isNull);
      const battery = DeviceConditions();
      expect(
        holdReason(battery, chargeOnly: true, userForced: false),
        HoldReason.notCharging,
      );
      expect(holdReason(battery, chargeOnly: false, userForced: false), isNull);
    });

    test('channel payloads decode; unknown ones are dropped', () {
      expect(
        MethodChannelBackgroundProcessing.decode({
          'kind': 'conditions',
          'charging': true,
          'lowPower': false,
          'thermal': 'serious',
        }),
        isA<ConditionsChanged>().having(
          (e) => e.conditions,
          'conditions',
          const DeviceConditions(charging: true, thermal: ThermalState.serious),
        ),
      );
      expect(
        MethodChannelBackgroundProcessing.decode({'kind': 'expiring'}),
        isA<BackgroundTimeExpiring>(),
      );
      expect(
        MethodChannelBackgroundProcessing.decode({'kind': 'deferredStarted'}),
        isA<DeferredProcessingStarted>(),
      );
      expect(MethodChannelBackgroundProcessing.decode({'kind': 'x'}), isNull);
      expect(MethodChannelBackgroundProcessing.decode(3), isNull);
      expect(
        DeviceConditions.fromMap(const {'thermal': 'lava'}),
        const DeviceConditions(),
      );
      expect('${const DeviceConditions()}', contains('unknown'));
      expect(
        const DeviceConditions().hashCode,
        const DeviceConditions().hashCode,
      );
    });

    test('the method channel speaks the documented protocol', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final calls = <MethodCall>[];
      const channel = MethodChannel(
        MethodChannelBackgroundProcessing.methodChannelName,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return call.method == 'conditions'
                ? {'charging': true, 'lowPower': true, 'thermal': 'fair'}
                : null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final p = MethodChannelBackgroundProcessing();
      expect(
        await p.conditions(),
        const DeviceConditions(
          charging: true,
          lowPower: true,
          thermal: ThermalState.fair,
        ),
      );
      await p.beginProcessing(title: 'T', text: 'B');
      await p.updateProgress(40);
      await p.endProcessing();
      await p.scheduleDeferred();
      await p.completeDeferred(success: true);
      expect(
        [for (final c in calls) c.method],
        [
          'conditions',
          'begin',
          'progress',
          'end',
          'scheduleDeferred',
          'completeDeferred',
        ],
      );
      expect(calls[1].arguments, {'title': 'T', 'text': 'B'});
      expect(calls[5].arguments, {'success': true});
    });
  });

  group('BackgroundProcessingGuard', () {
    late VaultVoiceDatabase db;
    late _Platform platform;
    late _Client client;
    late StreamController<List<JobSnapshot>> jobs;
    late BackgroundProcessingGuard guard;
    var workerStarts = 0;

    setUp(() async {
      db = memoryDb();
      platform = _Platform();
      client = _Client();
      jobs = StreamController<List<JobSnapshot>>.broadcast();
      workerStarts = 0;
      guard = BackgroundProcessingGuard(
        platform: platform,
        jobs: jobs.stream,
        client: () async {
          workerStarts++;
          return client;
        },
        settings: db.settingsRepository,
        texts: (title: 'Processing', text: 'On device'),
      );
      addTearDown(guard.dispose);
      await guard.start();
    });

    Future<void> push(List<JobSnapshot> list) async {
      jobs.add(list);
      await pumpEventQueue();
      await guard.settled();
    }

    Future<void> event(BackgroundEvent e) async {
      platform.events$.add(e);
      await pumpEventQueue();
      await guard.settled();
    }

    test('[FND-08/AC2] pending work holds the keep-alive (foreground service '
        '/ background task) with progress and starts the worker; an idle '
        'queue releases it', () async {
      await push([_job('a', JobState.transcribing, progress: 0.25)]);
      expect(platform.calls, ['begin:Processing', 'progress:25']);
      expect(workerStarts, greaterThan(0));
      await push([_job('a', JobState.transcribing, progress: 0.25)]);
      expect(platform.calls, hasLength(2), reason: 'no duplicate updates');
      await push([_job('a', JobState.extracting, progress: 0.5)]);
      expect(platform.calls.last, 'progress:50');
      await push([_job('a', JobState.done)]);
      expect(platform.calls.last, 'end');
      expect(client.calls, isEmpty);
      // Jobs waiting for the user/model are not work.
      await push([_job('w', JobState.waiting)]);
      expect(platform.calls.last, 'end');
    });

    test(
      '[FND-08/AC1] thermal critical pauses even "Process now" jobs and '
      'resumes exactly those once cool; a user-paused job stays paused',
      () async {
        await push([
          _job('a', JobState.transcribing, priority: 10),
          _job('u', JobState.paused),
        ]);
        await event(
          const ConditionsChanged(
            DeviceConditions(charging: true, thermal: ThermalState.critical),
          ),
        );
        expect(client.calls, ['pause:a']);
        expect(expectOk(await db.settingsRepository.get(kAutoPausedJobsKey)), [
          'a',
        ]);
        await push([_job('a', JobState.paused), _job('u', JobState.paused)]);
        expect(platform.calls.last, 'end');
        await event(
          const ConditionsChanged(
            DeviceConditions(charging: true, thermal: ThermalState.nominal),
          ),
        );
        expect(client.calls, ['pause:a', 'resume:a']);
        expect(
          expectOk(await db.settingsRepository.get(kAutoPausedJobsKey)),
          isEmpty,
        );
      },
    );

    test('"Process only while charging" defers background jobs but not '
        '"Process now"; plugging in resumes them', () async {
      platform.now = const DeviceConditions();
      expectOk(
        await db.settingsRepository.set(SettingKeys.processingChargeOnly, true),
      );
      await push([
        _job('auto', JobState.queued),
        _job('now', JobState.queued, priority: 10),
      ]);
      await event(const ConditionsChanged(DeviceConditions()));
      expect(client.calls, ['pause:auto']);
      expect(platform.calls.first, 'begin:Processing');
      await push([_job('auto', JobState.paused), _job('now', JobState.done)]);
      await event(const ConditionsChanged(DeviceConditions(charging: true)));
      expect(client.calls.last, 'resume:auto');
    });

    test(
      '[FND-08/AC1] leaving the foreground schedules deferred processing; '
      'background expiry checkpoints (pauses) and returning resumes',
      () async {
        await push([_job('a', JobState.transcribing)]);
        guard.setForeground(foreground: false);
        await guard.settled();
        expect(platform.calls, contains('schedule'));
        await event(const BackgroundTimeExpiring());
        expect(client.calls, ['pause:a']);
        await push([_job('a', JobState.paused)]);
        expect(platform.calls.last, 'end');
        guard.setForeground(foreground: true);
        await guard.settled();
        expect(client.calls, ['pause:a', 'resume:a']);
      },
    );

    test('[FND-08/AC1] a deferred task (BGProcessingTask) runs the queue and '
        'completes when idle', () async {
      guard.setForeground(foreground: false);
      await push([_job('a', JobState.queued)]);
      await event(const DeferredProcessingStarted());
      await push([_job('a', JobState.done)]);
      expect(platform.calls, containsAllInOrder(['begin:Processing', 'end']));
      expect(platform.calls.last, 'complete:true');
    });
  });

  test('[FND-08/AC3] no GPU (Metal) work while backgrounded: the worker LLM '
      'reloads on the CPU after the app leaves the foreground', () async {
    final caps = FakeDeviceCapabilities(
      gpus: const [GpuDevice(index: 0, name: 'MTL0', description: 'Apple A17')],
    );
    var foreground = true;
    final runtime = FakeLlmRuntime();
    final residency = ModelResidency();
    final llm = ActiveLlmEngine(
      resolve: () async =>
          const ActiveModel(id: 'l', path: '/m/l.gguf', sizeBytes: 1),
      residency: residency,
      create: (m) => LlmService(
        runtime: runtime,
        modelPath: m.path,
        backend: () => chooseLlmBackend(
          caps: caps,
          platform: DevicePlatform.ios,
          foreground: foreground,
        )!,
      ),
    );
    const request = LlmRequest(prompt: 'hi');
    await llm.generate(request);
    expect(runtime.loads.single.useGpu, isTrue);
    foreground = false;
    llm.setForeground(foreground: false);
    await llm.generate(request);
    expect(runtime.loads.last.useGpu, isFalse);
    expect(runtime.sessions.first.disposed, isTrue, reason: 'GPU freed');
  });
}
