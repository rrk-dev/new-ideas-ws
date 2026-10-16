import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/routing/app_routes.dart';
import 'package:vaultvoice/features/onboarding/data/onboarding_providers.dart';

part 'app_router.g.dart';

/// Where the router sends [path] given whether first-run onboarding is
/// still [required] (null = not known yet: never redirect, so a slow settings
/// read cannot trap the user) and whether recording is [recordingBlocked]
/// after completion. Only the Record route is gated on the latter; read-only
/// routes stay reachable.
String? onboardingRedirect({
  required bool? required,
  required String path,
  bool? recordingBlocked,
}) {
  final onboarding = const OnboardingRoute().location;
  if (path == onboarding) return null;
  if (required == true) return onboarding;
  if (recordingBlocked == true && path == const RecordRoute().location) {
    return onboarding;
  }
  return null;
}

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final required = ValueNotifier<bool?>(null);
  final blocked = ValueNotifier<bool?>(null);
  ref
    ..listen(
      onboardingRequiredProvider,
      (_, next) => required.value = next.value,
      fireImmediately: true,
    )
    ..listen(
      recordingBlockedProvider,
      (_, next) => blocked.value = next.value,
      fireImmediately: true,
    )
    ..onDispose(required.dispose)
    ..onDispose(blocked.dispose);
  return GoRouter(
    routes: $appRoutes,
    initialLocation: const RecordRoute().location,
    refreshListenable: Listenable.merge([required, blocked]),
    redirect: (_, state) => onboardingRedirect(
      required: required.value,
      path: state.uri.path,
      recordingBlocked: blocked.value,
    ),
  );
}
