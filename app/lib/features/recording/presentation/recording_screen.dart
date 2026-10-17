import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/flavor_provider.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/platform/call_guard.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/features/onboarding/data/onboarding_providers.dart';
import 'package:vaultvoice/features/onboarding/presentation/permission_priming.dart';
import 'package:vaultvoice/features/onboarding/presentation/recording_consent_explainer.dart';
import 'package:vaultvoice/features/recording/data/recording_providers.dart';
import 'package:vaultvoice/features/recording/data/recording_screen_providers.dart';
import 'package:vaultvoice/features/recording/domain/recording_controller.dart';
import 'package:vaultvoice/features/recording/domain/recording_session.dart';
import 'package:vaultvoice/features/recording/domain/start_source.dart';
import 'package:vaultvoice/features/recording/presentation/audio_import_flow.dart';
import 'package:vaultvoice/features/recording/presentation/battery_guidance.dart';
import 'package:vaultvoice/features/recording/presentation/call_guard_debug_screen.dart';
import 'package:vaultvoice/features/recording/presentation/live_waveform.dart';
import 'package:vaultvoice/features/recording/presentation/recording_debug_screen.dart';
import 'package:vaultvoice/features/recording/presentation/recording_details_sheet.dart';
import 'package:vaultvoice/features/recording/presentation/recording_indicator_binding.dart';
import 'package:vaultvoice/features/recording/presentation/recovered_recordings_prompt.dart';

/// The Record tab (AUD-08): one big Record / Pause / Resume button, Stop,
/// "mark this moment", a timer and the live input meter; profile and
/// destination pickers (Auto by default); the SEC-07 consent confirmation
/// before the microphone opens; and the "unavailable during calls" state.
///
/// SEC-09: the microphone opens only inside the Record tap handler
/// (`RecordingController.start(StartSource.inAppButton)`); opening this
/// screen only reads settings, profiles and the call state (no pre-capture).
/// Recovered recordings (AUD-07) are offered on top of this screen.
class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

/// Why a start was refused (shown until the next attempt).
enum _Blocked { inCall, callStateUnknown, permission, storage, failed }

