import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/features/licensing/data/licensing_providers.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/licensing/domain/paywall.dart';

/// Paywall entry point for actions behind a [Feature].
///
/// Returns `true` when the feature is available. Otherwise, in a commercial
/// build, opens the paywall from [from] and returns whether the feature is
/// available afterwards; a personal build never shows a paywall.
Future<bool> ensureFeature(
  WidgetRef ref,
  Feature feature, {
  required PaywallEntryPoint from,
}) async {
  if (ref.read(featureProvider(feature))) return true;
  final access = ref.read(featureAccessStateProvider);
  if (!access.paywallEnabled) return false;
  await ref
      .read(paywallPresenterProvider)
      .show(PaywallRequest(feature: feature, entryPoint: from));
  return ref.read(featureAccessStateProvider).has(feature);
}

/// Builds [enabled] when [feature] is available, else [locked] (e.g. a
/// read-only view or an upgrade hint).
class FeatureGate extends ConsumerWidget {
  const FeatureGate({
    required this.feature,
    required this.enabled,
    required this.locked,
    super.key,
  });

  final Feature feature;
  final WidgetBuilder enabled;
  final WidgetBuilder locked;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(featureProvider(feature)) ? enabled(context) : locked(context);
}
