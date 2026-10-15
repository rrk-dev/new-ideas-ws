import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/features/onboarding/domain/onboarding_keys.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

part 'onboarding_providers.g.dart';

/// Whether the first-launch flow still has to run. Drives the router
/// redirect to `/onboarding`; unknown (loading/error) never redirects.
@Riverpod(keepAlive: true)
Stream<bool> onboardingRequired(Ref ref) => ref
    .watch(settingsStoreProvider)
    .watch(OnboardingKeys.completed)
    .map((v) => v != true);

/// Whether the first-run recording-consent explainer was acknowledged.
@riverpod
Stream<bool> consentAcknowledged(Ref ref) => ref
    .watch(settingsStoreProvider)
    .watch(OnboardingKeys.consentAcknowledgedAt)
    .map((v) => v is int);

/// Persists onboarding milestones.
@Riverpod(keepAlive: true)
OnboardingStore onboardingStore(Ref ref) => OnboardingStore(ref);

class OnboardingStore {
  OnboardingStore(this._ref);

  final Ref _ref;

  Future<Result<void>> acknowledgeConsent() => _ref
      .read(settingsStoreProvider)
      .set(
        OnboardingKeys.consentAcknowledgedAt,
        _ref.read(clockProvider).now().toUtc().millisecondsSinceEpoch,
      );

  Future<Result<void>> complete() =>
      _ref.read(settingsStoreProvider).set(OnboardingKeys.completed, true);

  Future<bool> micPrimed() async =>
      await _ref
          .read(settingsStoreProvider)
          .watch(OnboardingKeys.micPrimed)
          .first ==
      true;

  Future<Result<void>> markMicPrimed() =>
      _ref.read(settingsStoreProvider).set(OnboardingKeys.micPrimed, true);
}
