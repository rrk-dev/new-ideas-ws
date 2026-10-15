import 'dart:async';
import 'dart:ui';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/platform/clock.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/features/recording/data/recording_providers.dart';
import 'package:vaultvoice/features/recording/domain/recording_controller.dart';
import 'package:vaultvoice/features/recording/domain/recording_indicator.dart';
import 'package:vaultvoice/features/recording/domain/start_source.dart';

part 'recording_indicator_binding.g.dart';

/// Keeps the OS recording indicator in step with [RecordingController] and
/// turns indicator button taps into controller calls (AUD-05 / AUD-04).
///
/// * The indicator appears with the first `recording` state — i.e. right
///   after a user tap opened the microphone, while the app is visible (the
///   Android 14+ microphone foreground service may only start then) — and
///   stays (updated) while paused, so a backgrounded recording can be
///   resumed from the notification. It is removed when the recording stops.
/// * Notification taps are user taps: Pause, Resume
///   (`ResumeSource.recordingNotification`, re-checked against CallGuard by
///   the controller) and Stop. Nothing here resumes on its own.
class RecordingIndicatorBinding {
  RecordingIndicatorBinding({
    required this._controller,
    required this._indicator,
    required this._clock,
    required this._l10n,
  }) {
    _states = _controller.states.listen(_onState);
  }

  final RecordingController _controller;
  final RecordingIndicator _indicator;
  final Clock _clock;
  final AppLocalizations Function() _l10n;
  late final StreamSubscription<RecordingState> _states;
  // Button taps are only listened to while the indicator is shown.
  StreamSubscription<IndicatorAction>? _actions;
  bool _shown = false;

  void _onState(RecordingState state) {
    final content = indicatorContentFor(state, _clock.now(), _l10n());
    if (content == null) {
      if (_shown) {
        _shown = false;
        unawaited(_actions?.cancel());
        _actions = null;
        unawaited(_indicator.hide());
      }
      return;
    }
    _shown = true;
    _actions ??= _indicator.actions.listen(_onAction);
    unawaited(_show(content));
  }

  // SEC-09: capture never continues without its visible indicator.
  Future<void> _show(IndicatorContent content) async {
    final shown = await _indicator.show(content);
    if (shown is Err && _controller.state.phase == RecordingPhase.recording) {
      await _controller.pause();
    }
  }

  Future<void> _onAction(IndicatorAction action) async {
    switch (action) {
      case IndicatorAction.pause:
        await _controller.pause();
      case IndicatorAction.resume:
        await _controller.resume(ResumeSource.recordingNotification);
      case IndicatorAction.stop:
        await _controller.stop();
    }
  }

  Future<void> dispose() async {
    await _states.cancel();
    await _actions?.cancel();
  }
}

/// Active for the whole app session; watched by the launch screen.
@Riverpod(keepAlive: true)
RecordingIndicatorBinding recordingIndicatorBinding(Ref ref) {
  final binding = RecordingIndicatorBinding(
    controller: ref.watch(recordingControllerProvider),
    indicator: ref.watch(recordingIndicatorProvider),
    clock: ref.watch(clockProvider),
    l10n: () => l10nFor(PlatformDispatcher.instance.locale),
  );
  ref.onDispose(binding.dispose);
  return binding;
}
