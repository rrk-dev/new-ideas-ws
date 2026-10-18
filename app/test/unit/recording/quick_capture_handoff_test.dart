import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/platform/clock.dart';
import 'package:vaultvoice/features/recording/domain/quick_capture_handoff.dart';
import 'package:vaultvoice/features/recording/domain/recording_controller.dart';
import 'package:vaultvoice/features/recording/domain/start_source.dart';

import '../../fakes/fake_call_guard.dart';
import '../../fakes/fake_capture_backend.dart';

const _id = '3f2b8c5e-9d41-4a7b-8e6f-0c1d2e3f4a5b';

class _Source implements QuickCaptureSource {
  _Source(this._queue);

  final List<QuickCaptureMessage?> _queue;
  Exception? error;
  int calls = 0;

  @override
  Future<QuickCaptureMessage?> consumeRequest() async {
    calls++;
    if (error != null) throw error!;
    return _queue.isEmpty ? null : _queue.removeAt(0);
  }
}

QuickCaptureMessage _msg({
  String id = _id,
  String entry = 'iosWidget',
  String mode = 'navigate',
  int remainingMs = 9000,
}) => QuickCaptureMessage(
  id: id,
  entry: entry,
  mode: mode,
  remainingMs: remainingMs,
);

void main() {
  late FakeCaptureBackend capture;
  late RecordingController controller;
  late List<QuickCaptureEntry> navigations;

  setUp(() {
    capture = FakeCaptureBackend();
    controller = RecordingController(
      capture: capture,
      callGuard: FakeCallGuard(),
      clock: const SystemClock(),
      isAppInForeground: () => true,
    );
    navigations = [];
  });

  QuickCaptureHandoff handoff(_Source s) =>
      QuickCaptureHandoff(source: s, navigateToRecord: navigations.add);

  void expectNothingRecorded() {
    expect(controller.state.phase, RecordingPhase.idle);
    expect(capture.calls, isEmpty);
    expect(capture.micOpen, isFalse);
  }

  group('hand-off validation', () {
    test('[QCP-02/AC2] a valid request only navigates to Record; the '
        'recording controller is never started', () async {
      final h = handoff(_Source([_msg(entry: 'iosControl')]));
      expect(await h.consume(), QuickCaptureOutcome.navigated);
      expect(navigations, [QuickCaptureEntry.iosControl]);
      expectNothingRecorded();
    });

    test('[QCP-02/AC2] an app launch with no request does nothing', () async {
      final source = _Source([]);
      final h = handoff(source);
      expect(await h.consume(), QuickCaptureOutcome.none);
      expect(navigations, isEmpty);
      expectNothingRecorded();
    });

    test(
      '[QCP-02/AC2] a missing native store (macOS, tests) is ignored',
      () async {
        final source = _Source([])..error = Exception('no host');
        expect(await handoff(source).consume(), QuickCaptureOutcome.none);
        expect(navigations, isEmpty);
      },
    );

    test('[QCP-02/AC2] an expired request is dropped', () async {
      for (final remaining in [0, -1, -5000]) {
        final h = handoff(_Source([_msg(remainingMs: remaining)]));
        expect(await h.consume(), QuickCaptureOutcome.expired);
      }
      expect(navigations, isEmpty);
      expectNothingRecorded();
    });

    test('[QCP-02/AC2] a request is single-use: a replay of the same id is '
        'dropped', () async {
      final h = handoff(_Source([_msg(), _msg()]));
      expect(await h.consume(), QuickCaptureOutcome.navigated);
      expect(await h.consume(), QuickCaptureOutcome.replayed);
      expect(navigations, hasLength(1));
      expectNothingRecorded();
    });

    test('[QCP-02/AC2] only the last $quickCaptureReplayMemory ids are '
        'remembered', () async {
      String id(int i) => '3f2b8c5e-9d41-4a7b-8e6f-${'$i'.padLeft(12, '0')}';
      const n = quickCaptureReplayMemory;
      final h = handoff(
        _Source([
          for (var i = 0; i <= n; i++) _msg(id: id(i)),
          _msg(id: id(n)),
          _msg(id: id(0)),
        ]),
      );
      for (var i = 0; i <= n; i++) {
        expect(await h.consume(), QuickCaptureOutcome.navigated);
      }
      expect(await h.consume(), QuickCaptureOutcome.replayed);
      // id 0 was evicted by the 17th id, so it is accepted again.
      expect(await h.consume(), QuickCaptureOutcome.navigated);
    });

    test('[QCP-02/AC2] malformed requests are dropped: id, entry, mode, '
        'ttl', () async {
      final bad = [
        _msg(id: 'not-a-uuid'),
        _msg(id: ''),
        _msg(entry: 'inAppButton'),
        _msg(entry: 'androidQuickSettingsTile'),
        _msg(entry: ''),
        _msg(mode: 'start'),
        _msg(mode: 'record'),
        _msg(remainingMs: quickCaptureTtl.inMilliseconds + 1),
      ];
      for (final m in bad) {
        final h = handoff(_Source([m]));
        expect(await h.consume(), QuickCaptureOutcome.malformed);
      }
      expect(navigations, isEmpty);
      expectNothingRecorded();
    });

    test('[QCP-02/AC2] the hand-off type cannot start a recording: no '
        'controller, start or StartSource in its sources', () {
      for (final path in [
        'lib/features/recording/domain/quick_capture_handoff.dart',
        'lib/features/recording/data/pigeon_quick_capture.dart',
        'lib/features/recording/presentation/quick_capture_host.dart',
      ]) {
        final code = File(path)
            .readAsLinesSync()
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');
        expect(code, isNot(contains('RecordingController')), reason: path);
        expect(code, isNot(contains('StartSource')), reason: path);
        expect(code, isNot(matches(RegExp(r'\.\s*start\s*\('))), reason: path);
        expect(code, isNot(contains('openMicrophone')), reason: path);
      }
    });

    test('[QCP-02/AC2] drops are logged by reason only', () async {
      // The hand-off has no payload to log: the only field is the outcome.
      final h = QuickCaptureHandoff(
        source: _Source([_msg(id: 'x')]),
        navigateToRecord: navigations.add,
      );
      expect(await h.consume(), QuickCaptureOutcome.malformed);
      expect(QuickCaptureOutcome.malformed.isDropped, isTrue);
      expect(QuickCaptureOutcome.navigated.isDropped, isFalse);
    });
  });

  group('start sources', () {
    test('[QCP-02/AC3] allowedStartSources is pinned: no new value for the '
        'widget or control entry points', () {
      expect(StartSource.values.map((s) => s.name).toList(), [
        'inAppButton',
        'homeScreenWidget',
        'androidQuickSettingsTile',
        'iosControl',
      ]);
      expect(allowedStartSources, {
        StartSource.inAppButton,
        StartSource.homeScreenWidget,
        StartSource.androidQuickSettingsTile,
        StartSource.iosControl,
      });
      expect(
        QuickCaptureEntry.values.map((e) => e.name),
        isNot(anyOf(contains('inAppButton'), contains('homeScreenWidget'))),
        reason: 'entries are not start sources',
      );
    });
  });
}
