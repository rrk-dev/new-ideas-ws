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

  /// No description provided for @settingAutoPause.
  ///
  /// In en, this message translates to:
  /// **'Auto-pause on silence'**
  String get settingAutoPause;

  /// No description provided for @settingAutoPauseDescription.
  ///
  /// In en, this message translates to:
  /// **'Pauses capture during long silences.'**
  String get settingAutoPauseDescription;

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
  /// **'On — the database is encrypted with a key kept in the device keychain.'**
  String get encryptionOn;

  /// No description provided for @encryptionOff.
  ///
  /// In en, this message translates to:
  /// **'Not enabled in this build yet.'**
  String get encryptionOff;

  /// No description provided for @encryptionDetails.
  ///
  /// In en, this message translates to:
  /// **'{status}\n\nRecordings, transcripts and notes never leave this device unless you export or share them. Notes exported to a vault folder are plain Markdown files, readable by any app with access to that folder.'**
  String encryptionDetails(String status);

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
