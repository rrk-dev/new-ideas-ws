import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/routing/app_routes.dart';

part 'transcript_navigation.g.dart';

/// Opens a recording's transcript at a position — the target of "show in
/// transcript" and of extraction source links (APP-05).
///
/// Production (integration wave 3): [PlaybackTranscriptNavigator] — the
/// STT-06 viewer/editor scrolled to `atMs` and playing from it.
/// [LinesTranscriptNavigator] (APP-02's read-only list) stays available.
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

/// Opens the STT-06 transcript viewer at `atMs` (seeks the audio there).
class PlaybackTranscriptNavigator implements TranscriptNavigator {
  const PlaybackTranscriptNavigator();

  @override
  void open(BuildContext context, String recordingId, {int? atMs}) =>
      TranscriptRoute(recordingId: recordingId, t: atMs).push<void>(context);
}

@Riverpod(keepAlive: true)
TranscriptNavigator transcriptNavigator(Ref ref) =>
    const PlaybackTranscriptNavigator();
