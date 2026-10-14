import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/audio_recorder.dart';
import 'package:vaultvoice/core/platform/call_guard.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/features/recording/data/recording_providers.dart';
import 'package:vaultvoice/features/recording/domain/capture_backend.dart';
import 'package:vaultvoice/features/recording/domain/recording_controller.dart';
import 'package:vaultvoice/features/recording/domain/start_source.dart';

/// Dev-flavor screen for the SEC-09 CallGuard device test
/// (docs/test-plans/device/SEC-09.md): shows the live in-call state, the
/// latency from the platform event to Dart, and whether
/// `RecordingController.start` is refused. Never opens the microphone — it
/// drives the controller with [NoMicrophoneCaptureBackend].
class CallGuardDebugScreen extends ConsumerStatefulWidget {
  const CallGuardDebugScreen({super.key});

  @override
  ConsumerState<CallGuardDebugScreen> createState() =>
      _CallGuardDebugScreenState();
}

class _CallGuardDebugScreenState extends ConsumerState<CallGuardDebugScreen> {
  StreamSubscription<CallGuardEvent>? _sub;
  late final RecordingController _controller;
  final _log = <String>[];
  bool? _inCall;
  String _startResult = '—';

  @override
  void initState() {
    super.initState();
    final guard = ref.read(callGuardProvider);
    _controller = RecordingController(
      capture: NoMicrophoneCaptureBackend(),
      callGuard: guard,
      clock: ref.read(clockProvider),
      isAppInForeground: isAppInForeground,
    );
    _sub = guard.events.listen(_onEvent);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _onEvent(CallGuardEvent e) {
    final latencyMs = DateTime.now().toUtc().difference(e.at).inMilliseconds;
    setState(() {
      if (e.signal == CallGuardSignal.callActive) _inCall = true;
      if (e.signal == CallGuardSignal.callEnded) _inCall = false;
      _log.insert(
        0,
        '${e.at.toIso8601String()}  ${e.signal.name}  '
        '(+$latencyMs ms to Dart)',
      );
      if (_log.length > 50) _log.removeLast();
    });
  }

  Future<void> _refresh() async {
    final r = await ref.read(callGuardProvider).isInCall();
    if (!mounted) return;
    setState(() => _inCall = r.valueOrNull);
  }

  Future<void> _tryStart() async {
    final r = await _controller.start(StartSource.inAppButton);
    if (r.isOk) await _controller.stop();
    if (!mounted) return;
    setState(() {
      _startResult = r.when(
        ok: (_) => 'allowed (no microphone opened)',
        err: (f) => switch (f) {
          RecordingBlockedFailure(reason: RecordingBlockReason.inCall) =>
            'refused: Recording is unavailable during calls',
          _ => 'refused: ${f.message}',
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = switch (_inCall) {
      true => 'IN CALL',
      false => 'no call',
      null => 'unknown (guard unavailable)',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('CallGuard debug')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              'Call state: $state',
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            children: [
              FilledButton(
                onPressed: _refresh,
                child: const Text('Query isInCall'),
              ),
              FilledButton(
                onPressed: _tryStart,
                child: const Text('Try start'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Last start attempt: $_startResult'),
          const Divider(),
          for (final line in _log) Text(line, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// [CaptureBackend] that never touches the microphone (debug screen only).
class NoMicrophoneCaptureBackend implements CaptureBackend {
  @override
  Future<Result<void>> openMicrophone() async => const Ok<void>(null);

  @override
  Future<Result<void>> suspend({
    required GapKind gap,
    DateTime? discardFrom,
  }) async => const Ok<void>(null);

  @override
  Future<Result<void>> resumeCapture() async => const Ok<void>(null);

  @override
  Future<Result<RecordedAudio>> close({
    StopCause cause = StopCause.user,
  }) async => const Ok(RecordedAudio(path: '', duration: Duration.zero));

  @override
  Stream<CaptureNotice> get notices => const Stream.empty();
}
