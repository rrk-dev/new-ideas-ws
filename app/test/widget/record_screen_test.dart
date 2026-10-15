import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/flavor.dart';
import 'package:vaultvoice/core/flavor_provider.dart';
import 'package:vaultvoice/core/platform/call_guard.dart';
import 'package:vaultvoice/features/onboarding/domain/onboarding_keys.dart';
import 'package:vaultvoice/features/recording/data/recording_providers.dart';
import 'package:vaultvoice/features/recording/data/recording_screen_providers.dart';
import 'package:vaultvoice/features/recording/data/recording_session_service.dart';
import 'package:vaultvoice/features/recording/domain/level_meter.dart';
import 'package:vaultvoice/features/recording/domain/recording_controller.dart';
import 'package:vaultvoice/features/recording/domain/recording_session.dart';
import 'package:vaultvoice/features/recording/presentation/recording_screen.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

import '../fakes/fake_call_guard.dart';
import '../fakes/fake_capture_backend.dart';
import '../fakes/fake_recording_indicator.dart';
import '../fakes/fake_settings_store.dart';

class _Active implements ActiveRecording {
  @override
  String? recordingId;

  @override
  Duration recorded = Duration.zero;
}

class _Session implements RecordingSessionService {
  final applied = <(String, RecordingSetup, DateTime?)>[];
  final markers = <(String, Duration)>[];
  final details = <(String, String, List<String>, RecordingSetup)>[];

  @override
  Future<Result<void>> applySetup(
    String recordingId,
    RecordingSetup setup, {
    DateTime? consentConfirmedAt,
  }) async {
    applied.add((recordingId, setup, consentConfirmedAt));
    return const Ok(null);
  }

  @override
  Future<Result<int>> addMarker(String recordingId, Duration at) async {
    markers.add((recordingId, at));
    return Ok(markers.length);
  }

  @override
  Future<Result<void>> saveDetails(
    String recordingId, {
    required String title,
    required List<String> tags,
    required RecordingSetup setup,
  }) async {
    details.add((recordingId, title, tags, setup));
    return const Ok(null);
  }

  int finished = 0;
  bool autoProcess = true;
  final processedNow = <String>[];

  @override
  Future<bool> finish(String recordingId) async {
    finished++;
    return autoProcess;
  }

