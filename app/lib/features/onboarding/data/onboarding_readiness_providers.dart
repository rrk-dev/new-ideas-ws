import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/db/enums.dart' show VaultPlatform;
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/models/data/model_state_providers.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';
import 'package:vaultvoice/features/onboarding/data/onboarding_providers.dart';
import 'package:vaultvoice/features/onboarding/domain/onboarding_readiness.dart';
import 'package:vaultvoice/features/recording/data/recording_providers.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

part 'onboarding_readiness_providers.g.dart';

/// Composes the existing providers into an [OnboardingReadiness]: installed
/// models, vault targets / "keep in app" choice, microphone permission
/// (queried without prompting — SEC-09) and free space vs the recommended
/// models still to download. Invalidate after a Fix action or when the app
/// returns from the OS Settings.
@Riverpod(keepAlive: true)
Future<OnboardingReadiness> onboardingReadiness(Ref ref) async {
  final installed = await ref.watch(installedModelsProvider.future);
  final targets = await ref.watch(vaultTargetsProvider.future);
  final notesInApp = await ref.watch(onboardingNotesInAppProvider.future);
  final sttInstalled = installed.any((m) => m.type == ModelType.stt);
  final llmInstalled = installed.any((m) => m.type == ModelType.llm);

  var requiredBytes = 0;
  if (!sttInstalled || !llmInstalled) {
    try {
      final bundle = await ref.watch(recommendedModelBundleProvider.future);
      for (final m in bundle?.models ?? const <CatalogModel>[]) {
        final covered = m.type == ModelType.stt ? sttInstalled : llmInstalled;
        if (!covered) requiredBytes += m.size;
      }
    } on Object {
      requiredBytes = 0;
    }
  }

  var microphone = false;
  try {
    microphone = await ref
        .watch(pcmMicSourceProvider)
        .hasPermission(request: false);
  } on Object {
    microphone = false;
  }

  int? freeBytes;
  if (requiredBytes > 0) {
    try {
      final paths = await ref.watch(storagePathsProvider.future);
      final free = await ref
          .watch(diskSpaceProbeProvider)
          .freeBytes(paths.root);
      freeBytes = switch (free) {
        Ok(:final value) => value,
        _ => null,
      };
    } on Object {
      freeBytes = null;
    }
  }

  return OnboardingReadiness(
    sttInstalled: sttInstalled,
    llmInstalled: llmInstalled,
    notesDestinationChosen:
        notesInApp || targets.any((t) => t.platform != VaultPlatform.appLocal),
    microphoneGranted: microphone,
    requiredBytes: requiredBytes,
    freeBytes: freeBytes,
  );
}
