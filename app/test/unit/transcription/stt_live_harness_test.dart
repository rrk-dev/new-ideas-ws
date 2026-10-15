import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/stt_engine.dart';

import '../../../integration_test/support/stt_live_harness.dart';
import '../../fakes/fake_stt_engine.dart';

/// Host self-test of the on-device STT-03 harness
/// (`integration_test/support/stt_live_harness.dart`): every check the
/// device run relies on must fail on bad data and pass on good data.
void main() {
  List<TranscriptSegment> segs(int n) => [
    for (var i = 0; i < n; i++)
      TranscriptSegment(
        start: Duration(seconds: i),
        end: Duration(seconds: i + 1),
        text: 'segment $i',
      ),
  ];

  SttLiveReport goodReport({List<int>? frames}) => SttLiveReport(
    displayed: const [
      DisplayedSample(
        elapsed: Duration(milliseconds: 16),
        progress: 0.01,
        segmentCount: 1,
        latestSegmentShown: true,
      ),
      DisplayedSample(
        elapsed: Duration(milliseconds: 32),
        progress: 0.02,
        segmentCount: 2,
        latestSegmentShown: true,
      ),
    ],
    completedBeforeCancel: false,
    cancelIssued: true,
    result: const Err(CancelledFailure()),
    cancelLatency: const Duration(milliseconds: 120),
    frameSpansUs: frames ?? List<int>.filled(200, 9000),
    liveWindow: const Duration(seconds: 3),
  );

  group('[STT-03/AC1] live UI + cancel checks', () {
    testWidgets('fails when the screen never rebuilds (callbacks only '
        'mutate state that is not rendered)', (tester) async {
      // Reproduces verifier issue 1: callbacks fire but nothing notifies the
      // view, so the displayed progress/segment count stay at 0.
      final state = _SilentState();
      final engine = FakeSttEngine(
        segments: segs(40),
        perChunk: const Duration(milliseconds: 100),
      );
      final cancel = CancelToken();
      final r = await runLiveAndCancel(
        tester,
        state: state,
        cancel: cancel,
        minLive: const Duration(seconds: 1),
        maxLive: const Duration(seconds: 2),
        start: () => engine.transcribe(
          'a.wav',
          cancel: cancel,
          onProgress: state.onProgress,
          onSegment: state.onSegment,
        ),
      );
      // Callbacks did run …
      expect(state.callbackCount, greaterThan(0));
      // … but the rendered view shows nothing, so the harness must fail.
      final problems = liveUiProblems(r);
      expect(problems, contains(startsWith('displayed progress never')));
      expect(problems, contains('no segment was displayed before cancel'));
      // Let the never-cancelled fake finish so no timer is left pending.
      cancel.cancel();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('fails when the run completes before cancel is issued', (
      tester,
    ) async {
      // Reproduces verifier issue 3: a fast device finishes the file before
      // the fixed 30 s cancel point.
      final state = SttLiveState();
      final engine = FakeSttEngine(
        segments: segs(5),
        perChunk: const Duration(milliseconds: 50),
      );
      final cancel = CancelToken();
      final r = await runLiveAndCancel(
        tester,
        state: state,
        cancel: cancel,
        minLive: const Duration(seconds: 30),
        start: () => engine.transcribe(
          'a.wav',
          cancel: cancel,
          onProgress: state.onProgress,
          onSegment: state.onSegment,
        ),
      );
      expect(r.completedBeforeCancel, isTrue);
      expect(r.cancelIssued, isFalse);
      expect(cancel.isCancelled, isFalse, reason: 'never cancel a done run');
      final problems = liveUiProblems(r);
      expect(
        problems,
        contains('transcription completed before cancel was issued'),
      );
      expect(problems, contains('run did not end with CancelledFailure'));
    });

    test('fails on a non-cancelled result or a slow cancel', () {
      final ok = goodReport();
      expect(liveUiProblems(ok), isEmpty);
      final notCancelled = SttLiveReport(
        displayed: ok.displayed,
        completedBeforeCancel: false,
        cancelIssued: true,
        result: Ok(Transcript(segs(1))),
        cancelLatency: const Duration(milliseconds: 1000),
        frameSpansUs: ok.frameSpansUs,
        liveWindow: ok.liveWindow,
      );
      final problems = liveUiProblems(notCancelled);
      expect(problems, contains('run did not end with CancelledFailure'));
      expect(problems, contains(startsWith('cancel took 1000 ms')));
    });

    testWidgets('passes for a streaming run cancelled while active; the '
        'displayed values come from the widget tree', (tester) async {
      final state = SttLiveState();
      final engine = FakeSttEngine(
        segments: segs(600), // 60 s of fake work — far longer than minLive
        perChunk: const Duration(milliseconds: 100),
      );
      final cancel = CancelToken();
      final r = await runLiveAndCancel(
        tester,
        state: state,
        cancel: cancel,
        start: () => engine.transcribe(
          'a.wav',
          cancel: cancel,
          onProgress: state.onProgress,
          onSegment: state.onSegment,
        ),
      );
      expect(liveUiProblems(r), isEmpty);
      expect(r.cancelIssued, isTrue);
      expect(r.completedBeforeCancel, isFalse);
      expect(r.liveWindow, greaterThanOrEqualTo(const Duration(seconds: 3)));
      // Displayed progress strictly increased across samples.
      final shown = r.displayed.map((s) => s.progress).toSet();
      expect(shown.length, greaterThan(10));
      expect(r.displayed.last.segmentCount, greaterThanOrEqualTo(2));
      // The screen shows the latest segment text.
      expect(find.byKey(kSttLatestSegmentKey), findsOneWidget);
      expect(find.text('${state.segments.length} segments'), findsOneWidget);
    });
  });

  group('[STT-03/AC2] frame-budget checks', () {
    test('zero frame samples never pass (was p99 = 0)', () {
      final r = goodReport(frames: const []);
      expect(r.p99FrameUs, -1);
      final problems = frameBudgetProblems(r);
      expect(problems, contains(startsWith('only 0 frame timings')));
      expect(problems, contains(startsWith('p99 frame -1')));
    });

    test('too few samples for the window fail even if all are fast', () {
      // 3 s window → floor 90 frames.
      expect(minFrameSamplesFor(const Duration(seconds: 3)), 90);
      expect(minFrameSamplesFor(const Duration(seconds: 1)), 60);
      final r = goodReport(frames: List<int>.filled(89, 1000));
      expect(frameBudgetProblems(r), [startsWith('only 89 frame timings')]);
    });

    test('p99 above 16 ms fails; at or below passes', () {
      final slow = [...List<int>.filled(195, 8000), ...List<int>.filled(5, 17000)];
      expect(frameBudgetProblems(goodReport(frames: slow)), [
        startsWith('p99 frame 17000'),
      ]);
      final edge = List<int>.filled(200, kFrameBudgetUs);
      expect(frameBudgetProblems(goodReport(frames: edge)), isEmpty);
      expect(goodReport().toReportData()['frames'], 200);
    });
  });
}

/// The old harness's shape: callbacks update fields, nothing notifies the
/// view.
class _SilentState extends SttLiveState {
  int callbackCount = 0;

  @override
  void onProgress(double fraction) => callbackCount++;

  @override
  void onSegment(TranscriptSegment segment) => callbackCount++;
}

