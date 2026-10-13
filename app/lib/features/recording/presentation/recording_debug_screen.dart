import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/features/recording/data/recording_providers.dart';
import 'package:vaultvoice/features/recording/domain/audio_format.dart';
import 'package:vaultvoice/features/recording/domain/recording_controller.dart';
import 'package:vaultvoice/features/recording/domain/start_source.dart';

/// Dev-flavor screen for the AUD-01 device tests
/// (docs/test-plans/device/AUD-01.md) until AUD-08 builds the real
/// recording UI. Every button is a direct user tap into
/// [RecordingController] — the only microphone entry point (SEC-09).
class RecordingDebugScreen extends ConsumerStatefulWidget {
  const RecordingDebugScreen({super.key});

  @override
  ConsumerState<RecordingDebugScreen> createState() =>
      _RecordingDebugScreenState();
}

class _RecordingDebugScreenState extends ConsumerState<RecordingDebugScreen> {
  final _log = <String>[];
  StreamSubscription<RecordingState>? _states;
  StreamSubscription<CaptureNotice>? _notices;
  Timer? _ticker;
  List<AudioInputDevice> _devices = const [];
  AudioInputDevice? _device;

  RecordingController get _controller => ref.read(recordingControllerProvider);

  @override
  void initState() {
    super.initState();
    final c = _controller;
    _states = c.states.listen((s) => _add('state: $s'));
    _notices = c.notices.listen((n) => _add('notice: ${n.name}'));
    // Repaints the timer only; never touches the microphone.
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    unawaited(_states?.cancel());
    unawaited(_notices?.cancel());
    super.dispose();
  }

  void _add(String line) {
    if (!mounted) return;
    setState(() {
      _log.insert(0, '${DateTime.now().toIso8601String()}  $line');
      if (_log.length > 100) _log.removeLast();
    });
  }

  String _describe(Result<Object?> r) => r.when(
    ok: (v) => 'ok',
    err: (f) => switch (f) {
      RecordingBlockedFailure(reason: RecordingBlockReason.inCall) =>
        'refused: Recording is unavailable during calls',
      _ => 'failed: ${f.message}',
    },
  );

  Future<void> _start() async => _add(
    'start: ${_describe(await _controller.start(StartSource.inAppButton))}',
  );

  Future<void> _pause() async =>
      _add('pause: ${_describe(await _controller.pause())}');

  Future<void> _resume() async => _add(
    'resume: '
    '${_describe(await _controller.resume(ResumeSource.inAppButton))}',
  );

  Future<void> _stop() async {
    final r = await _controller.stop();
    _add(
      r.when(
        ok: (a) => 'stopped: ${a.duration.inMilliseconds} ms in ${a.path}',
        err: (f) => 'stop: failed: ${f.message}',
      ),
    );
  }

  Future<void> _loadDevices() async {
    final r = await ref.read(recordingInputDevicesProvider.future);
    if (!mounted) return;
    setState(() => _devices = r);
  }

  void _select(AudioInputDevice? d) {
    setState(() => _device = d);
    ref.read(recordingInputSelectorProvider)(d);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(recordingControllerProvider).state;
    final e = state.elapsed;
    final timer =
        '${e.inMinutes.toString().padLeft(2, '0')}:'
        '${(e.inSeconds % 60).toString().padLeft(2, '0')}';
    final cause = state.pauseCause;
    final why = cause == null ? '' : '  (${cause.name})';
    return Scaffold(
      appBar: AppBar(title: const Text('Recording debug')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              '${state.phase.name.toUpperCase()}  $timer$why',
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton(onPressed: _start, child: const Text('Start')),
              FilledButton(onPressed: _pause, child: const Text('Pause')),
              FilledButton(onPressed: _resume, child: const Text('Resume')),
              FilledButton(onPressed: _stop, child: const Text('Stop')),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              OutlinedButton(
                onPressed: _loadDevices,
                child: const Text('List inputs'),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: DropdownButton<AudioInputDevice?>(
                  isExpanded: true,
                  value: _device,
                  hint: const Text('Default input'),
                  items: [
                    const DropdownMenuItem(child: Text('Default input')),
                    for (final d in _devices)
                      DropdownMenuItem(
                        value: d,
                        child: Text('${d.label} (${d.kind.name})'),
                      ),
                  ],
                  onChanged: _select,
                ),
              ),
            ],
          ),
          const Divider(),
          for (final line in _log) Text(line, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
