import 'package:vaultvoice/features/transcription/domain/playback_timeline.dart';
import 'package:vaultvoice/features/transcription/domain/transcript_player.dart';
import 'package:vaultvoice/features/transcription/domain/transcript_view.dart';
import 'package:vaultvoice/features/transcription/presentation/transcript_providers.dart';
import 'package:vaultvoice/features/transcription/presentation/transcript_screen.dart';

import '../fakes/fake_transcript_player.dart';
import '../helpers/golden.dart';

const _view = TranscriptViewData(
  transcriptId: 't1',
  edited: true,
  segments: [
    TranscriptSegmentView(
      id: 1,
      seq: 0,
      startMs: 0,
      endMs: 4000,
      text: 'Okay, let us start with the release schedule.',
      speaker: 'Speaker 1',
    ),
    TranscriptSegmentView(
      id: 2,
      seq: 1,
      startMs: 4200,
      endMs: 9000,
      text: 'Priya said the Android build is ready for testing.',
      speaker: 'Priya',
      tokens: [
        SegmentToken(text: ' Priya', p: 0.31),
        SegmentToken(text: ' said', p: 0.97),
      ],
    ),
    TranscriptSegmentView(
      id: 3,
      seq: 2,
      startMs: 12500,
      endMs: 18000,
      text: 'Marcus will own the crash fix and report on Thursday.',
      originalText: 'Marcus will own the crash fix and report on Tuesday.',
      speaker: 'Speaker 1',
    ),
  ],
  markers: [TranscriptMarkerView(id: 1, atMs: 10000, label: 'Decision')],
);

void main() {
  goldenTest(
    '[STT-06] Transcript viewer',
    fileName: 'transcript_screen',
    overrides: [
      transcriptViewProvider('rec-a').overrideWith((ref) async => _view),
      transcriptPlaybackProvider('rec-a').overrideWith(
        (ref) async => TranscriptPlayback(
          FakeTranscriptPlayer(),
          PlaybackTimeline(const [
            PlaybackChunk(path: '/c0', startMs: 0, pcmBytes: 20000 * 32),
          ]),
        ),
      ),
    ],
    builder: (_) => const TranscriptScreen(recordingId: 'rec-a'),
  );
}
