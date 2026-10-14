import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/routing/app_routes.dart';
import 'package:vaultvoice/features/onboarding/data/onboarding_providers.dart';

part 'app_router.g.dart';

/// Where the router sends [path] given whether onboarding is still
/// [required] (null = not known yet: never redirect, so a slow settings
/// read cannot trap the user). Completed onboarding can be revisited.
String? onboardingRedirect({required bool? required, required String path}) {
  final onboarding = const OnboardingRoute().location;
  return required == true && path != onboarding ? onboarding : null;
}

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final required = ValueNotifier<bool?>(null);
  ref
    ..listen(
      onboardingRequiredProvider,
      (_, next) => required.value = next.value,
      fireImmediately: true,
    )
    ..onDispose(required.dispose);
  return GoRouter(
    routes: $appRoutes,
    initialLocation: const RecordRoute().location,
    refreshListenable: required,
    redirect: (_, state) =>
        onboardingRedirect(required: required.value, path: state.uri.path),
  );
}
