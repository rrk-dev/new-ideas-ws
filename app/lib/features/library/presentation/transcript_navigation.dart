import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/routing/app_routes.dart';

part 'transcript_navigation.g.dart';

/// Opens a recording's transcript at a position — the target of "show in
/// transcript" and of extraction source links (APP-05).
///
/// Default: the read-only transcript list scrolled to and highlighting the
/// line at `atMs`. The STT-06 transcript viewer (with audio playback) takes
/// over by overriding `transcriptNavigatorProvider` so the link also seeks
/// the audio to `atMs`.
abstract interface class TranscriptNavigator {
  void open(BuildContext context, String recordingId, {int? atMs});
}

class LinesTranscriptNavigator implements TranscriptNavigator {
  const LinesTranscriptNavigator();

  @override
  void open(BuildContext context, String recordingId, {int? atMs}) =>
      RecordingLinesRoute(
        recordingId: recordingId,
        t: atMs,
      ).push<void>(context);
}

@Riverpod(keepAlive: true)
TranscriptNavigator transcriptNavigator(Ref ref) =>
    const LinesTranscriptNavigator();
