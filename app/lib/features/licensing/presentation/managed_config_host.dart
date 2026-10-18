import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/features/licensing/data/managed_config_applier.dart';

/// Starts applying the MDM managed configuration (licence, profile packs)
/// for the real app (LIC-04). Wraps the app in `bootstrap`.
class ManagedConfigHost extends ConsumerWidget {
  const ManagedConfigHost({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(managedConfigApplierProvider, (_, _) {});
    return child;
  }
}
