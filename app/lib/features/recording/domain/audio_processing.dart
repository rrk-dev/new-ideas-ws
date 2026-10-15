/// The user's audio-processing settings (Settings → Audio, AUD-02).
///
/// Defaults are **provisional** — platform AGC + noise suppression on; the
/// data-driven WER comparison that confirms or changes them is QA-02's
/// (ADR-AUD-02-agc-level-metering).
final class AudioProcessingSettings {
  const AudioProcessingSettings({
    this.platformAgc = true,
    this.noiseSuppression = true,
    this.softwareAgc = false,
    this.rawCapture = false,
  });

  /// Nothing applied: the AUD-01 behaviour (tests, raw capture).
  static const none = AudioProcessingSettings(
    platformAgc: false,
    noiseSuppression: false,
  );

  /// `audio.agc`: platform automatic gain control.
  final bool platformAgc;

  /// `audio.noise_suppression`: platform noise suppression.
  final bool noiseSuppression;

  /// `audio.software_agc`: the app's own AGC replaces the platform AGC.
  final bool softwareAgc;

  /// `audio.raw_capture`: power-user switch — no processing at all.
  final bool rawCapture;
}

/// Which platform voice-processing effects exist on this device.
final class PlatformAudioEffects {
  const PlatformAudioEffects({
    required this.agc,
    required this.noiseSuppression,
    this.voiceProcessingIo = false,
  });

  /// Nothing known to be available (fail safe: the software AGC takes over).
  static const unavailable = PlatformAudioEffects(
    agc: false,
    noiseSuppression: false,
  );

  /// Android `AutomaticGainControl.isAvailable()` / iOS VPIO AGC.
  final bool agc;

  /// Android `NoiseSuppressor.isAvailable()` / iOS VPIO.
  final bool noiseSuppression;

  /// iOS: AGC and noise suppression exist only inside the voice-processing
  /// I/O unit, which `record` enables through its `echoCancel` flag
  /// (record_ios 2.1.1 `setVoiceProcessingEnabled(echoCancel)`;
  /// `isVoiceProcessingAGCEnabled = autoGain`; `noiseSuppress` is ignored).
  final bool voiceProcessingIo;
}

/// The effective processing for one capture: platform flags for the `record`
/// config plus whether the software AGC runs.
final class ResolvedAudioProcessing {
  const ResolvedAudioProcessing({
    this.autoGain = false,
    this.echoCancel = false,
    this.noiseSuppress = false,
    this.softwareAgc = false,
  });

  static const none = ResolvedAudioProcessing();

  final bool autoGain;
  final bool echoCancel;
  final bool noiseSuppress;
  final bool softwareAgc;

  @override
  String toString() =>
      'ResolvedAudioProcessing(agc: $autoGain, aec: $echoCancel, '
      'ns: $noiseSuppress, swAgc: $softwareAgc)';
}

/// Resolves [settings] against what the device offers:
///
/// * raw capture → nothing at all;
/// * software AGC chosen → platform AGC off, software AGC on;
/// * platform AGC wanted but unavailable → software AGC (fallback);
/// * iOS: AGC/NS need the voice-processing I/O, switched on via `echoCancel`.
///   Echo cancellation is otherwise never requested (far-field meetings,
///   nothing is played back while recording).
ResolvedAudioProcessing resolveAudioProcessing(
  AudioProcessingSettings settings,
  PlatformAudioEffects effects,
) {
  if (settings.rawCapture) return ResolvedAudioProcessing.none;
  final platformAgc =
      settings.platformAgc && !settings.softwareAgc && effects.agc;
  final softwareAgc =
      settings.softwareAgc || (settings.platformAgc && !effects.agc);
  final ns = settings.noiseSuppression && effects.noiseSuppression;
  return ResolvedAudioProcessing(
    autoGain: platformAgc,
    noiseSuppress: ns,
    echoCancel: effects.voiceProcessingIo && (platformAgc || ns),
    softwareAgc: softwareAgc,
  );
}
