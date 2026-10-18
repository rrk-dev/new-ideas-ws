import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/features/recording/data/method_channel_recording_indicator.dart';
import 'package:vaultvoice/features/recording/domain/recording_controller.dart';
import 'package:vaultvoice/features/recording/domain/recording_indicator.dart';

String _code(String rel) =>
    File(rel)
        .readAsStringSync()
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');

IndicatorContent _content(RecordingPhase phase, {PauseCause? cause}) =>
    indicatorContentFor(
      RecordingState(
        phase: phase,
        elapsed: const Duration(minutes: 3),
        pauseCause: cause,
      ),
      DateTime.utc(2026, 1, 1, 12),
      l10nFor(kFallbackLocale),
    )!;

void main() {
  const widget = 'ios/LumenWidgets/RecordingActivityWidget.swift';
  const attrs = 'ios/LiveActivityShared/RecordingActivityAttributes.swift';
  const controller = 'ios/Runner/RecordingLiveActivityController.swift';

  test('[AUD-13/AC2] the Activity has no buttons, intents or start path', () {
    final w = _code(widget);
    for (final banned in [
      'Button',
      'AppIntent',
      'LiveActivityIntent',
      'Toggle(',
      'AVAudio',
      'CallKit',
      'startRecording',
    ]) {
      expect(w, isNot(contains(banned)), reason: banned);
    }
    expect(w, contains('LumenWidgetContent.url'));
    // Dart side: the indicator binding cannot start a recording.
    final binding = _code(
      'lib/features/recording/presentation/recording_indicator_binding.dart',
    );
    expect(binding, isNot(contains('.start(')));
    expect(_code(controller), isNot(contains('AVAudio')));
  });

  test('[AUD-13/AC3] the Activity payload is state + timer start only', () {
    final rec = MethodChannelRecordingIndicator.encodeLiveActivity(
      _content(RecordingPhase.recording),
    );
    expect(rec.keys.toSet(), {'recording', 'timerStartMs'});
    expect(rec['recording'], isTrue);
    expect(
      rec['timerStartMs'],
      DateTime.utc(2026, 1, 1, 11, 57).millisecondsSinceEpoch,
    );
    for (final cause in [PauseCause.call, PauseCause.silence, null]) {
      final paused = MethodChannelRecordingIndicator.encodeLiveActivity(
        _content(RecordingPhase.paused, cause: cause),
      );
      expect(paused, {'recording': false, 'timerStartMs': null});
    }
    final all = MethodChannelRecordingIndicator.encode(
      _content(RecordingPhase.recording),
    );
    expect(all['liveActivity'], rec);
  });

  test('[AUD-13/AC3] native Activity types hold no text and no push token', () {
    final a = _code(attrs);
    expect(a, isNot(contains('String')));
    expect(a, contains('var recording: Bool'));
    expect(a, contains('var timerStart: Date?'));
    final c = _code(controller);
    expect(c, contains('pushType: nil'));
    expect(c, isNot(contains('pushTokenUpdates')));
    expect(c, isNot(contains('"title"')));
    expect(c, isNot(contains('"text"')));
    expect(c, contains('"timerStartMs"'));
    final w = _code(widget);
    expect(w, isNot(contains('URLSession')));
  });

  test('[AUD-13/AC4] Info.plist declares Live Activities, no new modes', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('NSSupportsLiveActivities'));
    final ext = File('ios/LumenWidgets/Info.plist').readAsStringSync();
    expect(ext, isNot(contains('UIBackgroundModes')));
    expect(ext, isNot(contains('NSMicrophoneUsageDescription')));
    final policy = File('../tools/ci/check_recording_policy.py')
        .readAsStringSync();
    expect(policy, contains('app/ios/LiveActivityShared'));
    expect(
      File('../tools/ci/check_egress.sh').readAsStringSync(),
      contains('app/ios/LiveActivityShared'),
    );
  });
}
