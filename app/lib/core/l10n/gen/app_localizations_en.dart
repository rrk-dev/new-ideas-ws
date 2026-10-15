// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonTryAgain => 'Try again';

  @override
  String get commonOk => 'OK';

  @override
  String get commonSave => 'Save';

  @override
  String get commonReset => 'Reset';

  @override
  String get commonLoading => 'Loading';

  @override
  String get commonNotAvailableYet => 'Not available in this build yet.';

  @override
  String get tabRecord => 'Record';

  @override
  String get tabLibrary => 'Library';

  @override
  String get tabProfiles => 'Profiles';

  @override
  String get tabSettings => 'Settings';

  @override
  String placeholderScreenLabel(String title) {
    return '$title screen placeholder';
  }

  @override
  String get callGuardDebugTooltip => 'CallGuard debug';

  @override
  String get crashShareUnavailable => 'Sharing is not available.';

  @override
  String get crashShareFailed => 'Could not share the crash report.';

  @override
  String crashPromptTitleNative(String appName) {
    return '$appName closed unexpectedly';
  }

  @override
  String crashPromptTitleDart(String appName) {
    return '$appName hit an unexpected error';
  }

  @override
  String get crashPromptBody =>
      'A crash report was saved on this device. It contains only technical details (error type, code addresses, app and OS version) — no recordings, transcripts or notes. You can review it and send it to the developers, for example by email. Nothing is sent automatically.';

  @override
  String get crashPromptNotNow => 'Not now';

  @override
  String get crashPromptReview => 'Review report';

  @override
  String get crashPreviewTitle => 'Crash report';

  @override
  String crashPreviewInfo(String name, String size) {
    return '$name · $size. This is the complete file. Nothing leaves this device unless you choose a destination in the share sheet.';
  }

  @override
  String get crashPreviewDiscard => 'Discard';

  @override
  String get crashPreviewShare => 'Share';

  @override
  String get crashSettingsTitle => 'Crash reports';

  @override
  String get crashSettingsNone =>
      'None saved. Reports stay on this device until you share them.';

  @override
  String crashSettingsCount(int count) {
    return '$count saved on this device. Tap to review and share.';
  }

  @override
  String get crashDevForceNative => 'Force native crash (dev)';

  @override
  String get crashDevForceNativeSubtitle =>
      'Kills the app via SIGSEGV in libvv_native.';

  @override
  String get crashDevConfirmTitle => 'Crash the app now?';

  @override
  String get crashDevConfirm => 'Crash';

  @override
  String get crashDevThrowDart => 'Throw uncaught Dart error (dev)';

  @override
  String batteryGuidanceIntro(String steps) {
    return 'Long recordings can be stopped by this phone’s battery saver when the screen is off. $steps';
  }

  @override
  String get batteryGuidanceSamsung =>
      'Settings → Battery → Background usage limits → Never sleeping apps → add VaultVoice.';

  @override
  String get batteryGuidanceXiaomi =>
      'Settings → Apps → VaultVoice → Battery saver → No restrictions, and turn on Autostart.';

  @override
  String get batteryGuidanceOnePlus =>
      'Settings → Battery → VaultVoice → Allow background activity.';

  @override
  String get batteryGuidanceGeneric =>
      'In battery settings, allow VaultVoice to run in the background.';

  @override
  String get batteryGuidanceOpenSettings => 'Open battery settings';

  @override
  String get recoveredTitle => 'Recording recovered';

  @override
  String recoveredPrompt(String when) {
    return 'Recovered recording from $when — process now?';
  }

  @override
  String recoveredDetails(int minutes, String seconds) {
    return 'Length: ${minutes}m ${seconds}s. The app was closed while recording; the audio captured up to then was kept.';
  }

  @override
  String get recoveredLater => 'Later';

  @override
  String get recoveredProcessNow => 'Process now';

  @override
  String get modelImportTitle => 'Import model from file';

  @override
  String get modelImportSubtitle =>
      'Select the model file with its signed manifest (.json and .sig). Works without a network connection.';

  @override
  String get modelImportInstalled => 'Model installed';

  @override
  String get modelImportUnsignedTitle => 'Unsigned custom model';

  @override
  String get modelImportUnsignedBody =>
      'This file is not a VaultVoice-signed model. Only import GGUF files from a source you trust: a malformed or malicious model file can crash the app. Its license is your responsibility.';

  @override
  String get modelImportAnyway => 'Import anyway';

  @override
  String get modelImportErrorUnknownModel =>
      'Not a signed VaultVoice model. Select the model file together with its .json and .sig files.';

  @override
  String get modelImportErrorMissingFiles =>
      'Select exactly one model file plus its .json and .sig files.';

  @override
  String get modelImportErrorEntitlement =>
      'Custom models require VaultVoice Pro.';

  @override
  String get modelImportErrorInvalidGguf =>
      'This file is not a valid GGUF model.';

  @override
  String get modelImportErrorNotSingleModel =>
      'The manifest is not a single-model manifest.';

  @override
  String get modelImportErrorSignature =>
      'The manifest signature is not valid.';

  @override
  String get modelImportErrorIntegrity =>
      'The model file does not match its manifest (size or checksum).';

  @override
  String get modelImportErrorNoSpace => 'Not enough free space.';

  @override
  String get modelImportErrorGeneric => 'Import failed.';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonNotNow => 'Not now';

  @override
  String bytesKilobytes(String value) {
    return '$value KB';
  }

  @override
  String bytesMegabytes(String value) {
    return '$value MB';
  }

  @override
  String bytesGigabytes(String value) {
    return '$value GB';
  }

  @override
  String get deviceTierLow => 'Standard';

  @override
  String get deviceTierMid => 'Capable';

  @override
  String get deviceTierHigh => 'High-end';

  @override
  String get modelTypeStt => 'Speech to text';

  @override
  String get modelTypeLlm => 'Note writer (AI)';

  @override
  String get modelTypeVad => 'Speech detection';

  @override
  String get modelTypeSpeakers => 'Speaker separation';

  @override
  String get modelTypeAccelerator => 'Speech accelerator';

  @override
  String modelSummary(String type, String size) {
    return '$type · $size';
  }

  @override
  String get modelStatusInstalled => 'Installed';

  @override
  String get modelStatusNotDownloaded => 'Not downloaded';

  @override
  String get downloadPhaseChecking => 'Preparing download…';

  @override
  String downloadPhaseDownloading(int percent) {
    return 'Downloading · $percent%';
  }

  @override
  String get downloadPhaseRetrying => 'Connection lost, retrying…';

  @override
  String get downloadPhasePaused => 'Paused';

  @override
  String get downloadPhaseVerifying => 'Checking the file…';

  @override
  String get downloadPhaseInstalling => 'Installing…';

  @override
  String get downloadPhaseFailed => 'Download failed';

  @override
  String get downloadUnavailable =>
      'Model downloads are not available right now.';

  @override
  String get downloadOffline =>
      'You’re offline. Connect to the internet to download models.';

  @override
  String downloadNoSpace(String needed, String free) {
    return 'Not enough free space: $needed needed, $free available.';
  }

  @override
  String get downloadCellularTitle => 'Use mobile data?';

  @override
  String downloadCellularBody(String size) {
    return 'You’re not on Wi-Fi. Downloading $size over mobile data may cost money.';
  }

  @override
  String get downloadCellularAlways => 'Always allow mobile data for models';

  @override
  String get downloadWaitForWifi => 'Wait for Wi-Fi';

  @override
  String get downloadNow => 'Download now';

  @override
  String get downloadWaitingForWifi =>
      'Not downloading. Start it again from Settings › Models when you’re on Wi-Fi.';

  @override
  String get downloadLowPowerTitle => 'Low Power Mode is on';

  @override
  String get downloadLowPowerBody =>
      'Downloading large models uses battery. Download anyway?';

  @override
  String get downloadLater => 'Later';

  @override
  String get downloadAnyway => 'Download anyway';

  @override
  String downloadFailed(String name) {
    return 'Downloading $name failed. Try again from Settings › Models.';
  }

  @override
  String onboardingStepOf(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get onboardingBack => 'Back';

  @override
  String get onboardingGetStarted => 'Get started';

  @override
  String get onboardingPrivacyTitle => 'Your recordings stay on your device';

  @override
  String get onboardingPrivacyOnDevice =>
      'Recording, transcription and note writing all happen on this phone. No account, no cloud, no analytics.';

  @override
  String get onboardingPrivacyNetwork =>
      'The only thing VaultVoice downloads is its AI models. Nothing you record is ever uploaded.';

  @override
  String get onboardingPrivacyVault =>
      'Your notes are saved as Markdown files in a folder you choose, such as your Obsidian or Logseq vault.';

  @override
  String get consentExplainerTitle => 'Record responsibly';

  @override
  String get consentExplainerAsk =>
      'Only record people who know they are being recorded and agree to it.';

  @override
  String get consentExplainerLaws =>
      'Recording laws differ between countries and states. In many places everyone in the conversation must agree.';

  @override
  String get consentExplainerConfirm =>
      'For conversations with several people, VaultVoice asks you to confirm that everyone agreed before it starts.';

  @override
  String get consentNeverCalls =>
      'VaultVoice never records phone or VoIP calls. When a call starts, recording stops and does not resume on its own.';

  @override
  String get consentExplainerAcknowledge =>
      'I will only record people with their consent';

  @override
  String get onboardingPermissionsTitle => 'What VaultVoice will ask for';

  @override
  String get onboardingPermissionMic =>
      'Microphone: your phone asks the first time you tap Record — never before, and never in the background.';

  @override
  String get onboardingPermissionNotifications =>
      'Notifications: get a message when a note is ready or processing needs your attention. Optional.';

  @override
  String get onboardingAllowNotifications => 'Allow notifications';

  @override
  String get notificationsAllowed => 'Notifications are on.';

  @override
  String get notificationsDeniedBody =>
      'Notifications are off. Processing still works — check the Library for finished notes. You can turn notifications on in the system settings.';

  @override
  String get onboardingPermissionFolder =>
      'Folder: you choose where notes are saved in the next steps. VaultVoice can only see that folder.';

  @override
  String get permissionOpenSettings => 'Open settings';

  @override
  String get permissionOpenSettingsFailed =>
      'Could not open the system settings. Open them from your home screen.';

  @override
  String get micPrimerTitle => 'Allow microphone access';

  @override
  String get micPrimerBody =>
      'VaultVoice needs the microphone to record what you choose to record. The audio stays on this device. Your phone will ask for permission next.';

  @override
  String get micDeniedBody =>
      'Microphone access is off, so VaultVoice can’t record. You can still import audio and browse your notes. Allow the microphone in the system settings to record.';

  @override
  String get onboardingModelsTitle => 'AI models for this device';

  @override
  String get onboardingModelsChecking => 'Checking this device';

  @override
  String onboardingModelsDevice(String tier, String ram) {
    return 'Device class: $tier ($ram memory). Recommended:';
  }

  @override
  String get onboardingModelsDeviceUnknown =>
      'Couldn’t check this device, so the smallest models are recommended:';

  @override
  String onboardingModelsTotal(String size) {
    return 'Total download: $size. Wi-Fi recommended.';
  }

  @override
  String onboardingModelsDownload(String size) {
    return 'Download $size';
  }

  @override
  String get onboardingModelsExplore =>
      'You can continue and record while the models download. Recordings are processed as soon as the models are ready.';

  @override
  String get onboardingModelsReady => 'All recommended models are installed.';

  @override
  String get onboardingModelsOffline =>
      'Downloads are turned off on this device (offline mode or your organization). Import the model files instead:';

  @override
  String get onboardingModelsUnavailable =>
      'No model recommendation is available right now. You can download models later in Settings › Models.';

  @override
  String get onboardingFolderTitle => 'Where should notes go?';

  @override
  String get onboardingFolderBody =>
      'Pick your Obsidian or Logseq vault, or any folder. VaultVoice only gets access to the folder you pick.';

  @override
  String get onboardingFolderChoose => 'Choose folder';

  @override
  String get onboardingFolderChooseAnother => 'Choose another folder';

  @override
  String onboardingFolderChosen(String name) {
    return 'Notes will be saved in $name.';
  }

  @override
  String get onboardingFolderFailed =>
      'That folder couldn’t be used. Try another one, or keep notes in the app for now.';

  @override
  String get onboardingFolderLater =>
      'You can add or change folders anytime in Settings › Vault folders.';

  @override
  String get onboardingFolderKeepInApp => 'Keep notes in the app for now';

  @override
  String get onboardingReadyTitle => 'You’re all set';

  @override
  String get onboardingReadyBody =>
      'Tap Record to make your first note. If the models are still downloading, your recording waits and is processed automatically when they’re ready.';

  @override
  String get onboardingFirstRecording => 'Make my first recording';

  @override
  String get onboardingExplore => 'Explore first';

  @override
  String get modelsCheckUpdates => 'Check for model updates';

  @override
  String get modelsCatalogChecked => 'Model list checked.';

  @override
  String get modelsCatalogFailed =>
      'Couldn’t check for model updates. Try again later.';

  @override
  String get modelsLoadFailed => 'Couldn’t load the model list.';

  @override
  String get modelsEmpty =>
      'No models are available. Check for updates or import model files.';

  @override
  String get modelsStorageTitle => 'Storage used';

  @override
  String get modelsStorageModels => 'Models';

  @override
  String get modelsStorageAudio => 'Recordings (audio)';

  @override
  String get modelsStorageTranscripts => 'Transcripts';

  @override
  String modelsUpdatesAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Updates are available for $count models.',
      one: 'An update is available for 1 model.',
    );
    return '$_temp0';
  }

  @override
  String get modelsOfflineNotice =>
      'Downloads are turned off on this device (offline mode or your organization). Import model files below.';

  @override
  String get modelsImportSection => 'Import from files';

  @override
  String get modelsAdvancedCustom => 'Advanced: custom models';

  @override
  String get modelsAdvancedCustomSubtitle =>
      'Allow importing unsigned GGUF files. Only use files you trust.';

  @override
  String get modelBadgePro => 'Pro';

  @override
  String get modelBadgeEnterprise => 'Enterprise';

  @override
  String get modelBadgeActive => 'In use';

  @override
  String get modelBadgeRecommended => 'Recommended';

  @override
  String get modelBadgeUpdate => 'Update available';

  @override
  String modelSizeVersion(String size, String version) {
    return '$size · version $version';
  }

  @override
  String modelIncompatible(String ram) {
    return 'Needs $ram of memory — may not run on this device.';
  }

  @override
  String get modelNotOnPlan =>
      'Not available on your current plan. It stays installed but can’t be used.';

  @override
  String get modelRequiresPro => 'Requires Pro';

  @override
  String get modelActionDownload => 'Download';

  @override
  String get modelActionResume => 'Resume';

  @override
  String get modelActionUpdate => 'Update';

  @override
  String get modelActionPause => 'Pause';

  @override
  String get modelActionCancel => 'Cancel download';

  @override
  String get modelActionUse => 'Use this model';

  @override
  String get modelActionDelete => 'Delete';

  @override
  String modelActivated(String name) {
    return '$name will be used for new processing.';
  }

  @override
  String modelDeleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String modelDeleteBody(String size) {
    return 'This frees $size. You can download it again later.';
  }

  @override
  String modelDeleteReplaceBody(String name) {
    return '$name is used to process recordings. Choose the model to use instead:';
  }

  @override
  String get modelDeleteAndSwitch => 'Switch and delete';

  @override
  String get modelDeleteBlockedTitle => 'Can’t delete this model';

  @override
  String modelDeleteBlockedBody(String type) {
    return 'It’s the only installed model for $type, and VaultVoice needs one to process recordings. Download another one first, then delete this one.';
  }

  @override
  String modelDeleted(String name) {
    return '$name deleted.';
  }

  @override
  String get modelDeleteFailed => 'Couldn’t delete the model.';

  @override
  String get librarySearchHint => 'Search recordings, transcripts and notes';

  @override
  String get librarySearchClear => 'Clear search';

  @override
  String get librarySort => 'Sort';

  @override
  String get librarySortNewest => 'Newest first';

  @override
  String get librarySortOldest => 'Oldest first';

  @override
  String get librarySortLongest => 'Longest first';

  @override
  String get librarySortTitle => 'Title A–Z';

  @override
  String get libraryLoadFailed => 'Couldn’t load your recordings.';

  @override
  String get libraryEmpty =>
      'No recordings yet. Tap Record to make your first note.';

  @override
  String get libraryNoMatches => 'No recordings match your search or filters.';

  @override
  String get libraryFilterStatus => 'Status';

  @override
  String get libraryFilterProfile => 'Profile';

  @override
  String get libraryFilterTag => 'Tag';

  @override
  String get libraryFilterDate => 'Date';

  @override
  String get libraryFilterClear => 'Clear filters';

  @override
  String get libraryFilterAll => 'All';

  @override
  String libraryExportedTo(String status, String folders) {
    return '$status · $folders';
  }

  @override
  String get libraryStatusRecording => 'Recording';

  @override
  String get libraryStatusRecorded => 'Not processed';

  @override
  String get libraryStatusProcessing => 'Processing';

  @override
  String get libraryStatusWaiting => 'Waiting';

  @override
  String get libraryStatusProcessed => 'Processed, not exported';

  @override
  String get libraryStatusExported => 'Exported';

  @override
  String get libraryStatusFailed => 'Failed';

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String durationMinutesSeconds(int minutes, int seconds) {
    return '$minutes min $seconds s';
  }

  @override
  String durationSeconds(int seconds) {
    return '$seconds s';
  }

  @override
  String get recordingLoadFailed => 'Couldn’t load this recording.';

  @override
  String get recordingNotFound => 'This recording no longer exists.';

  @override
  String get recordingImported => 'Imported';

  @override
  String get recordingActions => 'Recording actions';

  @override
  String get recordingReExtract => 'Extract again';

  @override
  String get recordingChangeProfile => 'Change profile';

  @override
  String get recordingReExport => 'Export again';

  @override
  String get recordingDelete => 'Delete recording';

  @override
  String get recordingBusy =>
      'Processing is running. Try again when it has finished.';

  @override
  String recordingProfileCurrent(String name) {
    return '$name (current)';
  }

  @override
  String get recordingTranscript => 'Transcript';

  @override
  String get recordingNoTranscript => 'No transcript yet.';

  @override
  String recordingShowTranscript(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Show the full transcript ($count lines)',
      one: 'Show the full transcript (1 line)',
    );
    return '$_temp0';
  }

  @override
  String transcriptSpeakerLine(String speaker, String text) {
    return '$speaker: $text';
  }

  @override
  String get recordingExtracted => 'Extracted';

  @override
  String get recordingNoExtraction => 'Nothing extracted yet.';

  @override
  String get recordingExtractionInvalid =>
      'The AI output didn’t fully match the profile. Showing what was extracted.';

  @override
  String get recordingExports => 'Exports';

  @override
  String get recordingNoExports => 'Not exported yet.';

  @override
  String get exportStatusWritten => 'Written';

  @override
  String get exportStatusFailed => 'Failed';

  @override
  String get exportStatusPending => 'Waiting to be written';

  @override
  String get recordingDeleteTitle => 'Delete this recording?';

  @override
  String get recordingDeleteBody =>
      'The audio, transcript and extracted data are removed from this device. This can’t be undone.';

  @override
  String recordingDeleteNotes(String folders) {
    return 'Also delete the exported note from $folders';
  }

  @override
  String get recordingDeleted => 'Recording deleted.';

  @override
  String recordingDeletedNotesKept(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Recording deleted. $count exported notes couldn’t be removed — delete them in your vault.',
      one: 'Recording deleted. 1 exported note couldn’t be removed — delete it in your vault.',
    );
    return '$_temp0';
  }

  @override
  String get recordingDeleteFailed => 'Couldn’t delete the recording.';

  @override
  String get actionItemsTitle => 'Action items';

  @override
  String get actionItemsOpen => 'Open';

  @override
  String get actionItemsAll => 'All';

  @override
  String get actionItemsLoadFailed => 'Couldn’t load action items.';

  @override
  String get actionItemsNoneOpen => 'No open action items.';

  @override
  String get actionItemsNone => 'No action items yet.';

  @override
  String get actionItemUpdateFailed => 'Couldn’t update the action item.';

  @override
  String get actionItemOpenRecording => 'Open recording';

  @override
  String get reviewTitle => 'Review before export';

  @override
  String get reviewTabEdit => 'Edit';

  @override
  String get reviewTabPreview => 'Preview';

  @override
  String reviewIntro(String profile) {
    return 'Check what $profile extracted. Fix names, tasks, owners and dates, then export the note.';
  }

  @override
  String get reviewExport => 'Export note';

  @override
  String get reviewExported => 'Saved. The note is being exported.';

  @override
  String get reviewFailed => 'Couldn’t save your changes. Try again.';

  @override
  String reviewInvalid(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count fields don’t match the profile (too long, missing or wrong type).',
      one: '1 field doesn’t match the profile (too long, missing or wrong type).',
    );
    return '$_temp0';
  }

  @override
  String get reviewPreviewFailed => 'The preview couldn’t be rendered.';

  @override
  String get reviewProfileMissing =>
      'The profile of this result no longer exists, so it can’t be edited.';

  @override
  String get reviewFieldNone => 'None';

  @override
  String get reviewFieldSource => 'Said at (hh:mm:ss)';

  @override
  String reviewPlayFrom(String time) {
    return 'Show in transcript at $time';
  }

  @override
  String reviewRemoveItem(String field) {
    return 'Remove from $field';
  }

  @override
  String reviewAddItem(String field) {
    return 'Add to $field';
  }

  @override
  String get reviewSettingsTitle => 'Review before export';

  @override
  String get reviewSettingsSubtitle =>
      'Check extracted results before notes are written';

  @override
  String get reviewSettingsIntro =>
      'Small on-device models make mistakes. For profiles set to review, results wait for you to check and edit them before the note is written to your vault.';

  @override
  String get reviewSettingsLoadFailed => 'Couldn’t load the profiles.';

  @override
  String get reviewModeReview => 'Review first';

  @override
  String get reviewModeAuto => 'Export automatically';

  @override
  String get reviewBanner => 'The result is waiting for your review.';

  @override
  String get reviewOpen => 'Review';

  @override
  String get reviewEditResult => 'Review & edit result';

  @override
  String get recordingDebugTooltip => 'Recording debug';

  @override
  String get importAudioTooltip => 'Import audio file';

  @override
  String get importAttestationTitle => 'Import a recording';

  @override
  String get importAttestationBody =>
      'The audio is processed on this device only. Import only recordings you are allowed to use.';

  @override
  String get importAttestationCheckbox =>
      'I have the right to process this recording and everyone in it consented to being recorded.';

  @override
  String get importAction => 'Import';

  @override
  String get importInProgress => 'Importing audio…';

  @override
  String get importDone => 'Imported. Processing has been queued.';

  @override
  String importUnsupportedFormat(String format) {
    return '$format files can’t be imported on this device.';
  }

  @override
  String get importUnsupportedUnknown =>
      'This file type can’t be imported on this device.';

  @override
  String get importNoAudio => 'This file contains no audio.';

  @override
  String get importFailed => 'The file could not be imported.';

  @override
  String get recordStart => 'Record';

  @override
  String get recordPause => 'Pause';

  @override
  String get recordResume => 'Resume';

  @override
  String get recordStop => 'Stop';

  @override
  String get recordMarker => 'Mark';

  @override
  String get recordMarkerAdded => 'Moment marked';

  @override
  String get recordStateIdle => 'Ready to record';

  @override
  String get recordStateRecording => 'Recording';

  @override
  String get recordStatePaused => 'Paused';

  @override
  String get recordPausedCall =>
      'Paused because a call started. Audio from the call was not recorded. Tap Resume to continue.';

  @override
  String get recordPausedInterruption =>
      'Paused: another app or the system took the microphone. Tap Resume to continue.';

  @override
  String get recordPausedError =>
      'Paused: the microphone stopped. Tap Resume to continue.';

  @override
  String get recordUnavailableDuringCalls =>
      'Recording is unavailable during calls';

  @override
  String get recordCallStateUnknown =>
      'Recording is unavailable: the call state could not be checked.';

  @override
  String get recordPermissionDenied =>
      'Microphone access is off. Allow it in the system settings to record.';

  @override
  String get recordLowStorage => 'Not enough free space to record.';

  @override
  String get recordLowStorageWarning => 'Storage is almost full.';

  @override
  String get recordStartFailed => 'Recording could not start.';

  @override
  String get recordProfileLabel => 'Profile';

  @override
  String get recordDestinationLabel => 'Destination';

  @override
  String get recordAuto => 'Auto';

  @override
  String get recordButtonStartLabel => 'Start recording';

  @override
  String get recordButtonPauseLabel => 'Pause recording';

  @override
  String get recordButtonResumeLabel => 'Resume recording';

  @override
  String get recordButtonStopLabel => 'Stop and save recording';

  @override
  String recordTimerLabel(String elapsed) {
    return '$elapsed recorded';
  }

  @override
  String get consentTitle => 'Recording consent';

  @override
  String get consentBody =>
      'This profile requires that everyone present agrees to be recorded before recording starts.';

  @override
  String get consentConfirm => 'Everyone present agrees';

  @override
  String get detailsTitle => 'Recording saved';

  @override
  String get detailsTitleField => 'Title';

  @override
  String get detailsTagsField => 'Tags';

  @override
  String get detailsTagsHint => 'Separate tags with commas';

  @override
  String get detailsSave => 'Save';

  @override
  String get detailsSkip => 'Later';

  @override
  String get recordStoppedSilence => 'Stopped after silence.';

  @override
  String get recordStoppedMax => 'Stopped at the maximum recording length.';

  @override
  String get recordStoppedStorage => 'Stopped because storage is almost full.';

  @override
  String get detailsQueued => 'Processing has been queued.';

  @override
  String get detailsProcessNow => 'Process now';

  @override
  String get diagnosticsTitle => 'Export diagnostics';

  @override
  String get diagnosticsSubtitle =>
      'Logs, device info and performance metrics. No recordings, transcripts or notes.';

  @override
  String get diagnosticsShareUnavailable => 'Sharing is not available.';

  @override
  String get diagnosticsFailed => 'Could not export diagnostics.';

  @override
  String diagnosticsPreviewSummary(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0, $size. Nothing leaves this device unless you choose a destination in the share sheet.';
  }

  @override
  String get diagnosticsShare => 'Share';

  @override
  String get notificationReadyTitle => 'Your note is ready';

  @override
  String get notificationReadyBody => 'Tap to open it.';

  @override
  String notificationReadyTitleWithRecording(String title) {
    return 'Note ready — $title';
  }

  @override
  String get notificationFailedTitle => 'Processing needs attention';

  @override
  String get notificationFailedBody => 'Tap to see what happened.';

  @override
  String notificationFailedTitleWithRecording(String title) {
    return 'Processing failed — $title';
  }

  @override
  String get notificationChannelProcessing => 'Processing';

  @override
  String get notificationProcessingOngoingTitle => 'Processing your recording';

  @override
  String get notificationProcessingOngoingBody =>
      'Transcription runs on this device.';

  @override
  String get jobQueued => 'Queued';

  @override
  String get jobTranscribing => 'Transcribing';

  @override
  String get jobDiarizing => 'Identifying speakers';

  @override
  String get jobClassifying => 'Choosing a profile';

  @override
  String get jobExtracting => 'Extracting details';

  @override
  String get jobRendering => 'Formatting the note';

  @override
  String get jobWriting => 'Saving to your vault';

  @override
  String get jobBetweenSteps => 'Waiting for the next step';

  @override
  String get jobDone => 'Note ready';

  @override
  String get jobFailedPermanent => 'Processing failed';

  @override
  String get jobFailedRetryable => 'Processing failed — you can retry';

  @override
  String get jobCancelled => 'Cancelled';

  @override
  String get jobPaused => 'Paused';

  @override
  String get jobWaitingModel => 'Waiting for a model download';

  @override
  String get jobWaitingProfile => 'Choose a profile to continue';

  @override
  String get jobWaitingReview => 'Ready for your review';

  @override
  String get jobWaitingDestination => 'Needs access to your vault folder';

  @override
  String get jobWaiting => 'Waiting';

  @override
  String get etaEstimating => 'Estimating time…';

  @override
  String get etaUnderMinute => 'Less than a minute left';

  @override
  String etaMinutes(int minutes) {
    return 'About $minutes min left';
  }

  @override
  String etaHours(int hours) {
    return 'About $hours h left';
  }

  @override
  String etaHoursMinutes(int hours, int minutes) {
    return 'About $hours h $minutes min left';
  }

  @override
  String jobPercent(int percent) {
    return '$percent%';
  }

  @override
  String jobQueuePosition(int position) {
    return 'Position $position in queue';
  }

  @override
  String jobProgressSemantics(String status, int percent) {
    return '$status, $percent percent';
  }

  @override
  String get untitledRecording => 'Untitled recording';

  @override
  String get jobProcessNow => 'Process now';

  @override
  String get jobCommandFailed => 'That did not work. Please try again.';

  @override
  String get processingTitle => 'Processing';

  @override
  String get processingStatusLoadFailed =>
      'Could not load the processing status.';

  @override
  String get processingNotProcessed =>
      'This recording has not been processed yet.';

  @override
  String get processingQueueTitle => 'Processing queue';

  @override
  String get processingQueueLoadFailed =>
      'Could not load the processing queue.';

  @override
  String get processingQueueEmpty => 'Nothing is being processed right now.';

  @override
  String queueProcessing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Processing $count recordings',
      one: 'Processing 1 recording',
    );
    return '$_temp0';
  }

  @override
  String queueNeedsAttention(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count need attention',
      one: '1 needs attention',
    );
    return '$_temp0';
  }

  @override
  String queueIndicatorSemantics(String summary) {
    return '$summary. Open processing queue';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get sectionAudio => 'Audio';

  @override
  String get sectionProcessing => 'Processing';

  @override
  String get sectionExport => 'Export';

  @override
  String get sectionPrivacy => 'Privacy & security';

  @override
  String get sectionLicense => 'License';

  @override
  String get sectionAbout => 'About';

  @override
  String get settingInputDevice => 'Input device';

  @override
  String get settingAgc => 'Automatic gain control';

  @override
  String get settingAgcDescription => 'Evens out quiet and loud voices.';

  @override
  String get settingNoiseSuppression => 'Noise suppression';

  @override
  String get settingSoftwareAgc => 'App gain control';

  @override
  String get settingSoftwareAgcDescription =>
      'Use VaultVoice’s own gain control instead of the phone’s. Used automatically when the phone has none.';

  @override
  String get settingRawCapture => 'Raw capture';

  @override
  String get settingRawCaptureDescription =>
      'Turns off all audio processing. For external microphones and testing.';

  @override
  String get clippingHint => 'Too loud — move the phone further away.';

  @override
  String get recordingLevelLabel => 'Input level';

  @override
  String get settingAutoPause => 'Auto-pause on silence';

  @override
  String get settingAutoPauseDescription =>
      'Pauses after 2 minutes of silence. Tap Resume to continue. Needs the voice detection model.';

  @override
  String get settingSilenceAutoStop => 'Stop after silence';

  @override
  String get settingSilenceAutoStopDescription =>
      'Ends the recording after this much silence. Needs the voice detection model.';

  @override
  String get settingSkipSilence => 'Skip silence';

  @override
  String get settingSkipSilenceDescription =>
      'Transcribes only the parts with speech: faster, and no text invented in silence.';

  @override
  String get optionOff => 'Off';

  @override
  String get settingAudioRetention => 'Keep audio';

  @override
  String get settingAutoProcess => 'Process after recording';

  @override
  String get settingAutoProcessDescription =>
      'Transcribe and extract as soon as a recording ends.';

  @override
  String get settingChargeOnly => 'Process only while charging';

  @override
  String get settingChargeOnlyDescription =>
      'Wait for a charger before heavy processing.';

  @override
  String get settingDiarization => 'Label speakers by default';

  @override
  String get settingDiarizationDescription =>
      'Profiles can still turn speaker labels on or off.';

  @override
  String get settingFilenamePattern => 'File name pattern';

  @override
  String get settingCollisionMode => 'If the file already exists';

  @override
  String get settingAppLock => 'App lock';

  @override
  String get settingAppLockDescription =>
      'Face ID, fingerprint or device passcode.';

  @override
  String get settingLockTimeout => 'Lock after';

  @override
  String get settingTranscriptRetention => 'Keep transcripts and notes';

  @override
  String get settingOfflineMode => 'Offline mode';

  @override
  String get settingOfflineModeDescription =>
      'Turns off all network use. Models must already be installed.';

  @override
  String get networkActivityTitle => 'Network activity';

  @override
  String get networkActivitySubtitle =>
      'Every connection this app made. Only model downloads are allowed.';

  @override
  String get networkActivityEmpty => 'No network requests yet.';

  @override
  String get networkActivityClear => 'Clear log';

  @override
  String networkActivityCompleted(String status) {
    return 'HTTP $status';
  }

  @override
  String get networkActivityDenied => 'Blocked before sending';

  @override
  String get networkActivityFailed => 'Failed';

  @override
  String get networkActivitySystem => 'Handed to system download';

  @override
  String networkActivityBytes(String size) {
    return '$size bytes';
  }

  @override
  String get settingNotifications => 'Notifications';

  @override
  String get settingNotificationsDescription =>
      'When a note is ready or processing needs attention.';

  @override
  String get settingNotificationDetails => 'Show details in notifications';

  @override
  String get settingNotificationDetailsDescription =>
      'Include the recording title. Off: generic text on the lock screen.';

  @override
  String get optionSystemDefault => 'System default';

  @override
  String get optionBuiltInMic => 'Built-in microphone';

  @override
  String get optionWiredHeadset => 'Wired headset';

  @override
  String get optionBluetoothHeadset => 'Bluetooth headset';

  @override
  String get optionKeepForever => 'Until I delete it';

  @override
  String get optionDeleteAfterExport => 'Delete after export';

  @override
  String optionDays(int days) {
    return '$days days';
  }

  @override
  String get optionCollisionSuffix => 'Add a number (-2, -3 …)';

  @override
  String get optionCollisionOverwrite => 'Replace my earlier export';

  @override
  String get optionCollisionSkip => 'Skip';

  @override
  String get optionImmediately => 'Immediately';

  @override
  String optionMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String get patternErrorEmpty => 'Enter a pattern.';

  @override
  String get patternErrorTooLong => 'Use at most 200 characters.';

  @override
  String get patternErrorUnsafe => 'Folders must stay inside the vault.';

  @override
  String get patternErrorUnbalanced => 'Every {{ needs a matching }}.';

  @override
  String get patternErrorInvalid => 'Invalid pattern.';

  @override
  String get settingManaged => 'Managed by your organization';

  @override
  String get settingSaveFailed => 'Could not save the setting.';

  @override
  String get settingsModels => 'Models';

  @override
  String get settingsModelsSubtitle =>
      'Speech and language models on this device';

  @override
  String get settingsVaultFolders => 'Vault folders';

  @override
  String settingsVaultFoldersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count folders',
      one: '1 folder',
      zero: 'The app’s own folder',
    );
    return '$_temp0';
  }

  @override
  String get settingsRoutingRules => 'Routing rules';

  @override
  String settingsRoutingRulesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rules',
      one: '1 rule',
      zero: 'None',
    );
    return '$_temp0';
  }

  @override
  String get encryptionTitle => 'Encryption';

  @override
  String get encryptionOn =>
      'On — the database is encrypted with a key kept in this device’s secure key store.';

  @override
  String get encryptionUnavailable =>
      'Unavailable — the encryption key could not be read, so your data stays locked. Restart the app.';

  @override
  String get encryptionOff => 'Off — this build does not encrypt the database.';

  @override
  String encryptionDetails(String status) {
    return '$status\n\nAudio files are protected by the device’s file encryption, and app data is never included in cloud backups. Recordings, transcripts and notes never leave this device unless you export or share them. Notes exported to a vault folder are plain Markdown files, readable by any app with access to that folder.';
  }

  @override
  String appLockTitle(String appName) {
    return '$appName is locked';
  }

  @override
  String get appLockBody =>
      'Unlock to see your recordings, transcripts and notes.';

  @override
  String get appLockUnavailable =>
      'This device has no passcode or biometrics set up, so the app cannot be locked. Set a device passcode to use the app lock.';

  @override
  String get appLockReason => 'Unlock to see your recordings and notes';

  @override
  String get appLockUnlock => 'Unlock';

  @override
  String get appLockRecord => 'Start recording';

  @override
  String get appLockRecording =>
      'Recording. Your recordings and notes stay hidden until you unlock.';

  @override
  String get appLockStop => 'Stop recording';

  @override
  String get deleteAllTitle => 'Delete all data';

  @override
  String get deleteAllConfirmTitle => 'Delete all data?';

  @override
  String get deleteAllConfirmBody =>
      'Deletes every recording, transcript, note, profile and setting on this device. Notes already exported to your vault folders are kept. This cannot be undone.';

  @override
  String get deleteAllConfirm => 'Delete everything';

  @override
  String get deleteAllDone => 'All data deleted.';

  @override
  String get deleteAllUnavailable =>
      'Deleting all data is not available in this build yet.';

  @override
  String get deleteAllFailed =>
      'Some data could not be deleted. Close any recording or processing in progress and try again.';

  @override
  String get licensePlanFree => 'Free';

  @override
  String get licensePlanPro => 'Pro';

  @override
  String get licensePlanEnterprise => 'Enterprise';

  @override
  String licenseUntil(String date) {
    return 'until $date';
  }

  @override
  String get licenseGrace => 'offline grace period';

  @override
  String get licenseStatus => 'Status';

  @override
  String get licenseRestore => 'Restore purchases';

  @override
  String get licenseRestored => 'Purchases restored.';

  @override
  String get licenseEnterpriseEnter => 'Enter enterprise license';

  @override
  String get licenseEnterpriseTitle => 'Enterprise license';

  @override
  String get licenseEnterpriseHint =>
      'Paste the license from your administrator';

  @override
  String get licenseEnterpriseInstall => 'Install';

  @override
  String get licenseEnterpriseInstalled => 'Enterprise license installed.';

  @override
  String get aboutVersion => 'Version';

  @override
  String get aboutLicenses => 'Open-source & model licenses';

  @override
  String get vaultFoldersAdd => 'Add folder';

  @override
  String get vaultFoldersAddFailed => 'Could not add the folder.';

  @override
  String get vaultFolderDefaultName => 'Vault folder';

  @override
  String get vaultFoldersRemoveTitle => 'Remove this folder?';

  @override
  String get vaultFoldersRemoveBody =>
      'Notes already written stay in the folder. Routing rules that use it are removed too.';

  @override
  String get vaultFoldersRemove => 'Remove';

  @override
  String vaultFoldersRemoveTooltip(String name) {
    return 'Remove $name';
  }

  @override
  String get vaultFoldersLoadFailed => 'Could not load your vault folders.';

  @override
  String get vaultFoldersEmpty =>
      'No vault folders yet. Notes are saved in the app’s own folder until you add one.';

  @override
  String get routingRulesLoadFailed => 'Could not load routing rules.';

  @override
  String get routingRulesEmpty =>
      'No routing rules. Every note goes to your first vault folder.';

  @override
  String get profilesBuiltinSection => 'Built-in profiles';

  @override
  String get profilesCustomSection => 'Your profiles';

  @override
  String get profilesCustomEmpty =>
      'No custom profiles yet. Create one or duplicate a built-in profile.';

  @override
  String get profilesLoadFailed => 'Could not load profiles.';

  @override
  String get profilesNew => 'New profile';

  @override
  String profilesDuplicate(String name) {
    return 'Duplicate $name';
  }

  @override
  String profilesCopyName(String name) {
    return '$name (copy)';
  }

  @override
  String get profilesProOnly => 'Custom profiles are a Pro feature.';

  @override
  String get profilesReadOnly => 'Read-only';

  @override
  String get profilesManaged => 'Managed by your organization';

  @override
  String get profileEditorNewTitle => 'New profile';

  @override
  String get profileEditorEditTitle => 'Edit profile';

  @override
  String get profileEditorViewTitle => 'Profile';

  @override
  String get profileEditorNotFound => 'This profile no longer exists.';

  @override
  String get profileEditorReadOnlyBanner =>
      'This profile is read-only. Duplicate it to make changes.';

  @override
  String get profileEditorProBanner =>
      'Editing custom profiles needs Pro. Your profiles keep working.';

  @override
  String get profileEditorName => 'Name';

  @override
  String get profileEditorDescription => 'Description';

  @override
  String get profileEditorInstructions => 'Instructions for the assistant';

  @override
  String get profileEditorInstructionsHint =>
      'Short bullet points, e.g. “Use the speaker’s name as owner.”';

  @override
  String get profileEditorSpeakers => 'Several speakers';

  @override
  String get profileEditorSpeakersHint =>
      'Label who said what (asks for consent before recording)';

  @override
  String get profileEditorFields => 'Fields';

  @override
  String get profileEditorAddField => 'Add field';

  @override
  String get profileEditorFieldLabel => 'Field name';

  @override
  String profileEditorFieldKey(String key) {
    return 'Key: $key';
  }

  @override
  String get profileEditorFieldType => 'Type';

  @override
  String get profileEditorFieldDescription => 'What to extract';

  @override
  String get profileEditorFieldColumns => 'Columns (comma-separated)';

  @override
  String profileEditorFieldRemove(String name) {
    return 'Remove field $name';
  }

  @override
  String get profileEditorFieldAdvanced => 'Advanced field, kept as is.';

  @override
  String get profileEditorKindText => 'Text';

  @override
  String get profileEditorKindLongText => 'Long text';

  @override
  String get profileEditorKindTextList => 'List of text';

  @override
  String get profileEditorKindDate => 'Date';

  @override
  String get profileEditorKindNumber => 'Number';

  @override
  String get profileEditorKindBoolean => 'Yes / no';

  @override
  String get profileEditorKindCheckboxList => 'Checkbox list';

  @override
  String get profileEditorKindTable => 'Table';

  @override
  String get profileEditorKindAdvanced => 'Advanced';

  @override
  String get profileEditorExamples => 'Examples (optional)';

  @override
  String get profileEditorAddExample => 'Add example';

  @override
  String get profileEditorExampleTranscript => 'Example transcript';

  @override
  String profileEditorExampleValue(String field) {
    return 'Expected $field';
  }

  @override
  String get profileEditorExampleRemove => 'Remove example';

  @override
  String get profileEditorTarget => 'Save notes to';

  @override
  String get profileEditorTargetDefault => 'App default';

  @override
  String get profileEditorTargetAsk => 'Ask every time';

  @override
  String get profileEditorSave => 'Save profile';

  @override
  String get profileEditorSaved => 'Profile saved.';

  @override
  String profileEditorSaveFailed(String reason) {
    return 'Could not save the profile: $reason';
  }

  @override
  String get profileEditorDelete => 'Delete profile';

  @override
  String get profileEditorDeleteTitle => 'Delete this profile?';

  @override
  String get profileEditorDeleteBody =>
      'Notes already exported stay in your vault.';

  @override
  String get profileEditorCancel => 'Cancel';

  @override
  String get profileEditorIssueName => 'Give the profile a name.';

  @override
  String get profileEditorIssueNoFields => 'Add at least one field.';

  @override
  String get profileEditorIssueTooManyFields => 'Too many fields (at most 25).';

  @override
  String get profileEditorIssueFieldName =>
      'Use a name that starts with a letter.';

  @override
  String get profileEditorIssueDuplicateField =>
      'Another field has the same name.';

  @override
  String get profileEditorIssueColumns =>
      'Add 1–8 columns with distinct names.';

  @override
  String get profileEditorTest => 'Test on a recording';

  @override
  String get profileEditorTestPick => 'Choose a recording';

  @override
  String get profileEditorTestNone => 'No transcribed recordings yet.';

  @override
  String get profileEditorTestRunning =>
      'Running the profile on this recording…';

  @override
  String get profileEditorTestFailed => 'The test run failed.';

  @override
  String get profileEditorTestJson => 'Extracted data';

  @override
  String get profileEditorTestMarkdown => 'Note preview';

  @override
  String get profileEditorTestInvalid =>
      'The output does not match the fields.';

  @override
  String get profileEditorTestClose => 'Close';

  @override
  String get profilesImport => 'Import profile';

  @override
  String profilesImportTitle(String name) {
    return 'Import $name?';
  }

  @override
  String get profilesImportNew => 'Adds this profile and its note template.';

  @override
  String profilesImportUpdate(int from, int to) {
    return 'Updates version $from to version $to.';
  }

  @override
  String get profilesImportManaged =>
      'Signed by your organization. It will be read-only.';

  @override
  String get profilesImportConfirm => 'Import';

  @override
  String get profilesImported => 'Profile imported.';

  @override
  String get profilesImportInvalid =>
      'This file is not a valid VaultVoice profile.';

  @override
  String get profilesImportUntrusted =>
      'This profile pack is signed by an unknown organization.';

  @override
  String get profilesImportTampered =>
      'This profile pack was changed after signing and cannot be imported.';

  @override
  String get profilesImportIdTaken =>
      'A different profile with this name is already installed.';

  @override
  String get profilesImportOlder =>
      'A newer version of this profile is already installed.';

  @override
  String get profilesImportSame => 'This version is already installed.';

  @override
  String get profilesImportNotEntitled =>
      'Importing this profile needs a plan that includes it.';

  @override
  String get profilesImportFailed => 'The import failed.';

  @override
  String get profileEditorExport => 'Export profile';

  @override
  String get profileEditorExportFailed => 'Could not export the profile.';

  @override
  String get transcriptTitle => 'Transcript';

  @override
  String get transcriptOpen => 'View and edit transcript';

  @override
  String get transcriptLoadFailed => 'Could not load the transcript.';

  @override
  String get transcriptEmpty =>
      'No transcript yet. It appears here when transcription has finished.';

  @override
  String get transcriptFindReplace => 'Find and replace';

  @override
  String get transcriptFind => 'Find';

  @override
  String get transcriptReplaceWith => 'Replace with';

  @override
  String get transcriptMatchCase => 'Match case';

  @override
  String transcriptMatchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count matches',
      one: '1 match',
      zero: 'No matches',
    );
    return '$_temp0';
  }

  @override
  String get transcriptReplaceAll => 'Replace all';

  @override
  String transcriptReplaced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count segments changed.',
      one: '1 segment changed.',
      zero: 'Nothing to replace.',
    );
    return '$_temp0';
  }

  @override
  String get transcriptReExtract => 'Re-extract with edits';

  @override
  String get transcriptReExtractStarted =>
      'Extraction restarted with your edited transcript.';

  @override
  String get transcriptReExtractFailed => 'Could not restart extraction.';

  @override
  String transcriptEditSegment(String time) {
    return 'Edit segment at $time';
  }

  @override
  String get transcriptEditFailed => 'Could not save your edit.';

  @override
  String transcriptSegmentLabel(String speaker, String time, String text) {
    return '$speaker at $time: $text. Tap to play from here.';
  }

  @override
  String get transcriptNoSpeaker => 'Segment';

  @override
  String get transcriptEdited => 'Edited';

  @override
  String get transcriptLowConfidenceHint => 'Underlined words may be misheard.';

  @override
  String get transcriptPlay => 'Play';

  @override
  String get transcriptPause => 'Pause';

  @override
  String get transcriptPlaybackUnavailable =>
      'Audio playback is not available for this recording.';

  @override
  String get transcriptMarkerUser => 'Marker';

  @override
  String get transcriptMarkerGap => 'Gap in the audio';

  @override
  String get transcriptMarkerCall => 'Recording stopped for a call';

  @override
  String transcriptMarkerLabel(String kind, String time) {
    return '$kind at $time';
  }

  @override
  String get routingRulesAdd => 'Add rule';

  @override
  String get routingRulesLocked =>
      'Routing rules are a Pro feature. Your rules are kept but not applied: every note goes to your first vault folder.';

  @override
  String routingRuleTo(String folder) {
    return 'To $folder';
  }

  @override
  String get routingRuleEveryNote => 'Every note';

  @override
  String routingRuleMatchesSome(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count conditions',
      one: '1 condition',
    );
    return 'Notes matching $_temp0';
  }

  @override
  String get routingRuleContinues => 'then later rules';

  @override
  String get routingRuleOff => 'Off';

  @override
  String get routingRuleNewTitle => 'New rule';

  @override
  String get routingRuleEditTitle => 'Edit rule';

  @override
  String get routingRuleName => 'Name (optional)';

  @override
  String get routingRuleTarget => 'Vault folder';

  @override
  String get routingRuleNoTargets => 'Add a vault folder first.';

  @override
  String get routingRuleTargetRequired => 'Choose a vault folder.';

  @override
  String get routingRuleSubPath => 'Sub-folder (optional)';

  @override
  String get routingRuleSubPathHint => 'For example Meetings/2026';

  @override
  String get routingRuleFilename => 'File name pattern (optional)';

  @override
  String get routingRuleFilenameHint =>
      'Empty: the folder’s or the default pattern';

  @override
  String get routingRuleConditions => 'Conditions';

  @override
  String get routingRuleConditionsHelp =>
      'Separate values with commas. Every filled-in condition must match; a rule without conditions matches every note.';

  @override
  String get routingRuleProfiles => 'Profile ids';

  @override
  String get routingRuleTags => 'Tags';

  @override
  String get routingRuleKeywords => 'Keywords in title or summary';

  @override
  String get routingRuleSpeakers => 'Speaker names';

  @override
  String get routingRuleContinue => 'Also check later rules';

  @override
  String get routingRuleContinueHelp =>
      'Off: the first matching rule decides. On: later matching rules add more folders.';

  @override
  String get routingRuleEnabled => 'Rule is on';

  @override
  String get routingRuleSave => 'Save';

  @override
  String get routingRuleSaveFailed => 'Could not save the rule.';

  @override
  String get routingRuleDelete => 'Delete rule';

  @override
  String get routingRuleDeleteTitle => 'Delete this rule?';

  @override
  String get routingRuleDeleteBody =>
      'Notes already written stay where they are.';

  @override
  String get routingRuleNotFound => 'This rule no longer exists.';

  @override
  String get vaultTargetOptionsTitle => 'Folder options';

  @override
  String get vaultTargetCollision => 'If the note already exists';

  @override
  String get vaultTargetCollisionDefault => 'Use the default setting';

  @override
  String get vaultTargetFilename => 'File name pattern (optional)';

  @override
  String get vaultTargetTranscript => 'Also save the transcript';

  @override
  String get vaultTargetTranscriptHelp =>
      'Writes a separate transcript note next to each note.';

  @override
  String get vaultTargetAudio => 'Also copy the audio';

  @override
  String get vaultTargetAudioHelp =>
      'Copies the recording into an attachments folder. Audio files are large and leave the app’s protected storage.';

  @override
  String get vaultTargetSaveFailed => 'Could not save the folder options.';

  @override
  String get vaultTargetDisabled => 'Not used on your current plan';

  @override
  String get vaultTargetNotFound => 'This folder no longer exists.';

  @override
  String get settingsPendingExports => 'Pending exports';

  @override
  String get settingsPendingExportsSubtitle =>
      'Notes still waiting for a vault folder';

  @override
  String get pendingExportsEmpty => 'Every note has reached its vault folder.';

  @override
  String get pendingExportsLoadFailed => 'Could not load pending exports.';

  @override
  String get pendingExportsSafe =>
      'Waiting notes are kept safely in the app until they can be written.';

  @override
  String get pendingUntitled => 'Untitled recording';

  @override
  String get pendingReasonNoDestination => 'No vault folder chosen yet';

  @override
  String pendingReasonRevoked(String folder) {
    return 'Access to $folder was removed';
  }

  @override
  String get pendingReasonRevokedAny =>
      'Access to the vault folder was removed';

  @override
  String pendingReasonRetrying(String folder) {
    return '$folder is not reachable right now. Retrying automatically.';
  }

  @override
  String pendingReasonFailed(String folder) {
    return 'Could not write to $folder';
  }

  @override
  String get pendingActionRegrant => 'Re-grant access';

  @override
  String get pendingActionChange => 'Choose another folder';

  @override
  String get pendingActionRetry => 'Retry now';

  @override
  String get pendingActionChooseFolder => 'Choose a folder';

  @override
  String get pendingActionSaveOnDevice => 'Save on this device';

  @override
  String get pendingActionFailed => 'That did not work. Please try again.';

  @override
  String get settingsTemplates => 'Templates';

  @override
  String get settingsTemplatesSubtitle => 'How your notes are laid out';

  @override
  String get templatesBuiltin => 'Built-in templates';

  @override
  String get templatesCustom => 'Your templates';

  @override
  String get templatesCustomEmpty =>
      'No custom templates yet. Open a built-in template and duplicate it to start.';

  @override
  String get templatesLocked =>
      'Custom templates are a Pro feature. Existing templates are kept read-only.';

  @override
  String get templatesLoadFailed => 'Could not load templates.';

  @override
  String get templateFlavorObsidian => 'Obsidian';

  @override
  String get templateFlavorLogseq => 'Logseq';

  @override
  String get templateFlavorPlain => 'Plain text';

  @override
  String templateForProfile(String profile) {
    return 'For $profile';
  }

  @override
  String get templateForAnyProfile => 'For every profile';

  @override
  String get templateReadOnly =>
      'Built-in templates are read-only. Duplicate it to make changes.';

  @override
  String get templateLockedReadOnly =>
      'Editing custom templates needs Pro. This template is read-only.';

  @override
  String get templateSource => 'Template source';

  @override
  String get templateDuplicate => 'Duplicate';

  @override
  String get templateDuplicateTitle => 'Duplicate template';

  @override
  String get templateDuplicateName => 'Name';

  @override
  String get templateDuplicateCreate => 'Create';

  @override
  String get templateSave => 'Save';

  @override
  String get templateSaved => 'Template saved.';

  @override
  String get templateSaveFailed => 'Could not save the template.';

  @override
  String templateFixIssues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count problems',
      one: '1 problem',
    );
    return 'Fix $_temp0 before saving.';
  }

  @override
  String get templateReset => 'Reset to default';

  @override
  String get templateResetDone => 'Built-in text restored. Save to keep it.';

  @override
  String get templateDelete => 'Delete template';

  @override
  String get templateDeleteTitle => 'Delete this template?';

  @override
  String get templateDeleteBody =>
      'Notes already written are not changed. Profiles using it go back to their default template.';

  @override
  String templateUseFor(String profile) {
    return 'Use for $profile notes';
  }

  @override
  String get templateFilename => 'File name pattern';

  @override
  String get templatePreview => 'Preview';

  @override
  String get templatePreviewRaw => 'Markdown';

  @override
  String get templatePreviewRendered => 'Rendered';

  @override
  String get templatePreviewData => 'Preview data';

  @override
  String get templatePreviewSample => 'Sample data';

  @override
  String get templatePreviewUnavailable => 'Fix the template to see a preview.';

  @override
  String templateIssueAt(int line, int column, String message) {
    return 'Line $line, column $column: $message';
  }

  @override
  String get templateNotFound => 'This template no longer exists.';

  @override
  String get templateMore => 'More actions';

  @override
  String templateImageOmitted(String alt) {
    return '[image: $alt]';
  }

  @override
  String get noteShare => 'Share note';

  @override
  String get noteShareTitle => 'Share or copy this note';

  @override
  String get noteShareFormat => 'Format';

  @override
  String get noteFormatObsidian => 'Obsidian';

  @override
  String get noteFormatLogseq => 'Logseq';

  @override
  String get noteFormatPlain => 'Plain';

  @override
  String get noteShareFile => 'Share as .md file';

  @override
  String get noteShareText => 'Share as text';

  @override
  String get noteCopy => 'Copy to clipboard';

  @override
  String get noteCopied => 'Note copied.';

  @override
  String get noteShareFailed => 'Could not prepare the note.';

  @override
  String get noteShareUnavailable => 'Sharing is not available on this device.';

  @override
  String get noteShareHint =>
      'The note leaves the app only through the app you pick.';

  @override
  String get indicatorRecordingTitle => 'Recording';

  @override
  String get indicatorRecordingText => 'VaultVoice is recording. Tap to open.';

  @override
  String get indicatorPausedTitle => 'Recording paused';

  @override
  String get indicatorPausedCallTitle =>
      'Recording paused because a call started';

  @override
  String get indicatorPausedCallText =>
      'Audio from the call was not recorded. Tap Resume to continue.';

  @override
  String get indicatorPausedMicText =>
      'Another app or the system took the microphone. Tap Resume to continue.';

  @override
  String get indicatorPausedSilenceTitle => 'Recording paused after silence';

  @override
  String get indicatorResumeHint => 'Tap Resume to continue.';

  @override
  String indicatorStillRecording(int hours, String minutes) {
    return 'Still recording (${hours}h ${minutes}m)';
  }
}
