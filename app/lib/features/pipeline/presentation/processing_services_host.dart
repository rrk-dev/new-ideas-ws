import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // After the first frame so the router exists for launch deep links.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(processingMonitorProvider).start().ignore();
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
    final Object? client = ref.read(pipelineClientProvider).value;
    if (client is PipelineConditions) {
      unawaited(action(client).catchError((Object _) {}));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _toWorker(
    (w) => w.setForeground(foreground: state == AppLifecycleState.resumed),
  );

  @override
  void didHaveMemoryPressure() => _toWorker((w) => w.memoryPressure());

  @override
  Widget build(BuildContext context) => widget.child;
}
