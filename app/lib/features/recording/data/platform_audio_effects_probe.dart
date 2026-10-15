import 'dart:io';

import 'package:flutter/services.dart';
import 'package:vaultvoice/features/recording/data/method_channel_disk_space_probe.dart';
import 'package:vaultvoice/features/recording/domain/audio_processing.dart';

/// Which platform voice-processing effects this device offers (AUD-02).
///
/// * Android: `AutomaticGainControl` / `NoiseSuppressor.isAvailable()` over
///   the `vaultvoice/storage_info` channel (`StorageInfoPlugin`).
/// * iOS: the voice-processing I/O unit (AGC + noise suppression) exists on
///   every supported device (iOS 13+ API, app minimum iOS 16).
/// * Anything else / failure: nothing available — the software AGC is used.
class PlatformAudioEffectsProbe {
  const PlatformAudioEffectsProbe({
    this._channel = const MethodChannel(
      MethodChannelDiskSpaceProbe.channelName,
    ),
    this._isIOS,
    this._isAndroid,
  });

  final MethodChannel _channel;
  final bool? _isIOS;
  final bool? _isAndroid;

  Future<PlatformAudioEffects> probe() async {
    if (_isIOS ?? Platform.isIOS) {
      return const PlatformAudioEffects(
        agc: true,
        noiseSuppression: true,
        voiceProcessingIo: true,
      );
    }
    if (!(_isAndroid ?? Platform.isAndroid)) {
      return PlatformAudioEffects.unavailable;
    }
    try {
      final m = await _channel.invokeMapMethod<String, Object?>('audioEffects');
      return PlatformAudioEffects(
        agc: m?['agc'] == true,
        noiseSuppression: m?['noiseSuppression'] == true,
      );
    } on Object {
      return PlatformAudioEffects.unavailable;
    }
  }
}
