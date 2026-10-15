import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonTryAgain;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get commonReset;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get commonLoading;

  /// No description provided for @commonNotAvailableYet.
  ///
  /// In en, this message translates to:
  /// **'Not available in this build yet.'**
  String get commonNotAvailableYet;

  /// No description provided for @tabRecord.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get tabRecord;

  /// No description provided for @tabLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get tabLibrary;

  /// No description provided for @tabProfiles.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get tabProfiles;

  /// No description provided for @tabSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

  /// No description provided for @placeholderScreenLabel.
  ///
  /// In en, this message translates to:
  /// **'{title} screen placeholder'**
  String placeholderScreenLabel(String title);

  /// No description provided for @callGuardDebugTooltip.
  ///
  /// In en, this message translates to:
  /// **'CallGuard debug'**
  String get callGuardDebugTooltip;

  /// No description provided for @crashShareUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Sharing is not available.'**
  String get crashShareUnavailable;

  /// No description provided for @crashShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not share the crash report.'**
  String get crashShareFailed;

  /// No description provided for @crashPromptTitleNative.
  ///
  /// In en, this message translates to:
  /// **'{appName} closed unexpectedly'**
  String crashPromptTitleNative(String appName);

  /// No description provided for @crashPromptTitleDart.
  ///
  /// In en, this message translates to:
  /// **'{appName} hit an unexpected error'**
  String crashPromptTitleDart(String appName);

  /// No description provided for @crashPromptBody.
  ///
  /// In en, this message translates to:
  /// **'A crash report was saved on this device. It contains only technical details (error type, code addresses, app and OS version) — no recordings, transcripts or notes. You can review it and send it to the developers, for example by email. Nothing is sent automatically.'**
  String get crashPromptBody;

  /// No description provided for @crashPromptNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get crashPromptNotNow;

  /// No description provided for @crashPromptReview.
  ///
  /// In en, this message translates to:
  /// **'Review report'**
  String get crashPromptReview;

  /// No description provided for @crashPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Crash report'**
  String get crashPreviewTitle;

  /// No description provided for @crashPreviewInfo.
  ///
  /// In en, this message translates to:
  /// **'{name} · {size}. This is the complete file. Nothing leaves this device unless you choose a destination in the share sheet.'**
  String crashPreviewInfo(String name, String size);

  /// No description provided for @crashPreviewDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get crashPreviewDiscard;

  /// No description provided for @crashPreviewShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get crashPreviewShare;

  /// No description provided for @crashSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Crash reports'**
  String get crashSettingsTitle;

  /// No description provided for @crashSettingsNone.
  ///
  /// In en, this message translates to:
  /// **'None saved. Reports stay on this device until you share them.'**
  String get crashSettingsNone;

  /// No description provided for @crashSettingsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} saved on this device. Tap to review and share.'**
  String crashSettingsCount(int count);

  /// No description provided for @crashDevForceNative.
  ///
  /// In en, this message translates to:
  /// **'Force native crash (dev)'**
  String get crashDevForceNative;

  /// No description provided for @crashDevForceNativeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Kills the app via SIGSEGV in libvv_native.'**
  String get crashDevForceNativeSubtitle;

  /// No description provided for @crashDevConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Crash the app now?'**
  String get crashDevConfirmTitle;

  /// No description provided for @crashDevConfirm.
  ///
  /// In en, this message translates to:
  /// **'Crash'**
  String get crashDevConfirm;

  /// No description provided for @crashDevThrowDart.
  ///
  /// In en, this message translates to:
  /// **'Throw uncaught Dart error (dev)'**
  String get crashDevThrowDart;

  /// No description provided for @batteryGuidanceIntro.
  ///
  /// In en, this message translates to:
  /// **'Long recordings can be stopped by this phone’s battery saver when the screen is off. {steps}'**
  String batteryGuidanceIntro(String steps);

  /// No description provided for @batteryGuidanceSamsung.
  ///
  /// In en, this message translates to:
  /// **'Settings → Battery → Background usage limits → Never sleeping apps → add VaultVoice.'**
  String get batteryGuidanceSamsung;

  /// No description provided for @batteryGuidanceXiaomi.
  ///
  /// In en, this message translates to:
  /// **'Settings → Apps → VaultVoice → Battery saver → No restrictions, and turn on Autostart.'**
  String get batteryGuidanceXiaomi;

  /// No description provided for @batteryGuidanceOnePlus.
  ///
  /// In en, this message translates to:
  /// **'Settings → Battery → VaultVoice → Allow background activity.'**
  String get batteryGuidanceOnePlus;

  /// No description provided for @batteryGuidanceGeneric.
  ///
  /// In en, this message translates to:
  /// **'In battery settings, allow VaultVoice to run in the background.'**
  String get batteryGuidanceGeneric;

  /// No description provided for @batteryGuidanceOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open battery settings'**
  String get batteryGuidanceOpenSettings;

  /// No description provided for @recoveredTitle.
  ///
  /// In en, this message translates to:
  /// **'Recording recovered'**
  String get recoveredTitle;

  /// No description provided for @recoveredPrompt.
  ///
  /// In en, this message translates to:
  /// **'Recovered recording from {when} — process now?'**
  String recoveredPrompt(String when);

  /// No description provided for @recoveredDetails.
  ///
  /// In en, this message translates to:
  /// **'Length: {minutes}m {seconds}s. The app was closed while recording; the audio captured up to then was kept.'**
  String recoveredDetails(int minutes, String seconds);

  /// No description provided for @recoveredLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get recoveredLater;

  /// No description provided for @recoveredProcessNow.
  ///
  /// In en, this message translates to:
  /// **'Process now'**
  String get recoveredProcessNow;

  /// No description provided for @modelImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import model from file'**
  String get modelImportTitle;

  /// No description provided for @modelImportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select the model file with its signed manifest (.json and .sig). Works without a network connection.'**
  String get modelImportSubtitle;

  /// No description provided for @modelImportInstalled.
  ///
  /// In en, this message translates to:
  /// **'Model installed'**
  String get modelImportInstalled;

  /// No description provided for @modelImportUnsignedTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsigned custom model'**
  String get modelImportUnsignedTitle;

  /// No description provided for @modelImportUnsignedBody.
  ///
  /// In en, this message translates to:
  /// **'This file is not a VaultVoice-signed model. Only import GGUF files from a source you trust: a malformed or malicious model file can crash the app. Its license is your responsibility.'**
  String get modelImportUnsignedBody;

  /// No description provided for @modelImportAnyway.
  ///
  /// In en, this message translates to:
  /// **'Import anyway'**
  String get modelImportAnyway;

  /// No description provided for @modelImportErrorUnknownModel.
  ///
  /// In en, this message translates to:
  /// **'Not a signed VaultVoice model. Select the model file together with its .json and .sig files.'**
  String get modelImportErrorUnknownModel;

  /// No description provided for @modelImportErrorMissingFiles.
  ///
  /// In en, this message translates to:
  /// **'Select exactly one model file plus its .json and .sig files.'**
  String get modelImportErrorMissingFiles;

  /// No description provided for @modelImportErrorEntitlement.
  ///
  /// In en, this message translates to:
  /// **'Custom models require VaultVoice Pro.'**
  String get modelImportErrorEntitlement;

  /// No description provided for @modelImportErrorInvalidGguf.
  ///
  /// In en, this message translates to:
  /// **'This file is not a valid GGUF model.'**
  String get modelImportErrorInvalidGguf;

  /// No description provided for @modelImportErrorNotSingleModel.
  ///
  /// In en, this message translates to:
  /// **'The manifest is not a single-model manifest.'**
  String get modelImportErrorNotSingleModel;

  /// No description provided for @modelImportErrorSignature.
  ///
  /// In en, this message translates to:
  /// **'The manifest signature is not valid.'**
  String get modelImportErrorSignature;

  /// No description provided for @modelImportErrorIntegrity.
  ///
  /// In en, this message translates to:
  /// **'The model file does not match its manifest (size or checksum).'**
  String get modelImportErrorIntegrity;

  /// No description provided for @modelImportErrorNoSpace.
  ///
  /// In en, this message translates to:
  /// **'Not enough free space.'**
  String get modelImportErrorNoSpace;

  /// No description provided for @modelImportErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Import failed.'**
  String get modelImportErrorGeneric;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get commonNotNow;

  /// No description provided for @bytesKilobytes.
  ///
  /// In en, this message translates to:
  /// **'{value} KB'**
  String bytesKilobytes(String value);

  /// No description provided for @bytesMegabytes.
  ///
  /// In en, this message translates to:
  /// **'{value} MB'**
  String bytesMegabytes(String value);

  /// No description provided for @bytesGigabytes.
  ///
  /// In en, this message translates to:
  /// **'{value} GB'**
  String bytesGigabytes(String value);

  /// No description provided for @deviceTierLow.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get deviceTierLow;

  /// No description provided for @deviceTierMid.
  ///
  /// In en, this message translates to:
  /// **'Capable'**
  String get deviceTierMid;

  /// No description provided for @deviceTierHigh.
  ///
  /// In en, this message translates to:
  /// **'High-end'**
  String get deviceTierHigh;

  /// No description provided for @modelTypeStt.
  ///
  /// In en, this message translates to:
  /// **'Speech to text'**
  String get modelTypeStt;

  /// No description provided for @modelTypeLlm.
  ///
  /// In en, this message translates to:
  /// **'Note writer (AI)'**
  String get modelTypeLlm;

  /// No description provided for @modelTypeVad.
  ///
  /// In en, this message translates to:
  /// **'Speech detection'**
  String get modelTypeVad;

  /// No description provided for @modelTypeSpeakers.
  ///
  /// In en, this message translates to:
  /// **'Speaker separation'**
  String get modelTypeSpeakers;

  /// No description provided for @modelTypeAccelerator.
  ///
  /// In en, this message translates to:
  /// **'Speech accelerator'**
  String get modelTypeAccelerator;

  /// No description provided for @modelSummary.
  ///
  /// In en, this message translates to:
  /// **'{type} · {size}'**
  String modelSummary(String type, String size);

  /// No description provided for @modelStatusInstalled.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get modelStatusInstalled;

  /// No description provided for @modelStatusNotDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Not downloaded'**
  String get modelStatusNotDownloaded;

  /// No description provided for @downloadPhaseChecking.
  ///
  /// In en, this message translates to:
  /// **'Preparing download…'**
  String get downloadPhaseChecking;

  /// No description provided for @downloadPhaseDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading · {percent}%'**
  String downloadPhaseDownloading(int percent);

  /// No description provided for @downloadPhaseRetrying.
  ///
  /// In en, this message translates to:
  /// **'Connection lost, retrying…'**
  String get downloadPhaseRetrying;

  /// No description provided for @downloadPhasePaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get downloadPhasePaused;

  /// No description provided for @downloadPhaseVerifying.
  ///
  /// In en, this message translates to:
  /// **'Checking the file…'**
  String get downloadPhaseVerifying;

  /// No description provided for @downloadPhaseInstalling.
  ///
  /// In en, this message translates to:
  /// **'Installing…'**
  String get downloadPhaseInstalling;

  /// No description provided for @downloadPhaseFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get downloadPhaseFailed;

  /// No description provided for @downloadUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Model downloads are not available right now.'**
  String get downloadUnavailable;

  /// No description provided for @downloadOffline.
  ///
  /// In en, this message translates to:
  /// **'You’re offline. Connect to the internet to download models.'**
  String get downloadOffline;

  /// No description provided for @downloadNoSpace.
  ///
  /// In en, this message translates to:
  /// **'Not enough free space: {needed} needed, {free} available.'**
  String downloadNoSpace(String needed, String free);

  /// No description provided for @downloadCellularTitle.
  ///
  /// In en, this message translates to:
  /// **'Use mobile data?'**
  String get downloadCellularTitle;

  /// No description provided for @downloadCellularBody.
  ///
  /// In en, this message translates to:
  /// **'You’re not on Wi-Fi. Downloading {size} over mobile data may cost money.'**
  String downloadCellularBody(String size);

  /// No description provided for @downloadCellularAlways.
  ///
  /// In en, this message translates to:
  /// **'Always allow mobile data for models'**
  String get downloadCellularAlways;

  /// No description provided for @downloadWaitForWifi.
  ///
  /// In en, this message translates to:
  /// **'Wait for Wi-Fi'**
  String get downloadWaitForWifi;

  /// No description provided for @downloadNow.
  ///
  /// In en, this message translates to:
  /// **'Download now'**
  String get downloadNow;

  /// No description provided for @downloadWaitingForWifi.
  ///
  /// In en, this message translates to:
  /// **'Not downloading. Start it again from Settings › Models when you’re on Wi-Fi.'**
  String get downloadWaitingForWifi;

  /// No description provided for @downloadLowPowerTitle.
  ///
  /// In en, this message translates to:
  /// **'Low Power Mode is on'**
  String get downloadLowPowerTitle;

  /// No description provided for @downloadLowPowerBody.
  ///
  /// In en, this message translates to:
  /// **'Downloading large models uses battery. Download anyway?'**
  String get downloadLowPowerBody;

  /// No description provided for @downloadLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get downloadLater;

  /// No description provided for @downloadAnyway.
  ///
  /// In en, this message translates to:
  /// **'Download anyway'**
  String get downloadAnyway;

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Downloading {name} failed. Try again from Settings › Models.'**
  String downloadFailed(String name);

  /// No description provided for @onboardingStepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String onboardingStepOf(int step, int total);

  /// No description provided for @onboardingBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get onboardingBack;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onboardingGetStarted;

  /// No description provided for @onboardingPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your recordings stay on your device'**
  String get onboardingPrivacyTitle;

  /// No description provided for @onboardingPrivacyOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Recording, transcription and note writing all happen on this phone. No account, no cloud, no analytics.'**
  String get onboardingPrivacyOnDevice;

  /// No description provided for @onboardingPrivacyNetwork.
  ///
  /// In en, this message translates to:
  /// **'The only thing VaultVoice downloads is its AI models. Nothing you record is ever uploaded.'**
  String get onboardingPrivacyNetwork;

  /// No description provided for @onboardingPrivacyVault.
  ///
  /// In en, this message translates to:
  /// **'Your notes are saved as Markdown files in a folder you choose, such as your Obsidian or Logseq vault.'**
  String get onboardingPrivacyVault;

  /// No description provided for @consentExplainerTitle.
  ///
  /// In en, this message translates to:
  /// **'Record responsibly'**
  String get consentExplainerTitle;

  /// No description provided for @consentExplainerAsk.
  ///
  /// In en, this message translates to:
  /// **'Only record people who know they are being recorded and agree to it.'**
  String get consentExplainerAsk;

  /// No description provided for @consentExplainerLaws.
  ///
  /// In en, this message translates to:
  /// **'Recording laws differ between countries and states. In many places everyone in the conversation must agree.'**
  String get consentExplainerLaws;

  /// No description provided for @consentExplainerConfirm.
  ///
  /// In en, this message translates to:
  /// **'For conversations with several people, VaultVoice asks you to confirm that everyone agreed before it starts.'**
  String get consentExplainerConfirm;

  /// No description provided for @consentNeverCalls.
  ///
  /// In en, this message translates to:
  /// **'VaultVoice never records phone or VoIP calls. When a call starts, recording stops and does not resume on its own.'**
  String get consentNeverCalls;

  /// No description provided for @consentExplainerAcknowledge.
  ///
  /// In en, this message translates to:
  /// **'I will only record people with their consent'**
  String get consentExplainerAcknowledge;

  /// No description provided for @onboardingPermissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'What VaultVoice will ask for'**
  String get onboardingPermissionsTitle;

  /// No description provided for @onboardingPermissionMic.
  ///
  /// In en, this message translates to:
  /// **'Microphone: your phone asks the first time you tap Record — never before, and never in the background.'**
  String get onboardingPermissionMic;

  /// No description provided for @onboardingPermissionNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications: get a message when a note is ready or processing needs your attention. Optional.'**
  String get onboardingPermissionNotifications;

  /// No description provided for @onboardingAllowNotifications.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications'**
  String get onboardingAllowNotifications;

  /// No description provided for @notificationsAllowed.
  ///
  /// In en, this message translates to:
  /// **'Notifications are on.'**
  String get notificationsAllowed;

  /// No description provided for @notificationsDeniedBody.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off. Processing still works — check the Library for finished notes. You can turn notifications on in the system settings.'**
  String get notificationsDeniedBody;

  /// No description provided for @onboardingPermissionFolder.
  ///
  /// In en, this message translates to:
  /// **'Folder: you choose where notes are saved in the next steps. VaultVoice can only see that folder.'**
  String get onboardingPermissionFolder;

  /// No description provided for @permissionOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get permissionOpenSettings;

  /// No description provided for @permissionOpenSettingsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the system settings. Open them from your home screen.'**
  String get permissionOpenSettingsFailed;

  /// No description provided for @micPrimerTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow microphone access'**
  String get micPrimerTitle;

  /// No description provided for @micPrimerBody.
  ///
  /// In en, this message translates to:
  /// **'VaultVoice needs the microphone to record what you choose to record. The audio stays on this device. Your phone will ask for permission next.'**
  String get micPrimerBody;

  /// No description provided for @micDeniedBody.
  ///
  /// In en, this message translates to:
  /// **'Microphone access is off, so VaultVoice can’t record. You can still import audio and browse your notes. Allow the microphone in the system settings to record.'**
  String get micDeniedBody;

  /// No description provided for @onboardingModelsTitle.
  ///
  /// In en, this message translates to:
  /// **'AI models for this device'**
  String get onboardingModelsTitle;

  /// No description provided for @onboardingModelsChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking this device'**
  String get onboardingModelsChecking;

  /// No description provided for @onboardingModelsDevice.
  ///
  /// In en, this message translates to:
  /// **'Device class: {tier} ({ram} memory). Recommended:'**
  String onboardingModelsDevice(String tier, String ram);

  /// No description provided for @onboardingModelsDeviceUnknown.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t check this device, so the smallest models are recommended:'**
  String get onboardingModelsDeviceUnknown;

  /// No description provided for @onboardingModelsTotal.
  ///
  /// In en, this message translates to:
  /// **'Total download: {size}. Wi-Fi recommended.'**
  String onboardingModelsTotal(String size);

  /// No description provided for @onboardingModelsDownload.
  ///
  /// In en, this message translates to:
  /// **'Download {size}'**
  String onboardingModelsDownload(String size);

  /// No description provided for @onboardingModelsExplore.
  ///
  /// In en, this message translates to:
  /// **'You can continue and record while the models download. Recordings are processed as soon as the models are ready.'**
  String get onboardingModelsExplore;

  /// No description provided for @onboardingModelsReady.
  ///
  /// In en, this message translates to:
  /// **'All recommended models are installed.'**
  String get onboardingModelsReady;

  /// No description provided for @onboardingModelsOffline.
  ///
  /// In en, this message translates to:
  /// **'Downloads are turned off on this device (offline mode or your organization). Import the model files instead:'**
  String get onboardingModelsOffline;

  /// No description provided for @onboardingModelsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No model recommendation is available right now. You can download models later in Settings › Models.'**
  String get onboardingModelsUnavailable;

  /// No description provided for @onboardingFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Where should notes go?'**
  String get onboardingFolderTitle;

  /// No description provided for @onboardingFolderBody.
  ///
  /// In en, this message translates to:
  /// **'Pick your Obsidian or Logseq vault, or any folder. VaultVoice only gets access to the folder you pick.'**
  String get onboardingFolderBody;

  /// No description provided for @onboardingFolderChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose folder'**
  String get onboardingFolderChoose;

  /// No description provided for @onboardingFolderChooseAnother.
  ///
  /// In en, this message translates to:
  /// **'Choose another folder'**
  String get onboardingFolderChooseAnother;

  /// No description provided for @onboardingFolderChosen.
  ///
  /// In en, this message translates to:
  /// **'Notes will be saved in {name}.'**
  String onboardingFolderChosen(String name);

  /// No description provided for @onboardingFolderFailed.
  ///
  /// In en, this message translates to:
  /// **'That folder couldn’t be used. Try another one, or keep notes in the app for now.'**
  String get onboardingFolderFailed;

  /// No description provided for @onboardingFolderLater.
  ///
  /// In en, this message translates to:
  /// **'You can add or change folders anytime in Settings › Vault folders.'**
  String get onboardingFolderLater;

  /// No description provided for @onboardingFolderKeepInApp.
  ///
  /// In en, this message translates to:
  /// **'Keep notes in the app for now'**
  String get onboardingFolderKeepInApp;

  /// No description provided for @onboardingReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'You’re all set'**
  String get onboardingReadyTitle;

  /// No description provided for @onboardingReadyBody.
  ///
  /// In en, this message translates to:
  /// **'Tap Record to make your first note. If the models are still downloading, your recording waits and is processed automatically when they’re ready.'**
  String get onboardingReadyBody;

  /// No description provided for @onboardingFirstRecording.
  ///
  /// In en, this message translates to:
  /// **'Make my first recording'**
  String get onboardingFirstRecording;

  /// No description provided for @onboardingExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore first'**
  String get onboardingExplore;

  /// No description provided for @modelsCheckUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for model updates'**
  String get modelsCheckUpdates;

  /// No description provided for @modelsCatalogChecked.
  ///
  /// In en, this message translates to:
  /// **'Model list checked.'**
  String get modelsCatalogChecked;

  /// No description provided for @modelsCatalogFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t check for model updates. Try again later.'**
  String get modelsCatalogFailed;

  /// No description provided for @modelsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load the model list.'**
  String get modelsLoadFailed;

  /// No description provided for @modelsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No models are available. Check for updates or import model files.'**
  String get modelsEmpty;

  /// No description provided for @modelsStorageTitle.
  ///
  /// In en, this message translates to:
  /// **'Storage used'**
  String get modelsStorageTitle;

  /// No description provided for @modelsStorageModels.
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get modelsStorageModels;

  /// No description provided for @modelsStorageAudio.
  ///
  /// In en, this message translates to:
  /// **'Recordings (audio)'**
  String get modelsStorageAudio;

  /// No description provided for @modelsStorageTranscripts.
  ///
  /// In en, this message translates to:
  /// **'Transcripts'**
  String get modelsStorageTranscripts;

  /// No description provided for @modelsUpdatesAvailable.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{An update is available for 1 model.} other{Updates are available for {count} models.}}'**
  String modelsUpdatesAvailable(int count);

  /// No description provided for @modelsOfflineNotice.
  ///
  /// In en, this message translates to:
  /// **'Downloads are turned off on this device (offline mode or your organization). Import model files below.'**
  String get modelsOfflineNotice;

  /// No description provided for @modelsImportSection.
  ///
  /// In en, this message translates to:
  /// **'Import from files'**
  String get modelsImportSection;

  /// No description provided for @modelsAdvancedCustom.
  ///
  /// In en, this message translates to:
  /// **'Advanced: custom models'**
  String get modelsAdvancedCustom;

  /// No description provided for @modelsAdvancedCustomSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Allow importing unsigned GGUF files. Only use files you trust.'**
  String get modelsAdvancedCustomSubtitle;

  /// No description provided for @modelBadgePro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get modelBadgePro;

  /// No description provided for @modelBadgeEnterprise.
  ///
  /// In en, this message translates to:
  /// **'Enterprise'**
  String get modelBadgeEnterprise;

  /// No description provided for @modelBadgeActive.
  ///
  /// In en, this message translates to:
  /// **'In use'**
  String get modelBadgeActive;

  /// No description provided for @modelBadgeRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get modelBadgeRecommended;

  /// No description provided for @modelBadgeUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get modelBadgeUpdate;

  /// No description provided for @modelSizeVersion.
  ///
  /// In en, this message translates to:
  /// **'{size} · version {version}'**
  String modelSizeVersion(String size, String version);

  /// No description provided for @modelIncompatible.
  ///
  /// In en, this message translates to:
  /// **'Needs {ram} of memory — may not run on this device.'**
  String modelIncompatible(String ram);

  /// No description provided for @modelNotOnPlan.
  ///
  /// In en, this message translates to:
  /// **'Not available on your current plan. It stays installed but can’t be used.'**
  String get modelNotOnPlan;

  /// No description provided for @modelRequiresPro.
  ///
  /// In en, this message translates to:
  /// **'Requires Pro'**
  String get modelRequiresPro;

  /// No description provided for @modelActionDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get modelActionDownload;

  /// No description provided for @modelActionResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get modelActionResume;

  /// No description provided for @modelActionUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get modelActionUpdate;

  /// No description provided for @modelActionPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get modelActionPause;

  /// No description provided for @modelActionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel download'**
  String get modelActionCancel;

  /// No description provided for @modelActionUse.
  ///
  /// In en, this message translates to:
  /// **'Use this model'**
  String get modelActionUse;

  /// No description provided for @modelActionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get modelActionDelete;

  /// No description provided for @modelActivated.
  ///
  /// In en, this message translates to:
  /// **'{name} will be used for new processing.'**
  String modelActivated(String name);

  /// No description provided for @modelDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String modelDeleteTitle(String name);

  /// No description provided for @modelDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This frees {size}. You can download it again later.'**
  String modelDeleteBody(String size);

  /// No description provided for @modelDeleteReplaceBody.
  ///
  /// In en, this message translates to:
  /// **'{name} is used to process recordings. Choose the model to use instead:'**
  String modelDeleteReplaceBody(String name);

  /// No description provided for @modelDeleteAndSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch and delete'**
  String get modelDeleteAndSwitch;

  /// No description provided for @modelDeleteBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Can’t delete this model'**
  String get modelDeleteBlockedTitle;

  /// No description provided for @modelDeleteBlockedBody.
  ///
  /// In en, this message translates to:
  /// **'It’s the only installed model for {type}, and VaultVoice needs one to process recordings. Download another one first, then delete this one.'**
  String modelDeleteBlockedBody(String type);

  /// No description provided for @modelDeleted.
  ///
  /// In en, this message translates to:
  /// **'{name} deleted.'**
  String modelDeleted(String name);

  /// No description provided for @modelDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t delete the model.'**
  String get modelDeleteFailed;

  /// No description provided for @librarySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search recordings, transcripts and notes'**
  String get librarySearchHint;

  /// No description provided for @librarySearchClear.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get librarySearchClear;

  /// No description provided for @librarySort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get librarySort;

  /// No description provided for @librarySortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get librarySortNewest;

  /// No description provided for @librarySortOldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest first'**
  String get librarySortOldest;

  /// No description provided for @librarySortLongest.
  ///
  /// In en, this message translates to:
  /// **'Longest first'**
  String get librarySortLongest;

  /// No description provided for @librarySortTitle.
  ///
  /// In en, this message translates to:
  /// **'Title A–Z'**
  String get librarySortTitle;

  /// No description provided for @libraryLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load your recordings.'**
  String get libraryLoadFailed;

  /// No description provided for @libraryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No recordings yet. Tap Record to make your first note.'**
  String get libraryEmpty;

  /// No description provided for @libraryNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No recordings match your search or filters.'**
  String get libraryNoMatches;

  /// No description provided for @libraryFilterStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get libraryFilterStatus;

  /// No description provided for @libraryFilterProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get libraryFilterProfile;

  /// No description provided for @libraryFilterTag.
  ///
  /// In en, this message translates to:
  /// **'Tag'**
  String get libraryFilterTag;

  /// No description provided for @libraryFilterDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get libraryFilterDate;

  /// No description provided for @libraryFilterClear.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get libraryFilterClear;

  /// No description provided for @libraryFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get libraryFilterAll;

  /// No description provided for @libraryExportedTo.
  ///
  /// In en, this message translates to:
  /// **'{status} · {folders}'**
  String libraryExportedTo(String status, String folders);

  /// No description provided for @libraryStatusRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get libraryStatusRecording;

  /// No description provided for @libraryStatusRecorded.
  ///
  /// In en, this message translates to:
  /// **'Not processed'**
  String get libraryStatusRecorded;

  /// No description provided for @libraryStatusProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get libraryStatusProcessing;

  /// No description provided for @libraryStatusWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get libraryStatusWaiting;

  /// No description provided for @libraryStatusProcessed.
  ///
  /// In en, this message translates to:
  /// **'Processed, not exported'**
  String get libraryStatusProcessed;

  /// No description provided for @libraryStatusExported.
  ///
  /// In en, this message translates to:
  /// **'Exported'**
  String get libraryStatusExported;

  /// No description provided for @libraryStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get libraryStatusFailed;

  /// No description provided for @durationHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String durationHoursMinutes(int hours, int minutes);

  /// No description provided for @durationMinutesSeconds.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min {seconds} s'**
  String durationMinutesSeconds(int minutes, int seconds);

  /// No description provided for @durationSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String durationSeconds(int seconds);

  /// No description provided for @recordingLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load this recording.'**
  String get recordingLoadFailed;

  /// No description provided for @recordingNotFound.
  ///
  /// In en, this message translates to:
  /// **'This recording no longer exists.'**
  String get recordingNotFound;

  /// No description provided for @recordingImported.
  ///
  /// In en, this message translates to:
  /// **'Imported'**
  String get recordingImported;

  /// No description provided for @recordingActions.
  ///
  /// In en, this message translates to:
  /// **'Recording actions'**
  String get recordingActions;

  /// No description provided for @recordingReExtract.
  ///
  /// In en, this message translates to:
  /// **'Extract again'**
  String get recordingReExtract;

  /// No description provided for @recordingChangeProfile.
  ///
  /// In en, this message translates to:
  /// **'Change profile'**
  String get recordingChangeProfile;

  /// No description provided for @recordingReExport.
  ///
  /// In en, this message translates to:
  /// **'Export again'**
  String get recordingReExport;

  /// No description provided for @recordingDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete recording'**
  String get recordingDelete;

  /// No description provided for @recordingBusy.
  ///
  /// In en, this message translates to:
  /// **'Processing is running. Try again when it has finished.'**
  String get recordingBusy;

  /// No description provided for @recordingProfileCurrent.
  ///
  /// In en, this message translates to:
  /// **'{name} (current)'**
  String recordingProfileCurrent(String name);

  /// No description provided for @recordingTranscript.
  ///
  /// In en, this message translates to:
  /// **'Transcript'**
  String get recordingTranscript;

  /// No description provided for @recordingNoTranscript.
  ///
  /// In en, this message translates to:
  /// **'No transcript yet.'**
  String get recordingNoTranscript;

  /// No description provided for @recordingShowTranscript.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Show the full transcript (1 line)} other{Show the full transcript ({count} lines)}}'**
  String recordingShowTranscript(int count);

  /// No description provided for @transcriptSpeakerLine.
  ///
  /// In en, this message translates to:
  /// **'{speaker}: {text}'**
  String transcriptSpeakerLine(String speaker, String text);

  /// No description provided for @recordingExtracted.
  ///
  /// In en, this message translates to:
  /// **'Extracted'**
  String get recordingExtracted;

  /// No description provided for @recordingNoExtraction.
  ///
  /// In en, this message translates to:
  /// **'Nothing extracted yet.'**
  String get recordingNoExtraction;

  /// No description provided for @recordingExtractionInvalid.
  ///
  /// In en, this message translates to:
  /// **'The AI output didn’t fully match the profile. Showing what was extracted.'**
  String get recordingExtractionInvalid;

  /// No description provided for @recordingExports.
  ///
  /// In en, this message translates to:
  /// **'Exports'**
  String get recordingExports;

  /// No description provided for @recordingNoExports.
  ///
  /// In en, this message translates to:
  /// **'Not exported yet.'**
  String get recordingNoExports;

  /// No description provided for @exportStatusWritten.
  ///
  /// In en, this message translates to:
  /// **'Written'**
  String get exportStatusWritten;

  /// No description provided for @exportStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get exportStatusFailed;

  /// No description provided for @exportStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting to be written'**
  String get exportStatusPending;

  /// No description provided for @recordingDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this recording?'**
  String get recordingDeleteTitle;

  /// No description provided for @recordingDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'The audio, transcript and extracted data are removed from this device. This can’t be undone.'**
  String get recordingDeleteBody;

  /// No description provided for @recordingDeleteNotes.
  ///
  /// In en, this message translates to:
  /// **'Also delete the exported note from {folders}'**
  String recordingDeleteNotes(String folders);

  /// No description provided for @recordingDeleted.
  ///
  /// In en, this message translates to:
  /// **'Recording deleted.'**
  String get recordingDeleted;

  /// No description provided for @recordingDeletedNotesKept.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Recording deleted. 1 exported note couldn’t be removed — delete it in your vault.} other{Recording deleted. {count} exported notes couldn’t be removed — delete them in your vault.}}'**
  String recordingDeletedNotesKept(int count);

  /// No description provided for @recordingDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t delete the recording.'**
  String get recordingDeleteFailed;

  /// No description provided for @actionItemsTitle.
  ///
  /// In en, this message translates to:
  /// **'Action items'**
  String get actionItemsTitle;

  /// No description provided for @actionItemsOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get actionItemsOpen;

  /// No description provided for @actionItemsAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get actionItemsAll;

  /// No description provided for @actionItemsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load action items.'**
  String get actionItemsLoadFailed;

  /// No description provided for @actionItemsNoneOpen.
  ///
  /// In en, this message translates to:
  /// **'No open action items.'**
  String get actionItemsNoneOpen;

  /// No description provided for @actionItemsNone.
  ///
  /// In en, this message translates to:
  /// **'No action items yet.'**
  String get actionItemsNone;

  /// No description provided for @actionItemUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t update the action item.'**
  String get actionItemUpdateFailed;

  /// No description provided for @actionItemOpenRecording.
  ///
  /// In en, this message translates to:
  /// **'Open recording'**
  String get actionItemOpenRecording;

  /// No description provided for @reviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review before export'**
  String get reviewTitle;

  /// No description provided for @reviewTabEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get reviewTabEdit;

  /// No description provided for @reviewTabPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get reviewTabPreview;

  /// No description provided for @reviewIntro.
  ///
  /// In en, this message translates to:
  /// **'Check what {profile} extracted. Fix names, tasks, owners and dates, then export the note.'**
  String reviewIntro(String profile);

  /// No description provided for @reviewExport.
  ///
  /// In en, this message translates to:
  /// **'Export note'**
  String get reviewExport;

  /// No description provided for @reviewExported.
  ///
  /// In en, this message translates to:
  /// **'Saved. The note is being exported.'**
  String get reviewExported;

  /// No description provided for @reviewFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t save your changes. Try again.'**
  String get reviewFailed;

  /// No description provided for @reviewInvalid.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 field doesn’t match the profile (too long, missing or wrong type).} other{{count} fields don’t match the profile (too long, missing or wrong type).}}'**
  String reviewInvalid(int count);

  /// No description provided for @reviewNumberInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number.'**
  String get reviewNumberInvalid;

  /// No description provided for @reviewPreviewFailed.
  ///
  /// In en, this message translates to:
  /// **'The preview couldn’t be rendered.'**
  String get reviewPreviewFailed;

  /// No description provided for @reviewProfileMissing.
  ///
  /// In en, this message translates to:
  /// **'The profile of this result no longer exists, so it can’t be edited.'**
  String get reviewProfileMissing;

  /// No description provided for @reviewFieldNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get reviewFieldNone;

  /// No description provided for @reviewFieldSource.
  ///
  /// In en, this message translates to:
  /// **'Said at (hh:mm:ss)'**
  String get reviewFieldSource;

  /// No description provided for @reviewPlayFrom.
  ///
  /// In en, this message translates to:
  /// **'Show in transcript at {time}'**
  String reviewPlayFrom(String time);

  /// No description provided for @reviewRemoveItem.
  ///
  /// In en, this message translates to:
  /// **'Remove from {field}'**
  String reviewRemoveItem(String field);

  /// No description provided for @reviewAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add to {field}'**
  String reviewAddItem(String field);

  /// No description provided for @reviewSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Review before export'**
  String get reviewSettingsTitle;

  /// No description provided for @reviewSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check extracted results before notes are written'**
  String get reviewSettingsSubtitle;

  /// No description provided for @reviewSettingsIntro.
  ///
  /// In en, this message translates to:
  /// **'Small on-device models make mistakes. For profiles set to review, results wait for you to check and edit them before the note is written to your vault.'**
  String get reviewSettingsIntro;

  /// No description provided for @reviewSettingsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load the profiles.'**
  String get reviewSettingsLoadFailed;

  /// No description provided for @reviewModeReview.
  ///
  /// In en, this message translates to:
  /// **'Review first'**
  String get reviewModeReview;

  /// No description provided for @reviewModeAuto.
  ///
  /// In en, this message translates to:
  /// **'Export automatically'**
  String get reviewModeAuto;

  /// No description provided for @reviewBanner.
  ///
  /// In en, this message translates to:
  /// **'The result is waiting for your review.'**
  String get reviewBanner;

  /// No description provided for @reviewOpen.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get reviewOpen;

  /// No description provided for @reviewEditResult.
  ///
  /// In en, this message translates to:
  /// **'Review & edit result'**
  String get reviewEditResult;

  /// No description provided for @recordingDebugTooltip.
  ///
  /// In en, this message translates to:
  /// **'Recording debug'**
  String get recordingDebugTooltip;

  /// No description provided for @importAudioTooltip.
  ///
  /// In en, this message translates to:
  /// **'Import audio file'**
  String get importAudioTooltip;

  /// No description provided for @importAttestationTitle.
  ///
  /// In en, this message translates to:
  /// **'Import a recording'**
  String get importAttestationTitle;

  /// No description provided for @importAttestationBody.
  ///
  /// In en, this message translates to:
  /// **'The audio is processed on this device only. Import only recordings you are allowed to use.'**
  String get importAttestationBody;

  /// No description provided for @importAttestationCheckbox.
  ///
  /// In en, this message translates to:
  /// **'I have the right to process this recording and everyone in it consented to being recorded.'**
  String get importAttestationCheckbox;

  /// No description provided for @importAction.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importAction;

  /// No description provided for @importInProgress.
  ///
  /// In en, this message translates to:
  /// **'Importing audio…'**
  String get importInProgress;

  /// No description provided for @importDone.
  ///
  /// In en, this message translates to:
  /// **'Imported. Processing has been queued.'**
  String get importDone;

  /// No description provided for @importUnsupportedFormat.
  ///
  /// In en, this message translates to:
  /// **'{format} files can’t be imported on this device.'**
  String importUnsupportedFormat(String format);

  /// No description provided for @importUnsupportedUnknown.
  ///
  /// In en, this message translates to:
  /// **'This file type can’t be imported on this device.'**
  String get importUnsupportedUnknown;

  /// No description provided for @importNoAudio.
  ///
  /// In en, this message translates to:
  /// **'This file contains no audio.'**
  String get importNoAudio;

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'The file could not be imported.'**
  String get importFailed;

  /// No description provided for @recordStart.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get recordStart;

  /// No description provided for @recordPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get recordPause;

  /// No description provided for @recordResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get recordResume;

  /// No description provided for @recordStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get recordStop;

  /// No description provided for @recordMarker.
  ///
  /// In en, this message translates to:
  /// **'Mark'**
  String get recordMarker;

  /// No description provided for @recordMarkerAdded.
  ///
  /// In en, this message translates to:
  /// **'Moment marked'**
  String get recordMarkerAdded;

  /// No description provided for @recordStateIdle.
  ///
  /// In en, this message translates to:
  /// **'Ready to record'**
  String get recordStateIdle;

  /// No description provided for @recordStateRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get recordStateRecording;

  /// No description provided for @recordStatePaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get recordStatePaused;

  /// No description provided for @recordPausedCall.
  ///
  /// In en, this message translates to:
  /// **'Paused because a call started. Audio from the call was not recorded. Tap Resume to continue.'**
  String get recordPausedCall;

  /// No description provided for @recordPausedInterruption.
  ///
  /// In en, this message translates to:
  /// **'Paused: another app or the system took the microphone. Tap Resume to continue.'**
  String get recordPausedInterruption;

  /// No description provided for @recordPausedError.
  ///
  /// In en, this message translates to:
  /// **'Paused: the microphone stopped. Tap Resume to continue.'**
  String get recordPausedError;

  /// No description provided for @recordUnavailableDuringCalls.
  ///
  /// In en, this message translates to:
  /// **'Recording is unavailable during calls'**
  String get recordUnavailableDuringCalls;

  /// No description provided for @recordCallStateUnknown.
  ///
  /// In en, this message translates to:
  /// **'Recording is unavailable: the call state could not be checked.'**
  String get recordCallStateUnknown;

  /// No description provided for @recordPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone access is off. Allow it in the system settings to record.'**
  String get recordPermissionDenied;

  /// No description provided for @recordLowStorage.
  ///
  /// In en, this message translates to:
  /// **'Not enough free space to record.'**
  String get recordLowStorage;

  /// No description provided for @recordLowStorageWarning.
  ///
  /// In en, this message translates to:
  /// **'Storage is almost full.'**
  String get recordLowStorageWarning;

  /// No description provided for @recordStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Recording could not start.'**
  String get recordStartFailed;

  /// No description provided for @recordProfileLabel.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get recordProfileLabel;

  /// No description provided for @recordDestinationLabel.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get recordDestinationLabel;

  /// No description provided for @recordAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get recordAuto;

  /// No description provided for @recordButtonStartLabel.
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get recordButtonStartLabel;

  /// No description provided for @recordButtonPauseLabel.
  ///
  /// In en, this message translates to:
  /// **'Pause recording'**
  String get recordButtonPauseLabel;

  /// No description provided for @recordButtonResumeLabel.
  ///
  /// In en, this message translates to:
  /// **'Resume recording'**
  String get recordButtonResumeLabel;

  /// No description provided for @recordButtonStopLabel.
  ///
  /// In en, this message translates to:
  /// **'Stop and save recording'**
  String get recordButtonStopLabel;

  /// No description provided for @recordTimerLabel.
  ///
  /// In en, this message translates to:
  /// **'{elapsed} recorded'**
  String recordTimerLabel(String elapsed);

  /// No description provided for @consentTitle.
  ///
  /// In en, this message translates to:
  /// **'Recording consent'**
  String get consentTitle;

  /// No description provided for @consentBody.
  ///
  /// In en, this message translates to:
  /// **'This profile requires that everyone present agrees to be recorded before recording starts.'**
  String get consentBody;

  /// No description provided for @consentConfirm.
  ///
  /// In en, this message translates to:
  /// **'Everyone present agrees'**
  String get consentConfirm;

  /// No description provided for @consentOptionalBody.
  ///
  /// In en, this message translates to:
  /// **'Several people may be recorded. Confirm that everyone present knows and agrees, or record without confirming.'**
  String get consentOptionalBody;

  /// No description provided for @consentSkip.
  ///
  /// In en, this message translates to:
  /// **'Record without confirming'**
  String get consentSkip;

  /// No description provided for @consentFirstRunTitle.
  ///
  /// In en, this message translates to:
  /// **'Before your first recording'**
  String get consentFirstRunTitle;

  /// No description provided for @consentFirstRunConfirm.
  ///
  /// In en, this message translates to:
  /// **'I understand'**
  String get consentFirstRunConfirm;

  /// No description provided for @detailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recording saved'**
  String get detailsTitle;

  /// No description provided for @detailsTitleField.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get detailsTitleField;

  /// No description provided for @detailsTagsField.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get detailsTagsField;

  /// No description provided for @detailsTagsHint.
  ///
  /// In en, this message translates to:
  /// **'Separate tags with commas'**
  String get detailsTagsHint;

  /// No description provided for @detailsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get detailsSave;

  /// No description provided for @detailsSkip.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get detailsSkip;

  /// No description provided for @recordStoppedSilence.
  ///
  /// In en, this message translates to:
  /// **'Stopped after silence.'**
  String get recordStoppedSilence;

  /// No description provided for @recordStoppedMax.
  ///
  /// In en, this message translates to:
  /// **'Stopped at the maximum recording length.'**
  String get recordStoppedMax;

  /// No description provided for @recordStoppedStorage.
  ///
  /// In en, this message translates to:
  /// **'Stopped because storage is almost full.'**
  String get recordStoppedStorage;

  /// No description provided for @detailsQueued.
  ///
  /// In en, this message translates to:
  /// **'Processing has been queued.'**
  String get detailsQueued;

  /// No description provided for @detailsProcessNow.
  ///
  /// In en, this message translates to:
  /// **'Process now'**
  String get detailsProcessNow;

  /// No description provided for @diagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Export diagnostics'**
  String get diagnosticsTitle;

  /// No description provided for @diagnosticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Logs, device info and performance metrics. No recordings, transcripts or notes.'**
  String get diagnosticsSubtitle;

  /// No description provided for @diagnosticsShareUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Sharing is not available.'**
  String get diagnosticsShareUnavailable;

  /// No description provided for @diagnosticsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not export diagnostics.'**
  String get diagnosticsFailed;

  /// No description provided for @diagnosticsPreviewSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file} other{{count} files}}, {size}. Nothing leaves this device unless you choose a destination in the share sheet.'**
  String diagnosticsPreviewSummary(int count, String size);

  /// No description provided for @diagnosticsShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get diagnosticsShare;

  /// No description provided for @notificationReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your note is ready'**
  String get notificationReadyTitle;

  /// No description provided for @notificationReadyBody.
  ///
  /// In en, this message translates to:
  /// **'Tap to open it.'**
  String get notificationReadyBody;

  /// No description provided for @notificationReadyTitleWithRecording.
  ///
  /// In en, this message translates to:
  /// **'Note ready — {title}'**
  String notificationReadyTitleWithRecording(String title);

  /// No description provided for @notificationFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Processing needs attention'**
  String get notificationFailedTitle;

  /// No description provided for @notificationFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Tap to see what happened.'**
  String get notificationFailedBody;

  /// No description provided for @notificationFailedTitleWithRecording.
  ///
  /// In en, this message translates to:
  /// **'Processing failed — {title}'**
  String notificationFailedTitleWithRecording(String title);

  /// No description provided for @notificationChannelProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get notificationChannelProcessing;

  /// Ongoing (foreground service) notification while a recording is transcribed or extracted. Generic: never shows content.
  ///
  /// In en, this message translates to:
  /// **'Processing your recording'**
  String get notificationProcessingOngoingTitle;

  /// Body of the ongoing processing notification.
  ///
  /// In en, this message translates to:
  /// **'Transcription runs on this device.'**
  String get notificationProcessingOngoingBody;

  /// No description provided for @jobQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get jobQueued;

  /// No description provided for @jobTranscribing.
  ///
  /// In en, this message translates to:
  /// **'Transcribing'**
  String get jobTranscribing;

  /// No description provided for @jobDiarizing.
  ///
  /// In en, this message translates to:
  /// **'Identifying speakers'**
  String get jobDiarizing;

  /// No description provided for @jobClassifying.
  ///
  /// In en, this message translates to:
  /// **'Choosing a profile'**
  String get jobClassifying;

  /// No description provided for @jobExtracting.
  ///
  /// In en, this message translates to:
  /// **'Extracting details'**
  String get jobExtracting;

  /// No description provided for @jobRendering.
  ///
  /// In en, this message translates to:
  /// **'Formatting the note'**
  String get jobRendering;

  /// No description provided for @jobWriting.
  ///
  /// In en, this message translates to:
  /// **'Saving to your vault'**
  String get jobWriting;

  /// No description provided for @jobBetweenSteps.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the next step'**
  String get jobBetweenSteps;

  /// No description provided for @jobDone.
  ///
  /// In en, this message translates to:
  /// **'Note ready'**
  String get jobDone;

  /// No description provided for @jobFailedPermanent.
  ///
  /// In en, this message translates to:
  /// **'Processing failed'**
  String get jobFailedPermanent;

  /// No description provided for @jobFailedRetryable.
  ///
  /// In en, this message translates to:
  /// **'Processing failed — you can retry'**
  String get jobFailedRetryable;

  /// No description provided for @jobCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get jobCancelled;

  /// No description provided for @jobPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get jobPaused;

  /// No description provided for @jobWaitingModel.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a model download'**
  String get jobWaitingModel;

  /// No description provided for @jobWaitingProfile.
  ///
  /// In en, this message translates to:
  /// **'Choose a profile to continue'**
  String get jobWaitingProfile;

  /// No description provided for @jobWaitingReview.
  ///
  /// In en, this message translates to:
  /// **'Ready for your review'**
  String get jobWaitingReview;

  /// No description provided for @jobWaitingDestination.
  ///
  /// In en, this message translates to:
  /// **'Needs access to your vault folder'**
  String get jobWaitingDestination;

  /// No description provided for @jobWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get jobWaiting;

  /// No description provided for @etaEstimating.
  ///
  /// In en, this message translates to:
  /// **'Estimating time…'**
  String get etaEstimating;

  /// No description provided for @etaUnderMinute.
  ///
  /// In en, this message translates to:
  /// **'Less than a minute left'**
  String get etaUnderMinute;

  /// No description provided for @etaMinutes.
  ///
  /// In en, this message translates to:
  /// **'About {minutes} min left'**
  String etaMinutes(int minutes);

  /// No description provided for @etaHours.
  ///
  /// In en, this message translates to:
  /// **'About {hours} h left'**
  String etaHours(int hours);

  /// No description provided for @etaHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'About {hours} h {minutes} min left'**
  String etaHoursMinutes(int hours, int minutes);

  /// No description provided for @jobPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String jobPercent(int percent);

  /// No description provided for @jobQueuePosition.
  ///
  /// In en, this message translates to:
  /// **'Position {position} in queue'**
  String jobQueuePosition(int position);

  /// No description provided for @jobProgressSemantics.
  ///
  /// In en, this message translates to:
  /// **'{status}, {percent} percent'**
  String jobProgressSemantics(String status, int percent);

  /// No description provided for @untitledRecording.
  ///
  /// In en, this message translates to:
  /// **'Untitled recording'**
  String get untitledRecording;

  /// No description provided for @jobProcessNow.
  ///
  /// In en, this message translates to:
  /// **'Process now'**
  String get jobProcessNow;

  /// No description provided for @jobCommandFailed.
  ///
  /// In en, this message translates to:
  /// **'That did not work. Please try again.'**
  String get jobCommandFailed;

  /// No description provided for @processingTitle.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get processingTitle;

  /// No description provided for @processingStatusLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the processing status.'**
  String get processingStatusLoadFailed;

  /// No description provided for @processingNotProcessed.
  ///
  /// In en, this message translates to:
  /// **'This recording has not been processed yet.'**
  String get processingNotProcessed;

  /// No description provided for @processingQueueTitle.
  ///
  /// In en, this message translates to:
  /// **'Processing queue'**
  String get processingQueueTitle;

  /// No description provided for @processingQueueLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the processing queue.'**
  String get processingQueueLoadFailed;

  /// No description provided for @processingQueueEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing is being processed right now.'**
  String get processingQueueEmpty;

  /// No description provided for @queueProcessing.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Processing 1 recording} other{Processing {count} recordings}}'**
  String queueProcessing(int count);

  /// No description provided for @queueNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 needs attention} other{{count} need attention}}'**
  String queueNeedsAttention(int count);

  /// No description provided for @queueIndicatorSemantics.
  ///
  /// In en, this message translates to:
  /// **'{summary}. Open processing queue'**
  String queueIndicatorSemantics(String summary);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @sectionAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get sectionAudio;

  /// No description provided for @sectionProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get sectionProcessing;

  /// No description provided for @sectionExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get sectionExport;

  /// No description provided for @sectionPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy & security'**
  String get sectionPrivacy;

  /// No description provided for @sectionLicense.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get sectionLicense;

  /// No description provided for @sectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get sectionAbout;

  /// No description provided for @settingInputDevice.
  ///
  /// In en, this message translates to:
  /// **'Input device'**
  String get settingInputDevice;

  /// No description provided for @settingAgc.
  ///
  /// In en, this message translates to:
  /// **'Automatic gain control'**
  String get settingAgc;

  /// No description provided for @settingAgcDescription.
  ///
  /// In en, this message translates to:
  /// **'Evens out quiet and loud voices.'**
  String get settingAgcDescription;

  /// No description provided for @settingNoiseSuppression.
  ///
  /// In en, this message translates to:
  /// **'Noise suppression'**
  String get settingNoiseSuppression;

  /// No description provided for @settingSoftwareAgc.
  ///
  /// In en, this message translates to:
  /// **'App gain control'**
  String get settingSoftwareAgc;

  /// No description provided for @settingSoftwareAgcDescription.
  ///
  /// In en, this message translates to:
  /// **'Use VaultVoice’s own gain control instead of the phone’s. Used automatically when the phone has none.'**
  String get settingSoftwareAgcDescription;

  /// No description provided for @settingRawCapture.
  ///
  /// In en, this message translates to:
  /// **'Raw capture'**
  String get settingRawCapture;

  /// No description provided for @settingRawCaptureDescription.
  ///
  /// In en, this message translates to:
  /// **'Turns off all audio processing. For external microphones and testing.'**
  String get settingRawCaptureDescription;

  /// No description provided for @clippingHint.
  ///
  /// In en, this message translates to:
  /// **'Too loud — move the phone further away.'**
  String get clippingHint;

  /// No description provided for @recordingLevelLabel.
  ///
  /// In en, this message translates to:
  /// **'Input level'**
  String get recordingLevelLabel;

  /// No description provided for @settingAutoPause.
  ///
  /// In en, this message translates to:
  /// **'Auto-pause on silence'**
  String get settingAutoPause;

  /// No description provided for @settingAutoPauseDescription.
  ///
  /// In en, this message translates to:
  /// **'Pauses after 2 minutes of silence. Tap Resume to continue. Needs the voice detection model.'**
  String get settingAutoPauseDescription;

  /// No description provided for @settingSilenceAutoStop.
  ///
  /// In en, this message translates to:
  /// **'Stop after silence'**
  String get settingSilenceAutoStop;

  /// No description provided for @settingSilenceAutoStopDescription.
  ///
  /// In en, this message translates to:
  /// **'Ends the recording after this much silence. Needs the voice detection model.'**
  String get settingSilenceAutoStopDescription;

  /// No description provided for @settingSkipSilence.
  ///
  /// In en, this message translates to:
  /// **'Skip silence'**
  String get settingSkipSilence;

  /// No description provided for @settingSkipSilenceDescription.
  ///
  /// In en, this message translates to:
  /// **'Transcribes only the parts with speech: faster, and no text invented in silence.'**
  String get settingSkipSilenceDescription;

  /// No description provided for @optionOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get optionOff;

  /// No description provided for @settingAudioRetention.
  ///
  /// In en, this message translates to:
  /// **'Keep audio'**
  String get settingAudioRetention;

  /// No description provided for @settingAutoProcess.
  ///
  /// In en, this message translates to:
  /// **'Process after recording'**
  String get settingAutoProcess;

  /// No description provided for @settingAutoProcessDescription.
  ///
  /// In en, this message translates to:
  /// **'Transcribe and extract as soon as a recording ends.'**
  String get settingAutoProcessDescription;

  /// No description provided for @settingChargeOnly.
  ///
  /// In en, this message translates to:
  /// **'Process only while charging'**
  String get settingChargeOnly;

  /// No description provided for @settingChargeOnlyDescription.
  ///
  /// In en, this message translates to:
  /// **'Wait for a charger before heavy processing.'**
  String get settingChargeOnlyDescription;

  /// No description provided for @settingDiarization.
  ///
  /// In en, this message translates to:
  /// **'Label speakers by default'**
  String get settingDiarization;

  /// No description provided for @settingDiarizationDescription.
  ///
  /// In en, this message translates to:
  /// **'Profiles can still turn speaker labels on or off.'**
  String get settingDiarizationDescription;

  /// No description provided for @settingFilenamePattern.
  ///
  /// In en, this message translates to:
  /// **'File name pattern'**
  String get settingFilenamePattern;

  /// No description provided for @settingCollisionMode.
  ///
  /// In en, this message translates to:
  /// **'If the file already exists'**
  String get settingCollisionMode;

  /// No description provided for @settingAppLock.
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get settingAppLock;

  /// No description provided for @settingAppLockDescription.
  ///
  /// In en, this message translates to:
  /// **'Face ID, fingerprint or device passcode.'**
  String get settingAppLockDescription;

  /// No description provided for @settingLockTimeout.
  ///
  /// In en, this message translates to:
  /// **'Lock after'**
  String get settingLockTimeout;

  /// No description provided for @settingTranscriptRetention.
  ///
  /// In en, this message translates to:
  /// **'Keep transcripts and notes'**
  String get settingTranscriptRetention;

  /// No description provided for @settingOfflineMode.
  ///
  /// In en, this message translates to:
  /// **'Offline mode'**
  String get settingOfflineMode;

  /// No description provided for @settingOfflineModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Turns off all network use. Models must already be installed.'**
  String get settingOfflineModeDescription;

  /// No description provided for @networkActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Network activity'**
  String get networkActivityTitle;

  /// No description provided for @networkActivitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Every connection this app made. Only model downloads are allowed.'**
  String get networkActivitySubtitle;

  /// No description provided for @networkActivityEmpty.
  ///
  /// In en, this message translates to:
  /// **'No network requests yet.'**
  String get networkActivityEmpty;

  /// No description provided for @networkActivityClear.
  ///
  /// In en, this message translates to:
  /// **'Clear log'**
  String get networkActivityClear;

  /// No description provided for @networkActivityCompleted.
  ///
  /// In en, this message translates to:
  /// **'HTTP {status}'**
  String networkActivityCompleted(String status);

  /// No description provided for @networkActivityDenied.
  ///
  /// In en, this message translates to:
  /// **'Blocked before sending'**
  String get networkActivityDenied;

  /// No description provided for @networkActivityFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get networkActivityFailed;

  /// No description provided for @networkActivitySystem.
  ///
  /// In en, this message translates to:
  /// **'Handed to system download'**
  String get networkActivitySystem;

  /// No description provided for @networkActivityBytes.
  ///
  /// In en, this message translates to:
  /// **'{size} bytes'**
  String networkActivityBytes(String size);

  /// No description provided for @settingNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingNotifications;

  /// No description provided for @settingNotificationsDescription.
  ///
  /// In en, this message translates to:
  /// **'When a note is ready or processing needs attention.'**
  String get settingNotificationsDescription;

  /// No description provided for @settingNotificationDetails.
  ///
  /// In en, this message translates to:
  /// **'Show details in notifications'**
  String get settingNotificationDetails;

  /// No description provided for @settingNotificationDetailsDescription.
  ///
  /// In en, this message translates to:
  /// **'Include the recording title. Off: generic text on the lock screen.'**
  String get settingNotificationDetailsDescription;

  /// No description provided for @optionSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get optionSystemDefault;

  /// No description provided for @optionBuiltInMic.
  ///
  /// In en, this message translates to:
  /// **'Built-in microphone'**
  String get optionBuiltInMic;

  /// No description provided for @optionWiredHeadset.
  ///
  /// In en, this message translates to:
  /// **'Wired headset'**
  String get optionWiredHeadset;

  /// No description provided for @optionBluetoothHeadset.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth headset'**
  String get optionBluetoothHeadset;

  /// No description provided for @optionKeepForever.
  ///
  /// In en, this message translates to:
  /// **'Until I delete it'**
  String get optionKeepForever;

  /// No description provided for @optionDeleteAfterExport.
  ///
  /// In en, this message translates to:
  /// **'Delete after export'**
  String get optionDeleteAfterExport;

  /// No description provided for @optionDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String optionDays(int days);

  /// No description provided for @optionCollisionSuffix.
  ///
  /// In en, this message translates to:
  /// **'Add a number (-2, -3 …)'**
  String get optionCollisionSuffix;

  /// No description provided for @optionCollisionOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Replace my earlier export'**
  String get optionCollisionOverwrite;

  /// No description provided for @optionCollisionSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get optionCollisionSkip;

  /// No description provided for @optionImmediately.
  ///
  /// In en, this message translates to:
  /// **'Immediately'**
  String get optionImmediately;

  /// No description provided for @optionMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute} other{{count} minutes}}'**
  String optionMinutes(int count);

  /// No description provided for @patternErrorEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter a pattern.'**
  String get patternErrorEmpty;

  /// No description provided for @patternErrorTooLong.
  ///
  /// In en, this message translates to:
  /// **'Use at most 200 characters.'**
  String get patternErrorTooLong;

  /// No description provided for @patternErrorUnsafe.
  ///
  /// In en, this message translates to:
  /// **'Folders must stay inside the vault.'**
  String get patternErrorUnsafe;

  /// No description provided for @patternErrorUnbalanced.
  ///
  /// In en, this message translates to:
  /// **'Every \'{{\' needs a matching \'}}\'.'**
  String get patternErrorUnbalanced;

  /// No description provided for @patternErrorInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid pattern.'**
  String get patternErrorInvalid;

  /// No description provided for @settingManaged.
  ///
  /// In en, this message translates to:
  /// **'Managed by your organization'**
  String get settingManaged;

  /// No description provided for @settingSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the setting.'**
  String get settingSaveFailed;

  /// No description provided for @settingsModels.
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get settingsModels;

  /// No description provided for @settingsModelsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Speech and language models on this device'**
  String get settingsModelsSubtitle;

  /// No description provided for @settingsVaultFolders.
  ///
  /// In en, this message translates to:
  /// **'Vault folders'**
  String get settingsVaultFolders;

  /// No description provided for @settingsVaultFoldersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{The app’s own folder} =1{1 folder} other{{count} folders}}'**
  String settingsVaultFoldersCount(int count);

  /// No description provided for @settingsRoutingRules.
  ///
  /// In en, this message translates to:
  /// **'Routing rules'**
  String get settingsRoutingRules;

  /// No description provided for @settingsRoutingRulesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{None} =1{1 rule} other{{count} rules}}'**
  String settingsRoutingRulesCount(int count);

  /// No description provided for @encryptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Encryption'**
  String get encryptionTitle;

  /// No description provided for @encryptionOn.
  ///
  /// In en, this message translates to:
  /// **'On — the database is encrypted with a key kept in this device’s secure key store.'**
  String get encryptionOn;

  /// No description provided for @encryptionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable — the encryption key could not be read, so your data stays locked. Restart the app.'**
  String get encryptionUnavailable;

  /// No description provided for @encryptionOff.
  ///
  /// In en, this message translates to:
  /// **'Off — this build does not encrypt the database.'**
  String get encryptionOff;

  /// No description provided for @encryptionDetails.
  ///
  /// In en, this message translates to:
  /// **'{status}\n\nAudio files are protected by the device’s file encryption, and app data is never included in cloud backups. Recordings, transcripts and notes never leave this device unless you export or share them. Notes exported to a vault folder are plain Markdown files, readable by any app with access to that folder.'**
  String encryptionDetails(String status);

  /// No description provided for @appLockTitle.
  ///
  /// In en, this message translates to:
  /// **'{appName} is locked'**
  String appLockTitle(String appName);

  /// No description provided for @appLockBody.
  ///
  /// In en, this message translates to:
  /// **'Unlock to see your recordings, transcripts and notes.'**
  String get appLockBody;

  /// No description provided for @appLockUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This device has no passcode or biometrics set up, so the app cannot be locked. Set a device passcode to use the app lock.'**
  String get appLockUnavailable;

  /// No description provided for @appLockReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock to see your recordings and notes'**
  String get appLockReason;

  /// No description provided for @appLockUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get appLockUnlock;

  /// No description provided for @appLockRecord.
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get appLockRecord;

  /// No description provided for @appLockRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording. Your recordings and notes stay hidden until you unlock.'**
  String get appLockRecording;

  /// No description provided for @appLockStop.
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get appLockStop;

  /// No description provided for @deleteAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all data'**
  String get deleteAllTitle;

  /// No description provided for @deleteAllConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all data?'**
  String get deleteAllConfirmTitle;

  /// No description provided for @deleteAllConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Deletes every recording, transcript, note, profile and setting on this device. Notes already exported to your vault folders are kept. This cannot be undone.'**
  String get deleteAllConfirmBody;

  /// No description provided for @deleteAllConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete everything'**
  String get deleteAllConfirm;

  /// No description provided for @deleteAllDone.
  ///
  /// In en, this message translates to:
  /// **'All data deleted.'**
  String get deleteAllDone;

  /// No description provided for @deleteAllUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Deleting all data is not available in this build yet.'**
  String get deleteAllUnavailable;

  /// No description provided for @deleteAllFailed.
  ///
  /// In en, this message translates to:
  /// **'Some data could not be deleted. Close any recording or processing in progress and try again.'**
  String get deleteAllFailed;

  /// No description provided for @licensePlanFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get licensePlanFree;

  /// No description provided for @licensePlanPro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get licensePlanPro;

  /// No description provided for @licensePlanEnterprise.
  ///
  /// In en, this message translates to:
  /// **'Enterprise'**
  String get licensePlanEnterprise;

  /// No description provided for @licenseUntil.
  ///
  /// In en, this message translates to:
  /// **'until {date}'**
  String licenseUntil(String date);

  /// No description provided for @licenseGrace.
  ///
  /// In en, this message translates to:
  /// **'offline grace period'**
  String get licenseGrace;

  /// No description provided for @licenseStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get licenseStatus;

  /// No description provided for @licenseRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get licenseRestore;

  /// No description provided for @licenseRestored.
  ///
  /// In en, this message translates to:
  /// **'Purchases restored.'**
  String get licenseRestored;

  /// No description provided for @licenseEnterpriseEnter.
  ///
  /// In en, this message translates to:
  /// **'Enter enterprise license'**
  String get licenseEnterpriseEnter;

  /// No description provided for @licenseEnterpriseTitle.
  ///
  /// In en, this message translates to:
  /// **'Enterprise license'**
  String get licenseEnterpriseTitle;

  /// No description provided for @licenseEnterpriseHint.
  ///
  /// In en, this message translates to:
  /// **'Paste the license from your administrator'**
  String get licenseEnterpriseHint;

  /// No description provided for @licenseEnterpriseInstall.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get licenseEnterpriseInstall;

  /// No description provided for @licenseEnterpriseInstalled.
  ///
  /// In en, this message translates to:
  /// **'Enterprise license installed.'**
  String get licenseEnterpriseInstalled;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get aboutVersion;

  /// No description provided for @aboutPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get aboutPrivacyPolicy;

  /// No description provided for @privacyPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicyTitle;

  /// No description provided for @privacyPolicyLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'The privacy policy could not be shown.'**
  String get privacyPolicyLoadFailed;

  /// No description provided for @aboutLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source & model licenses'**
  String get aboutLicenses;

  /// No description provided for @vaultFoldersAdd.
  ///
  /// In en, this message translates to:
  /// **'Add folder'**
  String get vaultFoldersAdd;

  /// No description provided for @vaultFoldersAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not add the folder.'**
  String get vaultFoldersAddFailed;

  /// No description provided for @vaultFolderDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Vault folder'**
  String get vaultFolderDefaultName;

  /// No description provided for @vaultFoldersRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this folder?'**
  String get vaultFoldersRemoveTitle;

  /// No description provided for @vaultFoldersRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'Notes already written stay in the folder. Routing rules that use it are removed too.'**
  String get vaultFoldersRemoveBody;

  /// No description provided for @vaultFoldersRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get vaultFoldersRemove;

  /// No description provided for @vaultFoldersRemoveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String vaultFoldersRemoveTooltip(String name);

  /// No description provided for @vaultFoldersLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load your vault folders.'**
  String get vaultFoldersLoadFailed;

  /// No description provided for @vaultFoldersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No vault folders yet. Notes are saved in the app’s own folder until you add one.'**
  String get vaultFoldersEmpty;

  /// No description provided for @routingRulesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load routing rules.'**
  String get routingRulesLoadFailed;

  /// No description provided for @routingRulesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No routing rules. Every note goes to your first vault folder.'**
  String get routingRulesEmpty;

  /// No description provided for @profilesBuiltinSection.
  ///
  /// In en, this message translates to:
  /// **'Built-in profiles'**
  String get profilesBuiltinSection;

  /// No description provided for @profilesCustomSection.
  ///
  /// In en, this message translates to:
  /// **'Your profiles'**
  String get profilesCustomSection;

  /// No description provided for @profilesCustomEmpty.
  ///
  /// In en, this message translates to:
  /// **'No custom profiles yet. Create one or duplicate a built-in profile.'**
  String get profilesCustomEmpty;

  /// No description provided for @profilesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load profiles.'**
  String get profilesLoadFailed;

  /// No description provided for @profilesNew.
  ///
  /// In en, this message translates to:
  /// **'New profile'**
  String get profilesNew;

  /// No description provided for @profilesDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate {name}'**
  String profilesDuplicate(String name);

  /// No description provided for @profilesCopyName.
  ///
  /// In en, this message translates to:
  /// **'{name} (copy)'**
  String profilesCopyName(String name);

  /// No description provided for @profilesProOnly.
  ///
  /// In en, this message translates to:
  /// **'Custom profiles are a Pro feature.'**
  String get profilesProOnly;

  /// No description provided for @profilesReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Read-only'**
  String get profilesReadOnly;

  /// No description provided for @profilesManaged.
  ///
  /// In en, this message translates to:
  /// **'Managed by your organization'**
  String get profilesManaged;

  /// No description provided for @profileEditorNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New profile'**
  String get profileEditorNewTitle;

  /// No description provided for @profileEditorEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get profileEditorEditTitle;

  /// No description provided for @profileEditorViewTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileEditorViewTitle;

  /// No description provided for @profileEditorNotFound.
  ///
  /// In en, this message translates to:
  /// **'This profile no longer exists.'**
  String get profileEditorNotFound;

  /// No description provided for @profileEditorReadOnlyBanner.
  ///
  /// In en, this message translates to:
  /// **'This profile is read-only. Duplicate it to make changes.'**
  String get profileEditorReadOnlyBanner;

  /// No description provided for @profileEditorProBanner.
  ///
  /// In en, this message translates to:
  /// **'Editing custom profiles needs Pro. Your profiles keep working.'**
  String get profileEditorProBanner;

  /// No description provided for @profileEditorName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get profileEditorName;

  /// No description provided for @profileEditorDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get profileEditorDescription;

  /// No description provided for @profileEditorInstructions.
  ///
  /// In en, this message translates to:
  /// **'Instructions for the assistant'**
  String get profileEditorInstructions;

  /// No description provided for @profileEditorInstructionsHint.
  ///
  /// In en, this message translates to:
  /// **'Short bullet points, e.g. “Use the speaker’s name as owner.”'**
  String get profileEditorInstructionsHint;

  /// No description provided for @profileEditorSpeakers.
  ///
  /// In en, this message translates to:
  /// **'Several speakers'**
  String get profileEditorSpeakers;

  /// No description provided for @profileEditorSpeakersHint.
  ///
  /// In en, this message translates to:
  /// **'Label who said what (asks for consent before recording)'**
  String get profileEditorSpeakersHint;

  /// No description provided for @profileEditorFields.
  ///
  /// In en, this message translates to:
  /// **'Fields'**
  String get profileEditorFields;

  /// No description provided for @profileEditorAddField.
  ///
  /// In en, this message translates to:
  /// **'Add field'**
  String get profileEditorAddField;

  /// No description provided for @profileEditorFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Field name'**
  String get profileEditorFieldLabel;

  /// No description provided for @profileEditorFieldKey.
  ///
  /// In en, this message translates to:
  /// **'Key: {key}'**
  String profileEditorFieldKey(String key);

  /// No description provided for @profileEditorFieldType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get profileEditorFieldType;

  /// No description provided for @profileEditorFieldDescription.
  ///
  /// In en, this message translates to:
  /// **'What to extract'**
  String get profileEditorFieldDescription;

  /// No description provided for @profileEditorFieldColumns.
  ///
  /// In en, this message translates to:
  /// **'Columns (comma-separated)'**
  String get profileEditorFieldColumns;

  /// No description provided for @profileEditorFieldRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove field {name}'**
  String profileEditorFieldRemove(String name);

  /// No description provided for @profileEditorFieldAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced field, kept as is.'**
  String get profileEditorFieldAdvanced;

  /// No description provided for @profileEditorKindText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get profileEditorKindText;

  /// No description provided for @profileEditorKindLongText.
  ///
  /// In en, this message translates to:
  /// **'Long text'**
  String get profileEditorKindLongText;

  /// No description provided for @profileEditorKindTextList.
  ///
  /// In en, this message translates to:
  /// **'List of text'**
  String get profileEditorKindTextList;

  /// No description provided for @profileEditorKindDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get profileEditorKindDate;

  /// No description provided for @profileEditorKindNumber.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get profileEditorKindNumber;

  /// No description provided for @profileEditorKindBoolean.
  ///
  /// In en, this message translates to:
  /// **'Yes / no'**
  String get profileEditorKindBoolean;

  /// No description provided for @profileEditorKindCheckboxList.
  ///
  /// In en, this message translates to:
  /// **'Checkbox list'**
  String get profileEditorKindCheckboxList;

  /// No description provided for @profileEditorKindTable.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get profileEditorKindTable;

  /// No description provided for @profileEditorKindAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get profileEditorKindAdvanced;

  /// No description provided for @profileEditorExamples.
  ///
  /// In en, this message translates to:
  /// **'Examples (optional)'**
  String get profileEditorExamples;

  /// No description provided for @profileEditorAddExample.
  ///
  /// In en, this message translates to:
  /// **'Add example'**
  String get profileEditorAddExample;

  /// No description provided for @profileEditorExampleTranscript.
  ///
  /// In en, this message translates to:
  /// **'Example transcript'**
  String get profileEditorExampleTranscript;

  /// No description provided for @profileEditorExampleValue.
  ///
  /// In en, this message translates to:
  /// **'Expected {field}'**
  String profileEditorExampleValue(String field);

  /// No description provided for @profileEditorExampleRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove example'**
  String get profileEditorExampleRemove;

  /// No description provided for @profileEditorTarget.
  ///
  /// In en, this message translates to:
  /// **'Save notes to'**
  String get profileEditorTarget;

  /// No description provided for @profileEditorTargetDefault.
  ///
  /// In en, this message translates to:
  /// **'App default'**
  String get profileEditorTargetDefault;

  /// No description provided for @profileEditorTargetAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask every time'**
  String get profileEditorTargetAsk;

  /// No description provided for @profileEditorSave.
  ///
  /// In en, this message translates to:
  /// **'Save profile'**
  String get profileEditorSave;

  /// No description provided for @profileEditorSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved.'**
  String get profileEditorSaved;

  /// No description provided for @profileEditorSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the profile: {reason}'**
  String profileEditorSaveFailed(String reason);

  /// No description provided for @profileEditorDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete profile'**
  String get profileEditorDelete;

  /// No description provided for @profileEditorDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this profile?'**
  String get profileEditorDeleteTitle;

  /// No description provided for @profileEditorDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Notes already exported stay in your vault.'**
  String get profileEditorDeleteBody;

  /// No description provided for @profileEditorCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get profileEditorCancel;

  /// No description provided for @profileEditorIssueName.
  ///
  /// In en, this message translates to:
  /// **'Give the profile a name.'**
  String get profileEditorIssueName;

  /// No description provided for @profileEditorIssueNoFields.
  ///
  /// In en, this message translates to:
  /// **'Add at least one field.'**
  String get profileEditorIssueNoFields;

  /// No description provided for @profileEditorIssueTooManyFields.
  ///
  /// In en, this message translates to:
  /// **'Too many fields (at most 25).'**
  String get profileEditorIssueTooManyFields;

  /// No description provided for @profileEditorIssueFieldName.
  ///
  /// In en, this message translates to:
  /// **'Use a name that starts with a letter.'**
  String get profileEditorIssueFieldName;

  /// No description provided for @profileEditorIssueDuplicateField.
  ///
  /// In en, this message translates to:
  /// **'Another field has the same name.'**
  String get profileEditorIssueDuplicateField;

  /// No description provided for @profileEditorIssueColumns.
  ///
  /// In en, this message translates to:
  /// **'Add 1–8 columns with distinct names.'**
  String get profileEditorIssueColumns;

  /// No description provided for @profileEditorTest.
  ///
  /// In en, this message translates to:
  /// **'Test on a recording'**
  String get profileEditorTest;

  /// No description provided for @profileEditorTestPick.
  ///
  /// In en, this message translates to:
  /// **'Choose a recording'**
  String get profileEditorTestPick;

  /// No description provided for @profileEditorTestNone.
  ///
  /// In en, this message translates to:
  /// **'No transcribed recordings yet.'**
  String get profileEditorTestNone;

  /// No description provided for @profileEditorTestRunning.
  ///
  /// In en, this message translates to:
  /// **'Running the profile on this recording…'**
  String get profileEditorTestRunning;

  /// No description provided for @profileEditorTestFailed.
  ///
  /// In en, this message translates to:
  /// **'The test run failed.'**
  String get profileEditorTestFailed;

  /// No description provided for @profileEditorTestJson.
  ///
  /// In en, this message translates to:
  /// **'Extracted data'**
  String get profileEditorTestJson;

  /// No description provided for @profileEditorTestMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Note preview'**
  String get profileEditorTestMarkdown;

  /// No description provided for @profileEditorTestInvalid.
  ///
  /// In en, this message translates to:
  /// **'The output does not match the fields.'**
  String get profileEditorTestInvalid;

  /// No description provided for @profileEditorTestClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get profileEditorTestClose;

  /// No description provided for @profilesImport.
  ///
  /// In en, this message translates to:
  /// **'Import profile'**
  String get profilesImport;

  /// No description provided for @profilesImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import {name}?'**
  String profilesImportTitle(String name);

  /// No description provided for @profilesImportNew.
  ///
  /// In en, this message translates to:
  /// **'Adds this profile and its note template.'**
  String get profilesImportNew;

  /// No description provided for @profilesImportUpdate.
  ///
  /// In en, this message translates to:
  /// **'Updates version {from} to version {to}.'**
  String profilesImportUpdate(int from, int to);

  /// No description provided for @profilesImportManaged.
  ///
  /// In en, this message translates to:
  /// **'Signed by your organization. It will be read-only.'**
  String get profilesImportManaged;

  /// No description provided for @profilesImportConfirm.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get profilesImportConfirm;

  /// No description provided for @profilesImported.
  ///
  /// In en, this message translates to:
  /// **'Profile imported.'**
  String get profilesImported;

  /// No description provided for @profilesImportInvalid.
  ///
  /// In en, this message translates to:
  /// **'This file is not a valid VaultVoice profile.'**
  String get profilesImportInvalid;

  /// No description provided for @profilesImportUntrusted.
  ///
  /// In en, this message translates to:
  /// **'This profile pack is signed by an unknown organization.'**
  String get profilesImportUntrusted;

  /// No description provided for @profilesImportTampered.
  ///
  /// In en, this message translates to:
  /// **'This profile pack was changed after signing and cannot be imported.'**
  String get profilesImportTampered;

  /// No description provided for @profilesImportIdTaken.
  ///
  /// In en, this message translates to:
  /// **'A different profile with this name is already installed.'**
  String get profilesImportIdTaken;

  /// No description provided for @profilesImportOlder.
  ///
  /// In en, this message translates to:
  /// **'A newer version of this profile is already installed.'**
  String get profilesImportOlder;

  /// No description provided for @profilesImportSame.
  ///
  /// In en, this message translates to:
  /// **'This version is already installed.'**
  String get profilesImportSame;

  /// No description provided for @profilesImportNotEntitled.
  ///
  /// In en, this message translates to:
  /// **'Importing this profile needs a plan that includes it.'**
  String get profilesImportNotEntitled;

  /// No description provided for @profilesImportFailed.
  ///
  /// In en, this message translates to:
  /// **'The import failed.'**
  String get profilesImportFailed;

  /// No description provided for @profileEditorExport.
  ///
  /// In en, this message translates to:
  /// **'Export profile'**
  String get profileEditorExport;

  /// No description provided for @profileEditorExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not export the profile.'**
  String get profileEditorExportFailed;

  /// No description provided for @transcriptTitle.
  ///
  /// In en, this message translates to:
  /// **'Transcript'**
  String get transcriptTitle;

  /// No description provided for @transcriptOpen.
  ///
  /// In en, this message translates to:
  /// **'View and edit transcript'**
  String get transcriptOpen;

  /// No description provided for @transcriptLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the transcript.'**
  String get transcriptLoadFailed;

  /// No description provided for @transcriptEmpty.
  ///
  /// In en, this message translates to:
  /// **'No transcript yet. It appears here when transcription has finished.'**
  String get transcriptEmpty;

  /// No description provided for @transcriptFindReplace.
  ///
  /// In en, this message translates to:
  /// **'Find and replace'**
  String get transcriptFindReplace;

  /// No description provided for @transcriptFind.
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get transcriptFind;

  /// No description provided for @transcriptReplaceWith.
  ///
  /// In en, this message translates to:
  /// **'Replace with'**
  String get transcriptReplaceWith;

  /// No description provided for @transcriptMatchCase.
  ///
  /// In en, this message translates to:
  /// **'Match case'**
  String get transcriptMatchCase;

  /// No description provided for @transcriptMatchCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No matches} =1{1 match} other{{count} matches}}'**
  String transcriptMatchCount(int count);

  /// No description provided for @transcriptReplaceAll.
  ///
  /// In en, this message translates to:
  /// **'Replace all'**
  String get transcriptReplaceAll;

  /// No description provided for @transcriptReplaced.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing to replace.} =1{1 segment changed.} other{{count} segments changed.}}'**
  String transcriptReplaced(int count);

  /// No description provided for @transcriptReExtract.
  ///
  /// In en, this message translates to:
  /// **'Re-extract with edits'**
  String get transcriptReExtract;

  /// No description provided for @transcriptReExtractStarted.
  ///
  /// In en, this message translates to:
  /// **'Extraction restarted with your edited transcript.'**
  String get transcriptReExtractStarted;

  /// No description provided for @transcriptReExtractFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not restart extraction.'**
  String get transcriptReExtractFailed;

  /// No description provided for @transcriptEditSegment.
  ///
  /// In en, this message translates to:
  /// **'Edit segment at {time}'**
  String transcriptEditSegment(String time);

  /// No description provided for @transcriptEditFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save your edit.'**
  String get transcriptEditFailed;

  /// No description provided for @transcriptSegmentLabel.
  ///
  /// In en, this message translates to:
  /// **'{speaker} at {time}: {text}. Tap to play from here.'**
  String transcriptSegmentLabel(String speaker, String time, String text);

  /// No description provided for @transcriptNoSpeaker.
  ///
  /// In en, this message translates to:
  /// **'Segment'**
  String get transcriptNoSpeaker;

  /// No description provided for @transcriptEdited.
  ///
  /// In en, this message translates to:
  /// **'Edited'**
  String get transcriptEdited;

  /// No description provided for @transcriptLowConfidenceHint.
  ///
  /// In en, this message translates to:
  /// **'Underlined words may be misheard.'**
  String get transcriptLowConfidenceHint;

  /// No description provided for @transcriptPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get transcriptPlay;

  /// No description provided for @transcriptPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get transcriptPause;

  /// No description provided for @transcriptPlaybackUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Audio playback is not available for this recording.'**
  String get transcriptPlaybackUnavailable;

  /// No description provided for @transcriptMarkerUser.
  ///
  /// In en, this message translates to:
  /// **'Marker'**
  String get transcriptMarkerUser;

  /// No description provided for @transcriptMarkerGap.
  ///
  /// In en, this message translates to:
  /// **'Gap in the audio'**
  String get transcriptMarkerGap;

  /// No description provided for @transcriptMarkerCall.
  ///
  /// In en, this message translates to:
  /// **'Recording stopped for a call'**
  String get transcriptMarkerCall;

  /// No description provided for @transcriptMarkerLabel.
  ///
  /// In en, this message translates to:
  /// **'{kind} at {time}'**
  String transcriptMarkerLabel(String kind, String time);

  /// No description provided for @routingRulesAdd.
  ///
  /// In en, this message translates to:
  /// **'Add rule'**
  String get routingRulesAdd;

  /// No description provided for @routingRulesLocked.
  ///
  /// In en, this message translates to:
  /// **'Routing rules are a Pro feature. Your rules are kept but not applied: every note goes to your first vault folder.'**
  String get routingRulesLocked;

  /// No description provided for @routingRuleTo.
  ///
  /// In en, this message translates to:
  /// **'To {folder}'**
  String routingRuleTo(String folder);

  /// No description provided for @routingRuleEveryNote.
  ///
  /// In en, this message translates to:
  /// **'Every note'**
  String get routingRuleEveryNote;

  /// No description provided for @routingRuleMatchesSome.
  ///
  /// In en, this message translates to:
  /// **'Notes matching {count, plural, =1{1 condition} other{{count} conditions}}'**
  String routingRuleMatchesSome(int count);

  /// No description provided for @routingRuleContinues.
  ///
  /// In en, this message translates to:
  /// **'then later rules'**
  String get routingRuleContinues;

  /// No description provided for @routingRuleOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get routingRuleOff;

  /// No description provided for @routingRuleNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New rule'**
  String get routingRuleNewTitle;

  /// No description provided for @routingRuleEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit rule'**
  String get routingRuleEditTitle;

  /// No description provided for @routingRuleName.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get routingRuleName;

  /// No description provided for @routingRuleTarget.
  ///
  /// In en, this message translates to:
  /// **'Vault folder'**
  String get routingRuleTarget;

  /// No description provided for @routingRuleNoTargets.
  ///
  /// In en, this message translates to:
  /// **'Add a vault folder first.'**
  String get routingRuleNoTargets;

  /// No description provided for @routingRuleTargetRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose a vault folder.'**
  String get routingRuleTargetRequired;

  /// No description provided for @routingRuleSubPath.
  ///
  /// In en, this message translates to:
  /// **'Sub-folder (optional)'**
  String get routingRuleSubPath;

  /// No description provided for @routingRuleSubPathHint.
  ///
  /// In en, this message translates to:
  /// **'For example Meetings/2026'**
  String get routingRuleSubPathHint;

  /// No description provided for @routingRuleFilename.
  ///
  /// In en, this message translates to:
  /// **'File name pattern (optional)'**
  String get routingRuleFilename;

  /// No description provided for @routingRuleFilenameHint.
  ///
  /// In en, this message translates to:
  /// **'Empty: the folder’s or the default pattern'**
  String get routingRuleFilenameHint;

  /// No description provided for @routingRuleConditions.
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get routingRuleConditions;

  /// No description provided for @routingRuleConditionsHelp.
  ///
  /// In en, this message translates to:
  /// **'Separate values with commas. Every filled-in condition must match; a rule without conditions matches every note.'**
  String get routingRuleConditionsHelp;

  /// No description provided for @routingRuleProfiles.
  ///
  /// In en, this message translates to:
  /// **'Profile ids'**
  String get routingRuleProfiles;

  /// No description provided for @routingRuleTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get routingRuleTags;

  /// No description provided for @routingRuleKeywords.
  ///
  /// In en, this message translates to:
  /// **'Keywords in title or summary'**
  String get routingRuleKeywords;

  /// No description provided for @routingRuleSpeakers.
  ///
  /// In en, this message translates to:
  /// **'Speaker names'**
  String get routingRuleSpeakers;

  /// No description provided for @routingRuleContinue.
  ///
  /// In en, this message translates to:
  /// **'Also check later rules'**
  String get routingRuleContinue;

  /// No description provided for @routingRuleContinueHelp.
  ///
  /// In en, this message translates to:
  /// **'Off: the first matching rule decides. On: later matching rules add more folders.'**
  String get routingRuleContinueHelp;

  /// No description provided for @routingRuleEnabled.
  ///
  /// In en, this message translates to:
  /// **'Rule is on'**
  String get routingRuleEnabled;

  /// No description provided for @routingRuleSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get routingRuleSave;

  /// No description provided for @routingRuleSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the rule.'**
  String get routingRuleSaveFailed;

  /// No description provided for @routingRuleDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete rule'**
  String get routingRuleDelete;

  /// No description provided for @routingRuleDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this rule?'**
  String get routingRuleDeleteTitle;

  /// No description provided for @routingRuleDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Notes already written stay where they are.'**
  String get routingRuleDeleteBody;

  /// No description provided for @routingRuleNotFound.
  ///
  /// In en, this message translates to:
  /// **'This rule no longer exists.'**
  String get routingRuleNotFound;

  /// No description provided for @vaultTargetOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Folder options'**
  String get vaultTargetOptionsTitle;

  /// No description provided for @vaultTargetCollision.
  ///
  /// In en, this message translates to:
  /// **'If the note already exists'**
  String get vaultTargetCollision;

  /// No description provided for @vaultTargetCollisionDefault.
  ///
  /// In en, this message translates to:
  /// **'Use the default setting'**
  String get vaultTargetCollisionDefault;

  /// No description provided for @vaultTargetFilename.
  ///
  /// In en, this message translates to:
  /// **'File name pattern (optional)'**
  String get vaultTargetFilename;

  /// No description provided for @vaultTargetTranscript.
  ///
  /// In en, this message translates to:
  /// **'Also save the transcript'**
  String get vaultTargetTranscript;

  /// No description provided for @vaultTargetTranscriptHelp.
  ///
  /// In en, this message translates to:
  /// **'Writes a separate transcript note next to each note.'**
  String get vaultTargetTranscriptHelp;

  /// No description provided for @vaultTargetAudio.
  ///
  /// In en, this message translates to:
  /// **'Also copy the audio'**
  String get vaultTargetAudio;

  /// No description provided for @vaultTargetAudioHelp.
  ///
  /// In en, this message translates to:
  /// **'Copies the recording into an attachments folder. Audio files are large and leave the app’s protected storage.'**
  String get vaultTargetAudioHelp;

  /// No description provided for @vaultTargetSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the folder options.'**
  String get vaultTargetSaveFailed;

  /// No description provided for @vaultTargetDisabled.
  ///
  /// In en, this message translates to:
  /// **'Not used on your current plan'**
  String get vaultTargetDisabled;

  /// No description provided for @vaultTargetNotFound.
  ///
  /// In en, this message translates to:
  /// **'This folder no longer exists.'**
  String get vaultTargetNotFound;

  /// No description provided for @settingsPendingExports.
  ///
  /// In en, this message translates to:
  /// **'Pending exports'**
  String get settingsPendingExports;

  /// No description provided for @settingsPendingExportsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Notes still waiting for a vault folder'**
  String get settingsPendingExportsSubtitle;

  /// No description provided for @pendingExportsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Every note has reached its vault folder.'**
  String get pendingExportsEmpty;

  /// No description provided for @pendingExportsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load pending exports.'**
  String get pendingExportsLoadFailed;

  /// No description provided for @pendingExportsSafe.
  ///
  /// In en, this message translates to:
  /// **'Waiting notes are kept safely in the app until they can be written.'**
  String get pendingExportsSafe;

  /// No description provided for @pendingUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled recording'**
  String get pendingUntitled;

  /// No description provided for @pendingReasonNoDestination.
  ///
  /// In en, this message translates to:
  /// **'No vault folder chosen yet'**
  String get pendingReasonNoDestination;

  /// No description provided for @pendingReasonRevoked.
  ///
  /// In en, this message translates to:
  /// **'Access to {folder} was removed'**
  String pendingReasonRevoked(String folder);

  /// No description provided for @pendingReasonRevokedAny.
  ///
  /// In en, this message translates to:
  /// **'Access to the vault folder was removed'**
  String get pendingReasonRevokedAny;

  /// No description provided for @pendingReasonRetrying.
  ///
  /// In en, this message translates to:
  /// **'{folder} is not reachable right now. Retrying automatically.'**
  String pendingReasonRetrying(String folder);

  /// No description provided for @pendingReasonFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not write to {folder}'**
  String pendingReasonFailed(String folder);

  /// No description provided for @pendingActionRegrant.
  ///
  /// In en, this message translates to:
  /// **'Re-grant access'**
  String get pendingActionRegrant;

  /// No description provided for @pendingActionChange.
  ///
  /// In en, this message translates to:
  /// **'Choose another folder'**
  String get pendingActionChange;

  /// No description provided for @pendingActionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry now'**
  String get pendingActionRetry;

  /// No description provided for @pendingActionChooseFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose a folder'**
  String get pendingActionChooseFolder;

  /// No description provided for @pendingActionSaveOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Save on this device'**
  String get pendingActionSaveOnDevice;

  /// No description provided for @pendingActionFailed.
  ///
  /// In en, this message translates to:
  /// **'That did not work. Please try again.'**
  String get pendingActionFailed;

  /// No description provided for @settingsTemplates.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get settingsTemplates;

  /// No description provided for @settingsTemplatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How your notes are laid out'**
  String get settingsTemplatesSubtitle;

  /// No description provided for @templatesBuiltin.
  ///
  /// In en, this message translates to:
  /// **'Built-in templates'**
  String get templatesBuiltin;

  /// No description provided for @templatesCustom.
  ///
  /// In en, this message translates to:
  /// **'Your templates'**
  String get templatesCustom;

  /// No description provided for @templatesCustomEmpty.
  ///
  /// In en, this message translates to:
  /// **'No custom templates yet. Open a built-in template and duplicate it to start.'**
  String get templatesCustomEmpty;

  /// No description provided for @templatesLocked.
  ///
  /// In en, this message translates to:
  /// **'Custom templates are a Pro feature. Existing templates are kept read-only.'**
  String get templatesLocked;

  /// No description provided for @templatesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load templates.'**
  String get templatesLoadFailed;

  /// No description provided for @templateFlavorObsidian.
  ///
  /// In en, this message translates to:
  /// **'Obsidian'**
  String get templateFlavorObsidian;

  /// No description provided for @templateFlavorLogseq.
  ///
  /// In en, this message translates to:
  /// **'Logseq'**
  String get templateFlavorLogseq;

  /// No description provided for @templateFlavorPlain.
  ///
  /// In en, this message translates to:
  /// **'Plain text'**
  String get templateFlavorPlain;

  /// No description provided for @templateForProfile.
  ///
  /// In en, this message translates to:
  /// **'For {profile}'**
  String templateForProfile(String profile);

  /// No description provided for @templateForAnyProfile.
  ///
  /// In en, this message translates to:
  /// **'For every profile'**
  String get templateForAnyProfile;

  /// No description provided for @templateReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Built-in templates are read-only. Duplicate it to make changes.'**
  String get templateReadOnly;

  /// No description provided for @templateLockedReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Editing custom templates needs Pro. This template is read-only.'**
  String get templateLockedReadOnly;

  /// No description provided for @templateSource.
  ///
  /// In en, this message translates to:
  /// **'Template source'**
  String get templateSource;

  /// No description provided for @templateDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get templateDuplicate;

  /// No description provided for @templateDuplicateTitle.
  ///
  /// In en, this message translates to:
  /// **'Duplicate template'**
  String get templateDuplicateTitle;

  /// No description provided for @templateDuplicateName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get templateDuplicateName;

  /// No description provided for @templateDuplicateCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get templateDuplicateCreate;

  /// No description provided for @templateSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get templateSave;

  /// No description provided for @templateSaved.
  ///
  /// In en, this message translates to:
  /// **'Template saved.'**
  String get templateSaved;

  /// No description provided for @templateSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the template.'**
  String get templateSaveFailed;

  /// No description provided for @templateFixIssues.
  ///
  /// In en, this message translates to:
  /// **'Fix {count, plural, =1{1 problem} other{{count} problems}} before saving.'**
  String templateFixIssues(int count);

  /// No description provided for @templateReset.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get templateReset;

  /// No description provided for @templateResetDone.
  ///
  /// In en, this message translates to:
  /// **'Built-in text restored. Save to keep it.'**
  String get templateResetDone;

  /// No description provided for @templateDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete template'**
  String get templateDelete;

  /// No description provided for @templateDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this template?'**
  String get templateDeleteTitle;

  /// No description provided for @templateDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Notes already written are not changed. Profiles using it go back to their default template.'**
  String get templateDeleteBody;

  /// No description provided for @templateUseFor.
  ///
  /// In en, this message translates to:
  /// **'Use for {profile} notes'**
  String templateUseFor(String profile);

  /// No description provided for @templateFilename.
  ///
  /// In en, this message translates to:
  /// **'File name pattern'**
  String get templateFilename;

  /// No description provided for @templatePreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get templatePreview;

  /// No description provided for @templatePreviewRaw.
  ///
  /// In en, this message translates to:
  /// **'Markdown'**
  String get templatePreviewRaw;

  /// No description provided for @templatePreviewRendered.
  ///
  /// In en, this message translates to:
  /// **'Rendered'**
  String get templatePreviewRendered;

  /// No description provided for @templatePreviewData.
  ///
  /// In en, this message translates to:
  /// **'Preview data'**
  String get templatePreviewData;

  /// No description provided for @templatePreviewSample.
  ///
  /// In en, this message translates to:
  /// **'Sample data'**
  String get templatePreviewSample;

  /// No description provided for @templatePreviewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Fix the template to see a preview.'**
  String get templatePreviewUnavailable;

  /// No description provided for @templateIssueAt.
  ///
  /// In en, this message translates to:
  /// **'Line {line}, column {column}: {message}'**
  String templateIssueAt(int line, int column, String message);

  /// No description provided for @templateNotFound.
  ///
  /// In en, this message translates to:
  /// **'This template no longer exists.'**
  String get templateNotFound;

  /// No description provided for @templateMore.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get templateMore;

  /// No description provided for @templateImageOmitted.
  ///
  /// In en, this message translates to:
  /// **'[image: {alt}]'**
  String templateImageOmitted(String alt);

  /// No description provided for @noteShare.
  ///
  /// In en, this message translates to:
  /// **'Share note'**
  String get noteShare;

  /// No description provided for @noteShareTitle.
  ///
  /// In en, this message translates to:
  /// **'Share or copy this note'**
  String get noteShareTitle;

  /// No description provided for @noteShareFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get noteShareFormat;

  /// No description provided for @noteFormatObsidian.
  ///
  /// In en, this message translates to:
  /// **'Obsidian'**
  String get noteFormatObsidian;

  /// No description provided for @noteFormatLogseq.
  ///
  /// In en, this message translates to:
  /// **'Logseq'**
  String get noteFormatLogseq;

  /// No description provided for @noteFormatPlain.
  ///
  /// In en, this message translates to:
  /// **'Plain'**
  String get noteFormatPlain;

  /// No description provided for @noteShareFile.
  ///
  /// In en, this message translates to:
  /// **'Share as .md file'**
  String get noteShareFile;

  /// No description provided for @noteShareText.
  ///
  /// In en, this message translates to:
  /// **'Share as text'**
  String get noteShareText;

  /// No description provided for @noteCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy to clipboard'**
  String get noteCopy;

  /// No description provided for @noteCopied.
  ///
  /// In en, this message translates to:
  /// **'Note copied.'**
  String get noteCopied;

  /// No description provided for @noteShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not prepare the note.'**
  String get noteShareFailed;

  /// No description provided for @noteShareUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Sharing is not available on this device.'**
  String get noteShareUnavailable;

  /// No description provided for @noteShareHint.
  ///
  /// In en, this message translates to:
  /// **'The note leaves the app only through the app you pick.'**
  String get noteShareHint;

  /// No description provided for @indicatorRecordingTitle.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get indicatorRecordingTitle;

  /// No description provided for @indicatorRecordingText.
  ///
  /// In en, this message translates to:
  /// **'VaultVoice is recording. Tap to open.'**
  String get indicatorRecordingText;

  /// No description provided for @indicatorPausedTitle.
  ///
  /// In en, this message translates to:
  /// **'Recording paused'**
  String get indicatorPausedTitle;

  /// No description provided for @indicatorPausedCallTitle.
  ///
  /// In en, this message translates to:
  /// **'Recording paused because a call started'**
  String get indicatorPausedCallTitle;

  /// No description provided for @indicatorPausedCallText.
  ///
  /// In en, this message translates to:
  /// **'Audio from the call was not recorded. Tap Resume to continue.'**
  String get indicatorPausedCallText;

  /// No description provided for @indicatorPausedMicText.
  ///
  /// In en, this message translates to:
  /// **'Another app or the system took the microphone. Tap Resume to continue.'**
  String get indicatorPausedMicText;

  /// No description provided for @indicatorPausedSilenceTitle.
  ///
  /// In en, this message translates to:
  /// **'Recording paused after silence'**
  String get indicatorPausedSilenceTitle;

  /// No description provided for @indicatorResumeHint.
  ///
  /// In en, this message translates to:
  /// **'Tap Resume to continue.'**
  String get indicatorResumeHint;

  /// No description provided for @indicatorStillRecording.
  ///
  /// In en, this message translates to:
  /// **'Still recording ({hours}h {minutes}m)'**
  String indicatorStillRecording(int hours, String minutes);

  /// No description provided for @betaFeedbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Send beta feedback'**
  String get betaFeedbackTitle;

  /// No description provided for @betaFeedbackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Email or share a note. Nothing is sent until you pick a destination.'**
  String get betaFeedbackSubtitle;

  /// No description provided for @betaFeedbackIntro.
  ///
  /// In en, this message translates to:
  /// **'Tell us what worked and what did not. Do not include recordings or transcripts. Share opens the system sheet, where you can choose Mail.'**
  String get betaFeedbackIntro;

  /// No description provided for @betaFeedbackMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get betaFeedbackMessageLabel;

  /// No description provided for @betaFeedbackMessageHint.
  ///
  /// In en, this message translates to:
  /// **'What happened, and what you expected'**
  String get betaFeedbackMessageHint;

  /// No description provided for @betaFeedbackSatisfaction.
  ///
  /// In en, this message translates to:
  /// **'Extraction satisfaction (optional)'**
  String get betaFeedbackSatisfaction;

  /// No description provided for @betaFeedbackSatisfactionHelp.
  ///
  /// In en, this message translates to:
  /// **'How useful was the last extraction? 1 is not useful, 5 is very useful. Skip this if you have not extracted a note yet.'**
  String get betaFeedbackSatisfactionHelp;

  /// No description provided for @betaFeedbackScore.
  ///
  /// In en, this message translates to:
  /// **'Score {score} out of 5'**
  String betaFeedbackScore(int score);

  /// No description provided for @betaFeedbackIncludeDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Include diagnostics'**
  String get betaFeedbackIncludeDiagnostics;

  /// No description provided for @betaFeedbackIncludeDiagnosticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Logs, device info and performance metrics. No recordings, transcripts or notes. You can read them before sharing.'**
  String get betaFeedbackIncludeDiagnosticsSubtitle;

  /// No description provided for @betaFeedbackShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get betaFeedbackShare;

  /// No description provided for @betaFeedbackShared.
  ///
  /// In en, this message translates to:
  /// **'Choose a destination in the share sheet. Nothing is sent until you do.'**
  String get betaFeedbackShared;

  /// No description provided for @betaFeedbackDismissed.
  ///
  /// In en, this message translates to:
  /// **'Nothing was shared.'**
  String get betaFeedbackDismissed;

  /// No description provided for @betaFeedbackUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Sharing is not available on this device.'**
  String get betaFeedbackUnavailable;

  /// No description provided for @betaFeedbackFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not prepare feedback.'**
  String get betaFeedbackFailed;

  /// No description provided for @betaFeedbackEmailSubject.
  ///
  /// In en, this message translates to:
  /// **'VaultVoice beta feedback'**
  String get betaFeedbackEmailSubject;

  /// No description provided for @betaFeedbackDiagnosticsNote.
  ///
  /// In en, this message translates to:
  /// **'A diagnostics zip is attached. It contains logs, device info and metrics only.'**
  String get betaFeedbackDiagnosticsNote;

  /// No description provided for @betaFeedbackSatisfactionLine.
  ///
  /// In en, this message translates to:
  /// **'Extraction satisfaction: {score}/5'**
  String betaFeedbackSatisfactionLine(int score);

  /// No description provided for @paywallTitle.
  ///
  /// In en, this message translates to:
  /// **'Get VaultVoice Pro'**
  String get paywallTitle;

  /// No description provided for @paywallBenefits.
  ///
  /// In en, this message translates to:
  /// **'Unlock larger models, custom profiles and templates, and multiple vault folders.'**
  String get paywallBenefits;

  /// No description provided for @purchaseLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading store prices'**
  String get purchaseLoading;

  /// No description provided for @purchaseAnnual.
  ///
  /// In en, this message translates to:
  /// **'Annual subscription · {price} per year'**
  String purchaseAnnual(String price);

  /// No description provided for @purchaseLifetime.
  ///
  /// In en, this message translates to:
  /// **'Lifetime purchase · {price}'**
  String purchaseLifetime(String price);

  /// No description provided for @purchaseAnnualTerms.
  ///
  /// In en, this message translates to:
  /// **'Annual subscriptions renew automatically unless cancelled in your store account settings. Lifetime is a one-time purchase.'**
  String get purchaseAnnualTerms;

  /// No description provided for @purchaseRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get purchaseRestore;

  /// No description provided for @purchaseRetry.
  ///
  /// In en, this message translates to:
  /// **'Refresh store prices'**
  String get purchaseRetry;

  /// No description provided for @purchaseComplete.
  ///
  /// In en, this message translates to:
  /// **'Purchase verified. Your feature access has been updated.'**
  String get purchaseComplete;

  /// No description provided for @purchasePending.
  ///
  /// In en, this message translates to:
  /// **'Payment is pending. Pro will unlock after the store confirms it.'**
  String get purchasePending;

  /// No description provided for @purchaseCancelled.
  ///
  /// In en, this message translates to:
  /// **'Purchase cancelled.'**
  String get purchaseCancelled;

  /// No description provided for @purchaseUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The store could not complete this request. Check your connection and try again.'**
  String get purchaseUnavailable;

  /// No description provided for @purchaseRestored.
  ///
  /// In en, this message translates to:
  /// **'Purchases checked. Your feature access has been updated.'**
  String get purchaseRestored;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
