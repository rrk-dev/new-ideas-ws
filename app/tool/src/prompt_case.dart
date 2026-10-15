import 'dart:io';

import 'package:vaultvoice/features/profiles/domain/builtin_profiles.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/domain/profile_codec.dart';
import 'package:vaultvoice/features/profiles/domain/prompt_builder.dart';

/// One eval / CLI case (`tools/bench/eval/<profile>/cases/*.json`):
///
/// ```json
/// {"id": "meeting-001",
///  "metadata": {"date": "2026-03-02T10:00:00", "duration_s": 600,
///               "speakers": [{"label": "S1", "name": "Priya"}],
///               "markers": [{"t": "00:01:00", "label": "Budget"}]},
///  "segments": [{"t": "00:00:05", "speaker": "S1", "text": "…"}]}
/// ```
/// Instead of `segments`, `transcript` may hold `[hh:mm:ss] Name: text`
/// lines (the name is used as the speaker label as-is).
final class PromptCase {
  const PromptCase({
    required this.id,
    required this.metadata,
    required this.segments,
  });

  factory PromptCase.fromJson(Map<String, Object?> json) {
    final meta = (json['metadata'] as Map<String, Object?>?) ?? const {};
    final segments = switch (json['segments']) {
      final List<Object?> list => [
        for (final s in list.cast<Map<String, Object?>>())
          PromptSegment(
            start: parsePromptTimestamp(s['t']! as String),
            speaker: s['speaker'] as String?,
            text: s['text']! as String,
          ),
      ],
      _ => parseTranscriptLines((json['transcript'] as String?) ?? ''),
    };
    final speakers = [
      for (final s
          in ((meta['speakers'] as List<Object?>?) ?? const [])
              .cast<Map<String, Object?>>())
        PromptSpeaker(label: s['label']! as String, name: s['name'] as String?),
    ];
    final markers = [
      for (final m
          in ((meta['markers'] as List<Object?>?) ?? const [])
              .cast<Map<String, Object?>>())
        PromptMarker(
          at: parsePromptTimestamp(m['t']! as String),
          label: m['label'] as String?,
        ),
    ];
    final last = segments.isEmpty ? Duration.zero : segments.last.start;
    return PromptCase(
      id: (json['id'] as String?) ?? 'case',
      metadata: PromptMetadata(
        recordedAt: DateTime.parse(
          (meta['date'] as String?) ?? '2026-01-05T10:00:00',
        ),
        duration: meta['duration_s'] is num
            ? Duration(
                milliseconds: ((meta['duration_s']! as num) * 1000).round(),
              )
            : last + const Duration(seconds: 5),
        speakers: speakers,
        markers: markers,
      ),
      segments: segments,
    );
  }

  final String id;
  final PromptMetadata metadata;
  final List<PromptSegment> segments;

  PromptInput inputFor(Profile profile) =>
      PromptInput(profile: profile, metadata: metadata, segments: segments);
}

/// `hh:mm:ss` (or `mm:ss`) → duration.
Duration parsePromptTimestamp(String t) {
  final parts = t.split(':').map(int.parse).toList();
  var seconds = 0;
  for (final p in parts) {
    seconds = seconds * 60 + p;
  }
  return Duration(seconds: seconds);
}

final _line = RegExp(
  r'^\[(\d{1,2}:\d{2}(?::\d{2})?)\]\s*(?:([^:]{1,60}):\s)?(.*)$',
);

/// Parses `[hh:mm:ss] Name: text` lines; other non-empty lines continue the
/// previous segment.
List<PromptSegment> parseTranscriptLines(String text) {
  final out = <PromptSegment>[];
  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final m = _line.firstMatch(line);
    if (m == null) {
      if (out.isEmpty) {
        out.add(PromptSegment(start: Duration.zero, text: line));
      } else {
        final prev = out.removeLast();
        out.add(
          PromptSegment(
            start: prev.start,
            speaker: prev.speaker,
            text: '${prev.text} $line',
          ),
        );
      }
      continue;
    }
    out.add(
      PromptSegment(
        start: parsePromptTimestamp(m.group(1)!),
        speaker: m.group(2)?.trim(),
        text: m.group(3)!,
      ),
    );
  }
  return out;
}

/// Loads a built-in profile by id (`assets/profiles/<id>.yaml`, relative to
/// [appDir]) or a profile YAML file by path. Throws [FormatException] with
/// every validation issue.
Profile loadProfile(String idOrPath, {required String appDir}) {
  final asBuiltin = File('$appDir/assets/profiles/$idOrPath.yaml');
  final file = asBuiltin.existsSync() ? asBuiltin : File(idOrPath);
  final isBuiltin =
      asBuiltin.existsSync() ||
      kBuiltinProfileAssets.any((a) => file.path.endsWith(a));
  final result = ProfileCodec.parseYaml(
    file.readAsStringSync(),
    profileSource: isBuiltin ? ProfileSource.builtin : ProfileSource.user,
  );
  if (result.profile case final p?) return p;
  throw FormatException(
    'invalid profile ${file.path}:\n${result.issues.join('\n')}',
  );
}

/// Deterministic stand-in when no model is given: ChatML template and
/// ≈ 4 characters per token (rounded up). Output is marked `exact: false`.
final class ApproxTokenizer implements PromptTokenizer {
  const ApproxTokenizer();

  @override
  int countTokens(String text) => (text.length + 3) ~/ 4;

  @override
  String applyChatTemplate(List<ChatMessage> messages) {
    final out = StringBuffer();
    for (final (role, content) in messages) {
      out.write('<|im_start|>$role\n$content<|im_end|>\n');
    }
    return (out..write('<|im_start|>assistant\n')).toString();
  }
}