class _RecordScreenState extends ConsumerState<RecordScreen>
    with WidgetsBindingObserver {
  StreamSubscription<RecordingState>? _states;
  StreamSubscription<CallGuardEvent>? _callEvents;
  StreamSubscription<CaptureNotice>? _notices;
  RecordingState? _state;
  RecordingSetup _setup = const RecordingSetup();
  _Blocked? _blocked;
  bool _storageWarning = false;
  bool _starting = false;

  /// APP-01 microphone priming already shown (read once up front so the
  /// primed Record tap opens the microphone with no await first, AUD-08
  /// AC1); null = unknown → primed on the tap.
  bool? _micPrimed;

  /// First-run consent explainer acknowledged (SEC-07); null = unknown →
  /// asked on the tap. Read up front like [_micPrimed].
  bool? _consentAcked;

  /// Row id of the recording opened from this screen (for markers and the
  /// post-recording details).
  String? _recordingId;
  String? _detailsShownFor;

  RecordingController get _controller => ref.read(recordingControllerProvider);

  @override
  void initState() {
    super.initState();
    final c = _controller;
    _state = c.state;
    _states = c.states.listen(_onState);
    _notices = c.notices.listen((n) {
      if (n == CaptureNotice.lowStorageWarning && mounted) {
        setState(() => _storageWarning = true);
      }
    });
    WidgetsBinding.instance.addObserver(this);
    unawaited(_checkCallState());
    unawaited(_loadMicPrimed());
    unawaited(_loadConsentAcked());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_checkCallState());
  }

  Future<void> _loadMicPrimed() async {
    try {
      final primed = await ref.read(onboardingStoreProvider).micPrimed();
      if (mounted) _micPrimed = primed;
    } on Object {
      // Unknown: the first tap shows the priming dialog.
    }
  }

  Future<void> _loadConsentAcked() async {
    try {
      final acked = await ref
          .read(onboardingStoreProvider)
          .consentAcknowledged();
      if (mounted) _consentAcked = acked;
    } on Object {
      // Unknown: the first tap shows the explainer.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_callEvents?.cancel());
    unawaited(_states?.cancel());
    unawaited(_notices?.cancel());
    super.dispose();
  }

  /// "Recording unavailable during calls" before the user even taps — only
  /// asks the call guard; never touches the microphone.
  Future<void> _checkCallState({bool clearOnly = false}) async {
    final r = await ref.read(callGuardProvider).isInCall();
    if (!mounted) return;
    if (r case Ok(:final value)) {
      if (value) {
        if (clearOnly) return;
        setState(() => _blocked = _Blocked.inCall);
        // Hang-up must lift the block: listen only while it is shown.
        _callEvents ??= ref.read(callGuardProvider).events.listen((_) {
          unawaited(_checkCallState(clearOnly: true));
        });
      } else if (_blocked == _Blocked.inCall) {
        setState(() => _blocked = null);
        unawaited(_callEvents?.cancel());
        _callEvents = null;
      }
    }
  }

  void _onState(RecordingState s) {
    if (!mounted) return;
    setState(() => _state = s);
    final id = _recordingId;
    if (s.phase == RecordingPhase.stopped &&
        id != null &&
        _detailsShownFor != id) {
      _detailsShownFor = id;
      unawaited(_showDetails(id, s.stopCause));
    }
  }

  Future<void> _record() async {
    if (_starting) return;
    final profile = ref
        .read(profileChoicesProvider)
        .value
        ?.where((p) => p.id == _setup.profileId)
        .firstOrNull;
    if (_consentAcked != true) {
      final ack = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const FirstRunConsentDialog(),
      );
      if (ack != true || !mounted) return;
      await ref.read(onboardingStoreProvider).acknowledgeConsent();
      _consentAcked = true;
    }
    if (!mounted) return;
    // Auto (no profile) may resolve to a multi-person profile: ask too.
    final mode = profile == null
        ? ConsentMode.required
        : profile.consentRequired
        ? ConsentMode.required
        : profile.consentOptional
        ? ConsentMode.optional
        : ConsentMode.none;
    DateTime? consentAt;
    if (mode != ConsentMode.none) {
      final choice = await showDialog<ConsentChoice>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ConsentDialog(allowSkip: mode == ConsentMode.optional),
      );
      if (!mounted || choice == null || choice == ConsentChoice.cancel) return;
      if (choice == ConsentChoice.confirm) {
        consentAt = ref.read(clockProvider).now();
      }
    }
    // APP-01: explain the microphone once, on the first Record tap, before
    // the OS asks (integration wave 3).
    if (_micPrimed != true) {
      bool go;
      try {
        go = await primeMicrophonePermission(context, ref);
      } on Object {
        go = true; // settings unreadable: let the OS prompt decide
      }
      if (!go || !mounted) return;
      _micPrimed = true;
    }
    _starting = true;
    // The tap → mic path: nothing else is awaited before start (AC1 300 ms).
    final r = await _controller.start(StartSource.inAppButton);
    _starting = false;
    if (!mounted) return;
    switch (r) {
      case Ok():
        final id = ref.read(activeRecordingProvider)?.recordingId;
        setState(() {
          _blocked = null;
          _storageWarning = false;
          _recordingId = id;
        });
        if (id != null) {
          await ref
              .read(recordingSessionServiceProvider)
              .applySetup(id, _setup, consentConfirmedAt: consentAt);
        }
      case Err(:final failure):
        setState(() => _blocked = _blockedFor(failure));
    }
  }

  static _Blocked _blockedFor(Failure f) => switch (f) {
    RecordingBlockedFailure(reason: RecordingBlockReason.inCall) =>
      _Blocked.inCall,
    RecordingBlockedFailure(
      reason: RecordingBlockReason.callGuardUnavailable,
    ) =>
      _Blocked.callStateUnknown,
    PermissionFailure() => _Blocked.permission,
    StorageFailure() => _Blocked.storage,
    _ => _Blocked.failed,
  };

  Future<void> _pause() async => await _controller.pause();

  Future<void> _resume() async {
    final r = await _controller.resume(ResumeSource.inAppButton);
    if (!mounted) return;
    if (r case Err(:final failure)) {
      setState(() => _blocked = _blockedFor(failure));
    } else {
      setState(() => _blocked = null);
    }
  }

  Future<void> _stop() async => await _controller.stop();

  Future<void> _mark() async {
    final active = ref.read(activeRecordingProvider);
    final id = active?.recordingId ?? _recordingId;
    if (active == null || id == null) return;
    final r = await ref
        .read(recordingSessionServiceProvider)
        .addMarker(id, active.recorded);
    if (!mounted || r is Err) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.l10n.recordMarkerAdded)));
  }

  Future<void> _showDetails(String id, StopCause? cause) async {
    final service = ref.read(recordingSessionServiceProvider);
    var queued = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => RecordingDetailsSheet(
        recordingId: id,
        stopCause: cause,
        initialSetup: _setup,
        onQueued: () => queued = true,
      ),
    );
    // Auto-process only after the sheet saved the user's title, tags,
    // profile and destination.
    if (!queued) await service.finish(id);
    if (mounted) setState(() => _recordingId = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDev = ref.watch(flavorProvider).isDev;
    ref
      // Keeps the OS recording indicator (notification) in sync (AUD-05).
      ..watch(recordingIndicatorBindingProvider)
      // Auto-pause / auto-stop after silence (AUD-03): pause/stop only.
      ..watch(silenceWatcherProvider);
    final state = _state ?? _controller.state;
    final phase = state.phase;
    final active =
        phase == RecordingPhase.recording || phase == RecordingPhase.paused;
    // The launch screen: offers recordings recovered after a crash (AUD-07)
    // and OEM battery-saver guidance (AUD-05).
    return RecoveredRecordingsPrompt(
      // AUD-06: files shared into the app (share sheet / "Open in").
      child: SharedAudioImportListener(
        child: BatteryGuidance(
          child: Scaffold(
            appBar: AppBar(
              title: Text(l10n.tabRecord),
              actions: [
                // AUD-06: import an audio file recorded elsewhere.
                const ImportAudioButton(),
                if (isDev)
                  IconButton(
                    tooltip: l10n.recordingDebugTooltip,
                    icon: const Icon(Icons.graphic_eq),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const RecordingDebugScreen(),
                      ),
                    ),
                  ),
                if (isDev)
                  IconButton(
                    tooltip: l10n.callGuardDebugTooltip,
                    icon: const Icon(Icons.phone_disabled),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CallGuardDebugScreen(),
                      ),
                    ),
                  ),
              ],
            ),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  RecordingSetupPickers(
                    setup: _setup,
                    enabled: !active,
                    onChanged: (s) => setState(() => _setup = s),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _StatusText(state: state, blocked: _blocked),
                  if (_storageWarning) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _Banner(text: l10n.recordLowStorageWarning),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  _Timer(state: state),
                  const SizedBox(height: AppSpacing.md),
                  LiveWaveform(
                    key: const ValueKey('live-waveform'),
                    active: phase == RecordingPhase.recording,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  _Controls(
                    phase: phase,
                    inCall: _blocked == _Blocked.inCall && !active,
                    onRecord: _record,
                    onPause: _pause,
                    onResume: _resume,
                    onStop: _stop,
                    onMark: _mark,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, this.error = false, super.key});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: error ? scheme.errorContainer : scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: error
                ? scheme.onErrorContainer
                : scheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}

/// State line: what the recorder is doing, why it is paused, or why it
/// could not start.
class _StatusText extends StatelessWidget {
  const _StatusText({required this.state, required this.blocked});

  final RecordingState state;
  final _Blocked? blocked;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final b = blocked;
    if (b == _Blocked.permission && state.phase != RecordingPhase.recording) {
      // APP-01 recovery: what still works + a button to the OS settings.
      return PermissionDeniedNotice.microphone(
        key: const ValueKey('blocked-permission'),
      );
    }
    if (b != null && state.phase != RecordingPhase.recording) {
      return _Banner(
        key: ValueKey('blocked-${b.name}'),
        error: true,
        text: switch (b) {
          _Blocked.inCall => l10n.recordUnavailableDuringCalls,
          _Blocked.callStateUnknown => l10n.recordCallStateUnknown,
          _Blocked.permission => l10n.recordPermissionDenied,
          _Blocked.storage => l10n.recordLowStorage,
          _Blocked.failed => l10n.recordStartFailed,
        },
      );
    }
    final text = switch (state.phase) {
      RecordingPhase.idle || RecordingPhase.stopped => l10n.recordStateIdle,
      RecordingPhase.recording => l10n.recordStateRecording,
      RecordingPhase.paused => switch (state.pauseCause) {
        PauseCause.call => l10n.recordPausedCall,
        PauseCause.audioInterruption ||
        PauseCause.captureSilenced => l10n.recordPausedInterruption,
        PauseCause.captureError => l10n.recordPausedError,
        _ => l10n.recordStatePaused,
      },
    };
    return Semantics(
      liveRegion: true,
      child: Text(
        text,
        key: const ValueKey('record-status'),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

/// `mm:ss` (or `h:mm:ss`) recorded time; repaints itself 4×/s only while
/// recording (no screen-wide rebuilds).
class _Timer extends ConsumerStatefulWidget {
  const _Timer({required this.state});

  final RecordingState state;

  @override
  ConsumerState<_Timer> createState() => _TimerState();
}

class _TimerState extends ConsumerState<_Timer> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_Timer old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final running = widget.state.phase == RecordingPhase.recording;
    if (running && _tick == null) {
      _tick = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (mounted) setState(() {});
      });
    } else if (!running) {
      _tick?.cancel();
      _tick = null;
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phase = widget.state.phase;
    final e = phase == RecordingPhase.idle || phase == RecordingPhase.stopped
        ? Duration.zero
        : ref.read(recordingControllerProvider).elapsed;
    final text = formatElapsed(e);
    return Semantics(
      label: context.l10n.recordTimerLabel(text),
      excludeSemantics: true,
      child: Text(
        text,
        key: const ValueKey('record-timer'),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.displayMedium
            ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    );
  }
}

/// `05:07` / `1:02:03`.
String formatElapsed(Duration d) {
  String two(int v) => v.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = two(d.inMinutes % 60);
  final s = two(d.inSeconds % 60);
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.phase,
    required this.inCall,
    required this.onRecord,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.onMark,
  });

  final RecordingPhase phase;
  final bool inCall;
  final VoidCallback onRecord;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;
  final VoidCallback onMark;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final active =
        phase == RecordingPhase.recording || phase == RecordingPhase.paused;
    final (icon, label, semantics, onTap) = switch (phase) {
      RecordingPhase.recording => (
        Icons.pause,
        l10n.recordPause,
        l10n.recordButtonPauseLabel,
        onPause,
      ),
      RecordingPhase.paused => (
        Icons.mic,
        l10n.recordResume,
        l10n.recordButtonResumeLabel,
        onResume,
      ),
      _ => (Icons.mic, l10n.recordStart, l10n.recordButtonStartLabel, onRecord),
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _SideButton(
          key: const ValueKey('record-marker'),
          icon: Icons.bookmark_add_outlined,
          label: l10n.recordMarker,
          onPressed: phase == RecordingPhase.recording ? onMark : null,
        ),
        // The record button announces what a tap will do and the current
        // state (APP-06: state changes are read out via the live region).
        Semantics(
          button: true,
          label: semantics,
          value: switch (phase) {
            RecordingPhase.recording => l10n.recordStateRecording,
            RecordingPhase.paused => l10n.recordStatePaused,
            _ => l10n.recordStateIdle,
          },
          enabled: !(inCall && !active),
          focusable: true,
          onTap: inCall && !active ? null : onTap,
          excludeSemantics: true,
          child: SizedBox.square(
            dimension: AppSizes.recordButton,
            child: FilledButton(
              key: const ValueKey('record-main'),
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                padding: EdgeInsets.zero,
              ),
              onPressed: inCall && !active ? null : onTap,
              // Scales down at large text sizes instead of overflowing the
              // circle (the full label is in the semantics above).
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: FittedBox(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: AppSizes.iconLg),
                      Text(label, maxLines: 1),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        _SideButton(
          key: const ValueKey('record-stop'),
          icon: Icons.stop,
          label: l10n.recordStop,
          semanticsLabel: l10n.recordButtonStopLabel,
          onPressed: active ? onStop : null,
        ),
      ],
    );
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.semanticsLabel,
    super.key,
  });

  final IconData icon;
  final String label;
  final String? semanticsLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton.filledTonal(
        iconSize: AppSizes.iconMd,
        constraints: const BoxConstraints.tightFor(
          width: AppSizes.sideButton,
          height: AppSizes.sideButton,
        ),
        tooltip: semanticsLabel ?? label,
        icon: Icon(icon),
        onPressed: onPressed,
      ),
      const SizedBox(height: AppSpacing.xs),
      ExcludeSemantics(child: Text(label)),
    ],
  );
}

