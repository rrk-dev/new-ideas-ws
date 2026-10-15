import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/app_info.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/features/app_lock/presentation/app_lock_providers.dart';
import 'package:vaultvoice/features/recording/data/recording_providers.dart';
import 'package:vaultvoice/features/recording/domain/recording_controller.dart';
import 'package:vaultvoice/features/recording/domain/start_source.dart';

/// Hides the whole app behind the lock screen while [AppLock] is locked
/// (SEC-03). The app below stays mounted (navigation, an ongoing recording)
/// but is not painted, not hit-testable and excluded from semantics.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () => ref.read(appLockProvider.notifier).backgrounded(),
      onPause: () => ref.read(appLockProvider.notifier).backgrounded(),
      onResume: () => ref.read(appLockProvider.notifier).resumed(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(appLockProvider);
    final hidden = lock.locked;
    return Stack(
      fit: StackFit.expand,
      children: [
        Visibility(
          visible: !hidden,
          maintainState: true,
          maintainAnimation: true,
          child: ExcludeSemantics(excluding: hidden, child: widget.child),
        ),
        if (hidden && lock.enabled) const LockScreen(),
        // Settings still loading: a neutral cover, no lock UI flash.
        if (hidden && !lock.enabled) const _Cover(),
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover();

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: Theme.of(context).colorScheme.surface);
}

/// The locked state: unlock, or start a recording without revealing any
/// content (SEC-03 scope; SEC-09 rules apply because the start goes through
/// the single `RecordingController.start(StartSource)` entry point).
class LockScreen extends ConsumerWidget {
  const LockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final lock = ref.watch(appLockProvider);
    return Scaffold(
      key: const ValueKey('app-lock-screen'),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48),
                const SizedBox(height: 16),
                Text(
                  l10n.appLockTitle(kAppName),
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  lock.unavailable ? l10n.appLockUnavailable : l10n.appLockBody,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const ValueKey('app-lock-unlock'),
                  onPressed: lock.authenticating
                      ? null
                      : () => ref
                            .read(appLockProvider.notifier)
                            .unlock(l10n.appLockReason),
                  icon: const Icon(Icons.fingerprint),
                  label: Text(l10n.appLockUnlock),
                ),
                const SizedBox(height: 32),
                const _LockedRecorder(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Start/stop a recording while locked. Shows only that a recording runs —
/// never titles, transcripts or other recordings.
class _LockedRecorder extends ConsumerWidget {
  const _LockedRecorder();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final controller = ref.watch(recordingControllerProvider);
    return StreamBuilder<RecordingState>(
      stream: controller.states,
      initialData: controller.state,
      builder: (context, snap) {
        final s = snap.data ?? controller.state;
        final active =
            s.phase == RecordingPhase.recording ||
            s.phase == RecordingPhase.paused;
        if (!active) {
          return OutlinedButton.icon(
            key: const ValueKey('app-lock-record'),
            // An explicit user tap (SEC-09): the in-app Record button.
            onPressed: () => controller.start(StartSource.inAppButton),
            icon: const Icon(Icons.mic),
            label: Text(l10n.appLockRecord),
          );
        }
        return Column(
          children: [
            Text(
              l10n.appLockRecording,
              key: const ValueKey('app-lock-recording'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('app-lock-stop'),
              onPressed: controller.stop,
              icon: const Icon(Icons.stop),
              label: Text(l10n.appLockStop),
            ),
          ],
        );
      },
    );
  }
}
