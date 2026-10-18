import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/diagnostics/diagnostics_providers.dart';
import 'package:vaultvoice/core/routing/app_routes.dart';
import 'package:vaultvoice/features/recording/data/pigeon_quick_capture.dart';
import 'package:vaultvoice/features/recording/domain/quick_capture_handoff.dart';

/// Native quick-capture store; tests override it with a fake.
final quickCaptureSourceProvider = Provider<QuickCaptureSource>(
  (ref) => PigeonQuickCapture(),
);

/// Consumes a pending widget/control hand-off at startup and whenever the app
/// returns to the foreground, and opens the Record screen. It never starts a
/// recording (QCP-02): the user taps Record in the app.
class QuickCaptureHost extends ConsumerStatefulWidget {
  const QuickCaptureHost({
    required this.navigator,
    required this.child,
    super.key,
  });

  /// Router navigator context source (the root navigator's key).
  final GlobalKey<NavigatorState> navigator;
  final Widget child;

  @override
  ConsumerState<QuickCaptureHost> createState() => _QuickCaptureHostState();
}

class _QuickCaptureHostState extends ConsumerState<QuickCaptureHost>
    with WidgetsBindingObserver {
  late final QuickCaptureHandoff _handoff;

  @override
  void initState() {
    super.initState();
    _handoff = QuickCaptureHandoff(
      source: ref.read(quickCaptureSourceProvider),
      logger: ref.read(loggerProvider),
      navigateToRecord: (_) {
        final context = widget.navigator.currentContext;
        if (context != null && context.mounted) {
          const RecordRoute().go(context);
        }
      },
    );
    WidgetsBinding.instance
      ..addObserver(this)
      ..addPostFrameCallback((_) => unawaited(_handoff.consume()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_handoff.consume());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