  @override
  Future<bool> processNow(String recordingId) async {
    processedNow.add(recordingId);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeCaptureBackend capture;
  late FakeCallGuard guard;
  late _Active active;
  late _Session session;
  late StreamController<AudioLevel> levels;

  setUp(() {
    capture = FakeCaptureBackend();
    guard = FakeCallGuard();
    active = _Active();
    session = _Session();
    levels = StreamController<AudioLevel>.broadcast();
    capture.onOpen = () => active.recordingId = 'rec-1';
  });
  tearDown(() => levels.close());

  Future<void> pump(
    WidgetTester t, {
    bool micPrimed = true,
    List<ProfileChoice> profiles = const [
      ProfileChoice(id: 'meeting', name: 'Meeting'),
      ProfileChoice(id: 'interview', name: 'Interview', consentRequired: true),
    ],
  }) async {
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          captureBackendProvider.overrideWithValue(capture),
          // APP-01 priming state (integration W3).
          settingsStoreProvider.overrideWithValue(
            FakeSettingsStore({if (micPrimed) OnboardingKeys.micPrimed: true}),
          ),
          callGuardProvider.overrideWithValue(guard),
          flavorProvider.overrideWithValue(Flavor.prod),
          recordingIndicatorProvider.overrideWithValue(
            FakeRecordingIndicator(),
          ),
          activeRecordingProvider.overrideWithValue(active),
          recordingSessionServiceProvider.overrideWithValue(session),
          profileChoicesProvider.overrideWith((ref) => Stream.value(profiles)),
          destinationChoicesProvider.overrideWith(
            (ref) async => const [
              DestinationChoice(id: 'v1', name: 'Obsidian vault'),
            ],
          ),
          recordingLevelsProvider.overrideWith((ref) => levels.stream),
          recoveredRecordingsProvider.overrideWith((ref) async => const []),
          batteryStatusProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(home: RecordScreen()),
      ),
    );
    await t.pumpAndSettle();
  }

  Finder main() => find.byKey(const ValueKey('record-main'));
  String status(WidgetTester t) =>
      t.widget<Text>(find.byKey(const ValueKey('record-status'))).data!;

  testWidgets('[AUD-08/AC1] opening the screen never opens the microphone; '
      'the Record tap opens it immediately (< 300 ms, no other await first)', (
    t,
  ) async {
    await pump(t);
    expect(capture.calls, isEmpty, reason: 'no pre-capture');
    expect(status(t), 'Ready to record');
    // Integration W3: measured tap → microphone open (inside
    // openMicrophone), not the frame rendered afterwards — the full suite
    // runs widget tests in parallel and a frame alone can take > 300 ms.
    final sw = Stopwatch()..start();
    int? openedMs;
    final onOpen = capture.onOpen;
    capture.onOpen = () {
      onOpen?.call();
      openedMs ??= sw.elapsedMilliseconds;
    };
    await t.tap(main());
    await t.pump();
    expect(capture.calls.first, isA<OpenCall>());
    expect(capture.micOpen, isTrue);
    expect(openedMs, lessThan(300));
    expect(status(t), 'Recording');
  });

  testWidgets('[AUD-08/AC3] idle → recording → paused → recording → stopped '
      'with timer, meter and details sheet', (t) async {
    await pump(t);
    expect(find.text('00:00'), findsOneWidget);
    expect(find.byKey(const ValueKey('level-meter')), findsNothing);
    await t.tap(main());
    await t.pump();
    expect(status(t), 'Recording');
    expect(find.byKey(const ValueKey('level-meter')), findsOneWidget);
    expect(session.applied.single.$1, 'rec-1');

    levels.add(const AudioLevel(rmsDbfs: -20, peakDbfs: -10));
    await t.pump();

    await t.tap(main()); // Pause
    await t.pump();
    expect(status(t), 'Paused');
    expect(capture.suspends.single.gap, GapKind.userPause);

    await t.tap(main()); // Resume
    await t.pump();
    expect(status(t), 'Recording');

    await t.tap(find.byKey(const ValueKey('record-stop')));
    await t.pumpAndSettle();
    expect(capture.calls.last, isA<CloseCall>());
    expect(find.text('Recording saved'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('details-title')), ' Standup ');
    await t.enterText(find.byKey(const ValueKey('details-tags')), 'a, b');
    await t.tap(find.byKey(const ValueKey('details-save')));
    await t.pumpAndSettle();
    final d = session.details.single;
    expect((d.$1, d.$2), ('rec-1', ' Standup '));
    expect(d.$3, ['a', ' b']);
    expect(status(t), 'Ready to record');
  });

  testWidgets('[AUD-08/AC3] "Recording unavailable during calls": refused '
      'start, and shown on open when a call is active', (t) async {
    guard.inCall = true;
    await pump(t);
    expect(find.text('Recording is unavailable during calls'), findsOneWidget);
    expect(t.widget<FilledButton>(main()).onPressed, isNull);
    expect(capture.calls, isEmpty);
  });

  testWidgets('[AUD-08/AC3] the call block clears after hang-up', (t) async {
    guard.inCall = true;
    await pump(t);
    expect(t.widget<FilledButton>(main()).onPressed, isNull);
    guard.emit(CallGuardSignal.callEnded, DateTime.now());
    await t.pump();
    await t.pump();
    expect(find.text('Recording is unavailable during calls'), findsNothing);
    expect(t.widget<FilledButton>(main()).onPressed, isNotNull);
  });

  testWidgets('[AUD-08/AC3] a call while recording pauses with the call '
      'message and never resumes by itself', (t) async {
    await pump(t);
    await t.tap(main());
    await t.pump();
    guard.emit(CallGuardSignal.callActive, DateTime.now());
    await t.pump();
    expect(status(t), contains('a call started'));
    guard.emit(CallGuardSignal.callEnded, DateTime.now());
    await t.pump(const Duration(seconds: 2));
    expect(status(t), contains('a call started'));
    expect(capture.calls.whereType<ResumeCall>(), isEmpty);
    // Resume only by tap.
    await t.tap(main());
    await t.pump();
    expect(status(t), 'Recording');
  });

  testWidgets('[AUD-08/AC3] OS interruption / capture error states', (t) async {
    await pump(t);
    await t.tap(main());
    await t.pump();
    capture.notify(CaptureNotice.interrupted);
    await t.pump();
    expect(status(t), contains('took the microphone'));
    await t.tap(main());
    await t.pump();
    capture.notify(CaptureNotice.captureFailed);
    await t.pump();
    expect(status(t), contains('microphone stopped'));
    capture.notify(CaptureNotice.lowStorageWarning);
    await t.pump();
    expect(find.text('Storage is almost full.'), findsOneWidget);
  });

  testWidgets('integration W3 (AUD-08 ↔ APP-01): the first Record tap '
      'explains the microphone; "Not now" opens nothing, Continue records', (
    t,
  ) async {
    await pump(t, micPrimed: false);
    await t.tap(main());
    await t.pumpAndSettle();
    expect(find.text('Allow microphone access'), findsOneWidget);
    await t.tap(find.text('Not now'));
    await t.pumpAndSettle();
    expect(capture.calls, isEmpty, reason: 'nothing requested');

    await t.tap(main());
    await t.pumpAndSettle();
    await t.tap(find.text('Continue'));
    await t.pump();
    expect(capture.calls.first, isA<OpenCall>());
    await t.pump(const Duration(seconds: 1));
    // Primed now: the next start needs no dialog.
    expect(find.text('Allow microphone access'), findsNothing);
  });

  testWidgets('[AUD-08/AC3] permission denied and call state unknown are '
      'explained', (t) async {
    capture.failWith(const PermissionFailure('microphone'));
    await pump(t);
    await t.tap(main());
    await t.pump();
    expect(find.textContaining('Microphone access is off'), findsOneWidget);

    guard.unavailable = true;
    await t.tap(main());
    await t.pump();
    expect(
      find.textContaining('call state could not be checked'),
      findsOneWidget,
    );
  });

  testWidgets('[AUD-08/AC3] consent profile: the confirmation blocks the '
      'microphone until confirmed (SEC-07 hook)', (t) async {
    await pump(t);
    await t.tap(find.byKey(const ValueKey('record-profile')));
    await t.pumpAndSettle();
    await t.tap(find.text('Interview').last);
    await t.pumpAndSettle();

    await t.tap(main());
    await t.pumpAndSettle();
    expect(find.byType(ConsentDialog), findsOneWidget);
    expect(capture.calls, isEmpty, reason: 'mic stays closed while asking');
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(capture.calls, isEmpty);

    await t.tap(main());
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('consent-confirm')));
    await t.pump();
    expect(capture.calls.single, isA<OpenCall>());
    await t.pump();
    final applied = session.applied.single;
    expect(applied.$2.profileId, 'interview');
    expect(applied.$3, isNotNull, reason: 'consent_confirmed_at');
  });

  testWidgets('[AUD-08/AC2] the marker button stores the recorded time', (
    t,
  ) async {
    await pump(t);
    final marker = find.byKey(const ValueKey('record-marker'));
    expect(
      t
          .widget<IconButton>(
            find.descendant(of: marker, matching: find.byType(IconButton)),
          )
          .onPressed,
      isNull,
    );
    await t.tap(main());
    await t.pump();
    active.recorded = const Duration(milliseconds: 4321);
    await t.tap(find.descendant(of: marker, matching: find.byType(IconButton)));
    await t.pump();
    expect(session.markers.single, (
      'rec-1',
      const Duration(milliseconds: 4321),
    ));
    expect(find.text('Moment marked'), findsOneWidget);
  });

  testWidgets('[AUD-08/AC3] the record button announces its action and the '
      'state to screen readers', (t) async {
    final handle = t.ensureSemantics();
    await pump(t);
    expect(
      t.getSemantics(main()),
      matchesSemantics(
        label: 'Start recording',
        value: 'Ready to record',
        isButton: true,
        hasTapAction: true,
        isEnabled: true,
        hasEnabledState: true,
        isFocusable: true,
      ),
    );
    await t.tap(main());
    await t.pump();
    expect(t.getSemantics(main()).label, 'Pause recording');
    expect(t.getSemantics(main()).value, 'Recording');
    handle.dispose();
  });

  testWidgets('auto-stop (silence / max length) also opens the details '
      'sheet with the reason', (t) async {
    await pump(t);
    await t.tap(main());
    await t.pump();
    final controller = ProviderScope.containerOf(
      t.element(find.byType(RecordScreen)),
    ).read(recordingControllerProvider);
    await controller.stop(cause: StopCause.maxDuration);
    await t.pumpAndSettle();
    expect(find.text('Recording saved'), findsOneWidget);
    expect(find.byKey(const ValueKey('details-stop-cause')), findsOneWidget);
    await t.tap(find.text('Later'));
    await t.pumpAndSettle();
    expect(session.details, isEmpty);
  });

  testWidgets('[AUD-08] stop queues the recording when auto-process is on; '
      'otherwise the sheet offers Process now', (t) async {
    await pump(t);
    await t.tap(main());
    await t.pump();
    await t.tap(find.byKey(const ValueKey('record-stop')));
    await t.pumpAndSettle();
    // Auto-process waits until the sheet has saved the user's edits.
    expect(session.finished, 0);
    await t.tap(find.text('Later'));
    await t.pumpAndSettle();
    expect(session.finished, 1);

    session.autoProcess = false;
    active.recordingId = null;
    capture.onOpen = () => active.recordingId = 'rec-2';
    await t.tap(main());
    await t.pump();
    await t.tap(find.byKey(const ValueKey('record-stop')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('details-process-now')));
    await t.pumpAndSettle();
    expect(session.processedNow, ['rec-2']);
    expect(find.byKey(const ValueKey('details-queued')), findsOneWidget);
  });
}
