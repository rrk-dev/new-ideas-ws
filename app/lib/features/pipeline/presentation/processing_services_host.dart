import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/features/models/data/model_install_waker.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_providers.dart';

/// Starts the UI-isolate processing monitor (throughput, notifications,
/// notification deep links) and the model-install waker once the app is
/// up. Wraps the app in `bootstrap`; widget tests of `App` run without it.
class ProcessingServicesHost extends ConsumerStatefulWidget {
  const ProcessingServicesHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ProcessingServicesHost> createState() =>
      _ProcessingServicesHostState();
}

class _ProcessingServicesHostState
    extends ConsumerState<ProcessingServicesHost> {
  @override
  void initState() {
    super.initState();
    // After the first frame so the router exists for launch deep links.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(processingMonitorProvider).start().ignore();
      // APP-01: jobs waiting for a model resume once it is installed.
      ref.read(modelInstallWakerProvider).start();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
