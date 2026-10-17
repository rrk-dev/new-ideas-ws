import 'package:vaultvoice/features/onboarding/domain/onboarding_keys.dart';

/// What must be in place before Lumen can record and process a note.
enum ReadinessItem {
  sttModel(OnboardingStep.models),
  llmModel(OnboardingStep.models),
  diskSpace(OnboardingStep.models),
  microphone(OnboardingStep.permissions),
  notesFolder(OnboardingStep.folder);

  ReadinessItem(this.step);

  /// The onboarding step that can fix this item.
  final OnboardingStep step;
}

/// Snapshot of everything onboarding has to guarantee (APP-01): speech and
/// language models installed, a notes destination chosen, the microphone
/// granted and enough free space for the models still to download.
/// Pure value object; `onboardingReadinessProvider` fills it from the app's
/// existing providers.
class OnboardingReadiness {
  const OnboardingReadiness({
    required this.sttInstalled,
    required this.llmInstalled,
    required this.notesDestinationChosen,
    required this.microphoneGranted,
    this.requiredBytes = 0,
    this.freeBytes,
  });

  /// Everything satisfied (tests, previews).
  static const allReady = OnboardingReadiness(
    sttInstalled: true,
    llmInstalled: true,
    notesDestinationChosen: true,
    microphoneGranted: true,
  );

  final bool sttInstalled;
  final bool llmInstalled;

  /// A notes folder was picked, or "keep notes in the app" was chosen.
  final bool notesDestinationChosen;
  final bool microphoneGranted;

  /// Bytes of the recommended models still to download.
  final int requiredBytes;

  /// Free bytes on the models volume; null = unknown, which never blocks
  /// (the downloader re-checks before it starts).
  final int? freeBytes;

  bool get hasEnoughSpace => freeBytes == null || freeBytes! >= requiredBytes;

  /// Missing items in onboarding order.
  List<ReadinessItem> get missing => [
    if (!microphoneGranted) ReadinessItem.microphone,
    if (!sttInstalled) ReadinessItem.sttModel,
    if (!llmInstalled) ReadinessItem.llmModel,
    if (!hasEnoughSpace) ReadinessItem.diskSpace,
    if (!notesDestinationChosen) ReadinessItem.notesFolder,
  ];

  bool get isReady => missing.isEmpty;

  /// Missing items that [step] can fix.
  List<ReadinessItem> missingFor(OnboardingStep step) => [
    for (final i in missing)
      if (i.step == step) i,
  ];

  /// Earliest onboarding step with something missing (null = ready).
  OnboardingStep? get firstMissingStep {
    OnboardingStep? first;
    for (final i in missing) {
      if (first == null || i.step.index < first.index) first = i.step;
    }
    return first;
  }
}
