import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/stt_engine.dart';

/// Live-transcription harness shared by the on-device STT-03 integration
/// test (`integration_test/stt_engine_test.dart`) and its host self-test
/// (`test/unit/transcription/stt_live_harness_test.dart`), so the checks the
/// device run relies on are themselves proven to fail on bad data.
///
/// Everything asserted here is read back from the **rendered widget tree**
/// (not from callback variables), the frame floor is explicit and the cancel
/// is only issued while the run is demonstrably still active.

/// Keys of the rendered live view.
const kSttProgressKey = ValueKey<String>('stt-live-progress');
const kSttSegmentCountKey = ValueKey<String>('stt-live-segment-count');
const kSttLatestSegmentKey = ValueKey<String>('stt-live-latest-segment');

/// AC1/AC3 budget: cancel must finish in under 1 s.
const kCancelBudget = Duration(seconds: 1);

/// AC2 budget: p99 build+raster during transcription (vv-testing "Measuring
/// UI jank").
const kFrameBudgetUs = 16000;

/// Minimum number of `FrameTiming` samples that make a frame-budget verdict
/// meaningful for a measured [window]: at least half of the frames a 60 Hz
/// display would draw, never fewer than 60. Zero samples can never pass.
int minFrameSamplesFor(Duration window) {
  final half60Hz = window.inMilliseconds ~/ 33;
  return half60Hz < 60 ? 60 : half60Hz;
}

/// Engine callbacks → listenable state the view renders.
class SttLiveState extends ChangeNotifier {
  double _progress = 0;
  final List<TranscriptSegment> _segments = [];

  double get progress => _progress;
  List<TranscriptSegment> get segments => List.unmodifiable(_segments);

  void onProgress(double fraction) {
    _progress = fraction;
    notifyListeners();
  }

  void onSegment(TranscriptSegment segment) {
    _segments.add(segment);
    notifyListeners();
  }
}

/// The on-screen live view: progress bar, segment counter, latest segment.
class SttLiveView extends StatelessWidget {
  const SttLiveView({required this.state, super.key});

  final SttLiveState state;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final segs = state.segments;
          return Column(
            children: [
              // Keeps frames flowing so FrameTiming samples exist.
              const CircularProgressIndicator(),
              LinearProgressIndicator(
                key: kSttProgressKey,
                value: state.progress,
              ),
              Text('${segs.length} segments', key: kSttSegmentCountKey),
              if (segs.isNotEmpty)
                Text(segs.last.text, key: kSttLatestSegmentKey),
            ],
          );
        },
      ),
    ),
  );
}

/// One sample of what the screen displayed after a pump.
class DisplayedSample {
  const DisplayedSample({
    required this.elapsed,
    required this.progress,
    required this.segmentCount,
    required this.latestSegmentShown,
  });

  final Duration elapsed;
  final double progress;
  final int segmentCount;
  final bool latestSegmentShown;
}

/// Reads the live view's displayed values from the widget tree.
DisplayedSample readDisplayed(WidgetTester tester, Duration elapsed) {
  final bar = tester.widget<LinearProgressIndicator>(
    find.byKey(kSttProgressKey),
  );
  final count = tester.widget<Text>(find.byKey(kSttSegmentCountKey)).data!;
  return DisplayedSample(
    elapsed: elapsed,
    progress: bar.value ?? 0,
    segmentCount: int.parse(count.split(' ').first),
    latestSegmentShown: find.byKey(kSttLatestSegmentKey).evaluate().isNotEmpty,
  );
}

/// What one live run observed.
class SttLiveReport {
  const SttLiveReport({
    required this.displayed,
    required this.completedBeforeCancel,
    required this.cancelIssued,
    required this.result,
    required this.cancelLatency,
    required this.frameSpansUs,
    required this.liveWindow,
  });

  /// Displayed values sampled after every pump before cancel.
  final List<DisplayedSample> displayed;

  /// The run finished (any result) before cancel could be issued.
  final bool completedBeforeCancel;
  final bool cancelIssued;
  final Result<Transcript>? result;

  /// Cancel → run future completed.
  final Duration cancelLatency;

  /// `FrameTiming.totalSpan` (µs) collected during the live window.
  final List<int> frameSpansUs;

  /// How long the run was observed live before cancel.
  final Duration liveWindow;

  SttLiveReport withFrames(List<int> spansUs) => SttLiveReport(
    displayed: displayed,
    completedBeforeCancel: completedBeforeCancel,
    cancelIssued: cancelIssued,
    result: result,
    cancelLatency: cancelLatency,
    frameSpansUs: spansUs,
    liveWindow: liveWindow,
  );

  int get p99FrameUs {
    if (frameSpansUs.isEmpty) return -1; // never a passing value
    final s = [...frameSpansUs]..sort();
    final i = (s.length * 0.99).floor();
    return s[i >= s.length ? s.length - 1 : i];
  }

  Map<String, Object> toReportData() => {
    'frames': frameSpansUs.length,
    'p99_frame_us': p99FrameUs,
    'cancel_ms': cancelLatency.inMilliseconds,
    'live_window_ms': liveWindow.inMilliseconds,
    'segments_before_cancel': displayed.isEmpty
        ? 0
        : displayed.last.segmentCount,
    'completed_before_cancel': completedBeforeCancel,
  };
}

