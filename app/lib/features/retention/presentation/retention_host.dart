import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/features/retention/data/retention_providers.dart';

/// Starts the SEC-04 retention scheduler (sweep at start + hourly) for the
/// real app. Wraps the app in `bootstrap`; widget tests of `App` run
/// without it.
class RetentionHost extends ConsumerWidget {
  const RetentionHost({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(retentionSchedulerProvider, (_, _) {});
    return child;
  }
}
