import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/features/export/data/routing_providers.dart';
import 'package:vaultvoice/features/pipeline/data/background_providers.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_isolate.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_providers.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_providers.dart';

/// Starts the UI-isolate processing monitor (throughput, notifications,
/// notification deep links) once the app is up, and forwards the app
/// lifecycle and OS memory warnings to the pipeline worker (FND-11: GPU only
/// in the foreground; LLM unload on memory pressure). Wraps the app in
/// `bootstrap`; widget tests of `App` run without it.
class ProcessingServicesHost extends ConsumerStatefulWidget {
  const ProcessingServicesHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ProcessingServicesHost> createState() =>
      _ProcessingServicesHostState();
}

class _ProcessingServicesHostState extends ConsumerState<ProcessingServicesHost>
    with WidgetsBindingObserver {
  AppLifecycleState? _lifecycle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // After the first frame so the router exists for launch deep links.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(processingMonitorProvider).start().ignore();
      // FND-08: OS keep-alive, power/thermal holds, deferred processing.
      final guard = ref.read(backgroundProcessingGuardProvider)
        ..setForeground(
          foreground:
              WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.resumed,
        );
      guard.start().ignore();
      // EXP-05: mirror the routing entitlement for the pipeline isolate.
      ref.read(routingPolicyMirrorProvider);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Sends [action] to the worker only if it is already running: lifecycle
  /// events never start the pipeline.
  void _toWorker(Future<void> Function(PipelineConditions worker) action) {
    if (!ref.exists(pipelineClientProvider)) return;
    final Object? client = ref.read(pipelineClientProvider).value;
    if (client is PipelineConditions) {
      unawaited(action(client).catchError((Object _) {}));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    final wasForeground = _lifecycle == AppLifecycleState.resumed;
    _lifecycle = state;
    // EXP-06: a folder that came back (SD card, iCloud, re-granted in the
    // system settings) unblocks its pending exports on resume.
    if (foreground && !wasForeground) {
      ref.read(exportOutboxProvider).recheck().ignore();
    }
    _toWorker((w) => w.setForeground(foreground: foreground));
    if (ref.exists(backgroundProcessingGuardProvider)) {
      ref
          .read(backgroundProcessingGuardProvider)
          .setForeground(foreground: foreground);
    }
  }

  @override
  void didHaveMemoryPressure() => _toWorker((w) => w.memoryPressure());

  @override
  Widget build(BuildContext context) => widget.child;
}