/// How the per-recording consent step applies to the chosen profile.
enum ConsentMode { required, optional, none }

/// What the user chose in [ConsentDialog].
enum ConsentChoice { confirm, skip, cancel }

/// Per-recording confirmation (SEC-07): "everyone present knows and agrees".
/// The confirm button is the default action; [allowSkip] (profiles with
/// `consent_confirmation: optional`) adds "record without confirming". The
/// confirmation time is stored as `recordings.consent_confirmed_at`.
class ConsentDialog extends StatelessWidget {
  const ConsentDialog({super.key, this.allowSkip = false});

  final bool allowSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.consentTitle),
      content: Text(allowSkip ? l10n.consentOptionalBody : l10n.consentBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(ConsentChoice.cancel),
          child: Text(l10n.commonCancel),
        ),
        if (allowSkip)
          TextButton(
            key: const ValueKey('consent-skip'),
            onPressed: () => Navigator.of(context).pop(ConsentChoice.skip),
            child: Text(l10n.consentSkip),
          ),
        FilledButton(
          key: const ValueKey('consent-confirm'),
          onPressed: () => Navigator.of(context).pop(ConsentChoice.confirm),
          child: Text(l10n.consentConfirm),
        ),
      ],
    );
  }
}

/// The first-run acknowledgement, shown before the first recording when it
/// was not given during onboarding (SEC-07).
class FirstRunConsentDialog extends StatelessWidget {
  const FirstRunConsentDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.consentFirstRunTitle),
      content: const SingleChildScrollView(child: RecordingConsentExplainer()),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('consent-first-run-ack'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.consentFirstRunConfirm),
        ),
      ],
    );
  }
}
