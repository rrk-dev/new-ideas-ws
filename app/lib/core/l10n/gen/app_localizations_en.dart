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
  String get recordingDebugTooltip => 'Recording debug';

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
      'On — the database is encrypted with a key kept in the device keychain.';

  @override
  String get encryptionOff => 'Not enabled in this build yet.';

  @override
  String encryptionDetails(String status) {
    return '$status\n\nRecordings, transcripts and notes never leave this device unless you export or share them. Notes exported to a vault folder are plain Markdown files, readable by any app with access to that folder.';
  }

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
}
