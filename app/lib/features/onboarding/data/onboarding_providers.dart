import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/features/onboarding/data/onboarding_readiness_providers.dart';
import 'package:vaultvoice/features/onboarding/domain/onboarding_keys.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

part 'onboarding_providers.g.dart';

/// The persisted `onboarding.completed` flag.
@Riverpod(keepAlive: true)
Stream<bool> onboardingCompleted(Ref ref) => ref
    .watch(settingsStoreProvider)
    .watch(OnboardingKeys.completed)
    .map((v) => v == true);

/// Whether the user explicitly chose to keep notes in the app.
@Riverpod(keepAlive: true)
Stream<bool> onboardingNotesInApp(Ref ref) => ref
    .watch(settingsStoreProvider)
    .watch(OnboardingKeys.notesInApp)
    .map((v) => v == true);

/// Whether first-run onboarding still has to run (drives the router
/// redirect to `/onboarding`). Unknown (loading) never redirects.
@Riverpod(keepAlive: true)
Stream<bool> onboardingRequired(Ref ref) async* {
  yield !await ref.watch(onboardingCompletedProvider.future);
}

/// Whether recording must be refused although onboarding was completed once:
/// the readiness check now fails (model deleted, microphone revoked…). Only
/// the Record route is gated on this; read-only routes (Library, Settings,
/// export, delete) stay reachable. Unknown, or a failing readiness probe,
/// never blocks.
@Riverpod(keepAlive: true)
Stream<bool> recordingBlocked(Ref ref) async* {
  final completed = await ref.watch(onboardingCompletedProvider.future);
  if (!completed) {
    yield false;
    return;
  }
  try {
    yield !(await ref.watch(onboardingReadinessProvider.future)).isReady;
  } on Object {
    yield false;
  }
}

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

  Future<bool> consentAcknowledged() async =>
      await _ref
              .read(settingsStoreProvider)
              .watch(OnboardingKeys.consentAcknowledgedAt)
              .first
          is int;

  Future<bool> isCompleted() async =>
      await _ref
          .read(settingsStoreProvider)
          .watch(OnboardingKeys.completed)
          .first ==
      true;

  /// Remembers "keep notes in the app" as an explicit choice.
  Future<Result<void>> chooseNotesInApp() =>
      _ref.read(settingsStoreProvider).set(OnboardingKeys.notesInApp, true);

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
