import 'package:vaultvoice/features/recording/domain/audio_format.dart';
import 'package:vaultvoice/features/recording/domain/audio_session_monitor.dart';
import 'package:vaultvoice/features/recording/domain/start_source.dart';

/// macOS microphone prompt (AUD-09).
///
/// The user is recording a note, not a call. The same sentence is the
/// `NSMicrophoneUsageDescription` in `packages/vv_native/macos/Info.plist`.
/// FND-09 merges that file into the runner; this task does not edit
/// `app/macos`.
const macosMicrophonePurpose =
    'Lumen uses the microphone to record a note you start, not a call. '
    'Audio stays on this Mac.';

/// Start sources that may open the microphone on macOS.
///
/// Only the in-app Record button ([StartSource.inAppButton]). Launch,
/// menu-bar items, and shortcuts are not members — they cannot start
/// capture (AUD-09, SEC-09).
const macosAllowedStartSources = <StartSource>{StartSource.inAppButton};

/// Route-change reason for "the input device went away".
///
/// Same token the iOS audio-session plugin already emits. On macOS an
/// unplug pauses the recording; a later route or engine event does not
/// reopen the microphone.
const macosInputRemovedReason = 'oldDeviceUnavailable';

/// Request names that are not the Record button. [macosStartSourceFor]
/// returns null for each of them.
const macosRefusedStartNames = <String>{
  'launch',
  'menuBar',
  'shortcut',
  'screenCapture',
  'systemAudio',
  'aggregate',
  'call',
};

/// Maps a start-request name to a [StartSource], or null when macOS must
/// not open the microphone.
///
/// Only `'recordButton'` — the existing Record button path — is accepted.
StartSource? macosStartSourceFor(String name) {
  if (name == 'recordButton') return StartSource.inAppButton;
  return null;
}

/// Whether [source] is the macOS Record button path.
bool macosMayStart(StartSource source) =>
    source == StartSource.inAppButton &&
    macosAllowedStartSources.contains(source);

/// True when [event] means the microphone was unplugged.
bool macosInputWasRemoved(AudioSessionEvent event) =>
    event.kind == AudioSessionEventKind.routeChanged &&
    event.reason == macosInputRemovedReason;

/// Whether [device] is a microphone macOS may record.
///
/// Built-in, wired, Bluetooth, and USB inputs only. Anything the plugin
/// could not classify (aggregate devices, display/AirPlay routes, another
/// app's output) is refused. There is no screen capture and no system-audio
/// tap.
bool macosMaySelectInput(AudioInputDevice device) => switch (device.kind) {
  AudioInputKind.builtIn ||
  AudioInputKind.wired ||
  AudioInputKind.bluetooth ||
  AudioInputKind.usb => true,
  AudioInputKind.unknown => false,
};