/// AC1/AC3 problems: live UI rebuilt with advancing progress and segments,
/// cancel issued while active, `CancelledFailure` within [kCancelBudget].
/// Empty list = pass.
List<String> liveUiProblems(SttLiveReport r) {
  final p = <String>[];
  final shown = r.displayed;
  final distinctProgress = <double>{
    for (final s in shown)
      if (s.progress > 0) s.progress,
  };
  if (distinctProgress.length < 2) {
    p.add(
      'displayed progress never advanced (distinct >0 values: '
      '${distinctProgress.length}, need ≥ 2)',
    );
  }
  for (var i = 1; i < shown.length; i++) {
    if (shown[i].progress < shown[i - 1].progress) {
      p.add('displayed progress went backwards at sample $i');
      break;
    }
  }
  final maxSegs = shown.fold<int>(
    0,
    (m, s) => s.segmentCount > m ? s.segmentCount : m,
  );
  if (maxSegs == 0 || !shown.any((s) => s.latestSegmentShown)) {
    p.add('no segment was displayed before cancel');
  }
  if (r.completedBeforeCancel) {
    p.add('transcription completed before cancel was issued');
  }
  if (!r.cancelIssued) p.add('cancel was never issued');
  if (r.result?.failureOrNull is! CancelledFailure) {
    p.add('run did not end with CancelledFailure');
  }
  if (r.cancelLatency >= kCancelBudget) {
    p.add('cancel took ${r.cancelLatency.inMilliseconds} ms (≥ 1000 ms)');
  }
  return p;
}

/// AC2 problems: enough frame samples for [SttLiveReport.liveWindow] and
/// p99 build+raster ≤ [kFrameBudgetUs]. Empty list = pass.
List<String> frameBudgetProblems(SttLiveReport r) {
  final p = <String>[];
  final floor = minFrameSamplesFor(r.liveWindow);
  if (r.frameSpansUs.length < floor) {
    p.add(
      'only ${r.frameSpansUs.length} frame timings in '
      '${r.liveWindow.inMilliseconds} ms (need ≥ $floor)',
    );
  }
  final p99 = r.p99FrameUs;
  if (p99 < 0 || p99 > kFrameBudgetUs) {
    p.add('p99 frame $p99 µs exceeds $kFrameBudgetUs µs');
  }
  return p;
}

/// Starts [start] (a transcription wired to [state]'s callbacks and
/// [cancel]), pumps frames of [frame] length and samples the displayed
/// values. Cancels once the run has been live for at least [minLive] and
/// [minSegments] segments are on screen; never cancels a run that already
/// finished (that is reported as [SttLiveReport.completedBeforeCancel]).
/// Gives up (no cancel) after [maxLive].
///
/// Time is measured as pumped time, which is real time on a device
/// (`LiveTestWidgetsFlutterBinding.pump` waits) and fake time on the host.
Future<SttLiveReport> runLiveAndCancel(
  WidgetTester tester, {
  required SttLiveState state,
  required CancelToken cancel,
  required Future<Result<Transcript>> Function() start,
  Duration minLive = const Duration(seconds: 3),
  Duration maxLive = const Duration(seconds: 60),
  int minSegments = 2,
  Duration frame = const Duration(milliseconds: 16),
}) async {
  await tester.pumpWidget(SttLiveView(state: state));
  Result<Transcript>? result;
  var done = false;
  final run = start().then((r) {
    result = r;
    done = true;
    return r;
  });
  final displayed = <DisplayedSample>[];
  var elapsed = Duration.zero;
  var cancelIssued = false;
  var completedBeforeCancel = false;
  while (true) {
    await tester.pump(frame);
    elapsed += frame;
    if (done) {
      completedBeforeCancel = true;
      break;
    }
    final shown = readDisplayed(tester, elapsed);
    displayed.add(shown);
    if (elapsed >= minLive && shown.segmentCount >= minSegments) {
      cancel.cancel();
      cancelIssued = true;
      break;
    }
    if (elapsed >= maxLive) break;
  }
  final liveWindow = elapsed;
  var latency = Duration.zero;
  if (cancelIssued) {
    final sw = Stopwatch()..start();
    var pumped = Duration.zero;
    // Pump until the run settles; cap at 5× the budget so a hang reports a
    // latency instead of timing out the test.
    while (!done && pumped < kCancelBudget * 5) {
      await tester.pump(frame);
      pumped += frame;
    }
    sw.stop();
    // On a device (live binding) pump waits real time, so wall clock is the
    // truth and also catches work beyond the pumped frames. Under the host's
    // fake-async binding only pumped time is meaningful (wall clock there
    // measures test-runner load, not the engine).
    final live = tester.binding is LiveTestWidgetsFlutterBinding;
    latency = live && sw.elapsed > pumped ? sw.elapsed : pumped;
  }
  if (done) await run;
  return SttLiveReport(
    displayed: displayed,
    completedBeforeCancel: completedBeforeCancel,
    cancelIssued: cancelIssued,
    result: result,
    cancelLatency: latency,
    frameSpansUs: const [],
    liveWindow: liveWindow,
  );
}
