import 'package:flutter/foundation.dart' show immutable;
import 'package:vaultvoice/features/export/domain/export_collision.dart';

/// Per-target export options (EXP-05), persisted as one JSON map in the
/// settings key `export.target_options` (`{targetId: options}`) so schema v1
/// needs no migration.
///
/// Sidecars are off by default (size, privacy — vv-markdown-vault-export).
@immutable
class VaultTargetOptions {
  const VaultTargetOptions({
    this.collision,
    this.filenamePattern,
    this.transcriptSidecar = false,
    this.audioSidecar = false,
  });

  factory VaultTargetOptions.fromJson(Object? raw) {
    if (raw is! Map) return defaults;
    final collision = raw['collision'];
    final pattern = raw['filename_pattern'];
    return VaultTargetOptions(
      collision: CollisionMode.values
          .where((m) => m.name == collision)
          .firstOrNull,
      filenamePattern: pattern is String && pattern.trim().isNotEmpty
          ? pattern
          : null,
      transcriptSidecar: raw['transcript_sidecar'] == true,
      audioSidecar: raw['audio_sidecar'] == true,
    );
  }

  /// Null = the global `export.collision_mode` setting (default `suffix`).
  final CollisionMode? collision;

  /// Null = the global `export.filename_pattern` setting.
  final String? filenamePattern;

  /// Also write `<note>.transcript.md` next to the note.
  final bool transcriptSidecar;

  /// Also copy the recording's audio into `attachments/` in the target.
  final bool audioSidecar;

  static const defaults = VaultTargetOptions();

  Map<String, Object?> toJson() => {
    if (collision != null) 'collision': collision!.name,
    if (filenamePattern != null) 'filename_pattern': filenamePattern,
    'transcript_sidecar': transcriptSidecar,
    'audio_sidecar': audioSidecar,
  };

  VaultTargetOptions copyWith({
    CollisionMode? Function()? collision,
    String? Function()? filenamePattern,
    bool? transcriptSidecar,
    bool? audioSidecar,
  }) => VaultTargetOptions(
    collision: collision == null ? this.collision : collision(),
    filenamePattern: filenamePattern == null
        ? this.filenamePattern
        : filenamePattern(),
    transcriptSidecar: transcriptSidecar ?? this.transcriptSidecar,
    audioSidecar: audioSidecar ?? this.audioSidecar,
  );

  @override
  bool operator ==(Object other) =>
      other is VaultTargetOptions &&
      other.collision == collision &&
      other.filenamePattern == filenamePattern &&
      other.transcriptSidecar == transcriptSidecar &&
      other.audioSidecar == audioSidecar;

  @override
  int get hashCode =>
      Object.hash(collision, filenamePattern, transcriptSidecar, audioSidecar);
}

/// Decodes the `export.target_options` setting.
Map<String, VaultTargetOptions> decodeTargetOptions(Object? raw) => raw is Map
    ? {
        for (final e in raw.entries)
          if (e.key is String)
            e.key as String: VaultTargetOptions.fromJson(e.value),
      }
    : const {};

/// Encodes the `export.target_options` setting.
Map<String, Object?> encodeTargetOptions(
  Map<String, VaultTargetOptions> options,
) => {for (final e in options.entries) e.key: e.value.toJson()};

/// Sidecar paths derived from a note path (no extra `exports` rows: the
/// note's stable identity determines them, so re-exports update them and
/// APP-02 can delete them).
abstract final class SidecarPaths {
  /// `Meetings/2026-10-14-meeting-x.md` → `…-x.transcript.md`.
  static String transcript(String notePath) =>
      '${_stem(notePath)}.transcript.md';

  /// `Meetings/note.md` + `m4a` → `Meetings/attachments/note.m4a`.
  static String audio(String notePath, String extension) {
    final slash = notePath.lastIndexOf('/');
    final folder = slash < 0 ? '' : '${notePath.substring(0, slash)}/';
    final name = _stem(slash < 0 ? notePath : notePath.substring(slash + 1));
    return '${folder}attachments/$name.$extension';
  }

  static String _stem(String path) =>
      path.endsWith('.md') ? path.substring(0, path.length - 3) : path;
}
