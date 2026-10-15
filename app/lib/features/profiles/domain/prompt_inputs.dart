/// Inputs of the extraction prompt (PRF-02): transcript segments and the
/// recording metadata shown to the model. Pure data — no transcript text is
/// ever logged (vv-privacy-security).
library;

/// One speaker-labelled transcript line.
final class PromptSegment {
  const PromptSegment({required this.start, required this.text, this.speaker});

  /// Offset from the start of the recording (rendered `[hh:mm:ss]`).
  final Duration start;

  /// Diarization label (`S1`) or null when diarization was off.
  final String? speaker;
  final String text;
}

/// A diarized speaker: [label] as in [PromptSegment.speaker], [name] the
/// display name the user assigned (null = unnamed).
final class PromptSpeaker {
  const PromptSpeaker({required this.label, this.name});

  final String label;
  final String? name;
}

/// A user marker tapped during recording (AUD-08).
final class PromptMarker {
  const PromptMarker({required this.at, this.label});

  final Duration at;
  final String? label;
}

/// Recording metadata included in the user message.
final class PromptMetadata {
  const PromptMetadata({
    required this.recordedAt,
    required this.duration,
    this.speakers = const [],
    this.markers = const [],
  });

  /// Local wall-clock start of the recording (date only is shown).
  final DateTime recordedAt;
  final Duration duration;
  final List<PromptSpeaker> speakers;
  final List<PromptMarker> markers;

  /// Display name for a segment's speaker label (label when unnamed).
  String? displayName(String? label) {
    if (label == null) return null;
    for (final s in speakers) {
      if (s.label == label) {
        final name = s.name?.trim();
        return name == null || name.isEmpty ? label : name;
      }
    }
    return label;
  }
}

/// `hh:mm:ss` (hours not wrapped; > 99 h is not a real recording).
String formatPromptTimestamp(Duration d) {
  final s = d.isNegative ? 0 : d.inSeconds;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(s ~/ 3600)}:${two(s ~/ 60 % 60)}:${two(s % 60)}';
}
