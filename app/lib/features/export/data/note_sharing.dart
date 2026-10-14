import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/export/domain/filename_pattern.dart';
import 'package:vaultvoice/features/pipeline/data/steps/render_write_steps.dart';
import 'package:vaultvoice/features/profiles/domain/builtin_profiles.dart';
import 'package:vaultvoice/features/templates/data/template_note_renderer.dart';
import 'package:vaultvoice/features/templates/domain/builtin_templates.dart';

/// A note ready to share (EXP-08). User content: never logged.
class ShareableNote {
  const ShareableNote({required this.markdown, required this.fileName});

  final String markdown;

  /// `<date>-<profile>-<slug>.md` (EXP-02 default pattern, file part).
  final String fileName;
}

/// Removes a leading YAML front-matter block (`---` … `---`).
String stripFrontMatter(String md) {
  if (!md.startsWith('---\n')) return md;
  final end = md.indexOf('\n---\n', 3);
  if (end < 0) return md;
  return md.substring(end + 5).replaceFirst(RegExp(r'^\n+'), '');
}

/// Renders a processed recording in an alternate output format for the
/// share sheet / clipboard (EXP-08). Nothing leaves the device here; the
/// caller hands the result to the OS share sheet on an explicit user tap.
///
/// - [TemplateFlavor.obsidian]: the note exactly as rendered for the vault
///   (`rendered/<id>.md`), re-rendered only when that file is missing.
/// - [TemplateFlavor.logseq] / [TemplateFlavor.plain]: the profile's
///   built-in variant template; a profile without a plain variant (custom
///   profiles) gets the vault note without front-matter; without a Logseq
///   variant the flavor is unavailable.
class NoteSharing {
  NoteSharing({
    required this.db,
    required this.paths,
    required this.profiles,
    required this.templates,
    required this.appVersion,
  });

  final VaultVoiceDatabase db;
  final StoragePaths paths;
  final BuiltinProfiles profiles;
  final BuiltinTemplates templates;
  final String appVersion;

  Future<ExtractionRow?> _latestExtraction(String recordingId) =>
      (db.select(db.extractions)
            ..where((e) => e.recordingId.equals(recordingId))
            ..orderBy([(e) => OrderingTerm.desc(e.createdAt)])
            ..limit(1))
          .getSingleOrNull();

  /// Formats [recordingId] can be shared in; empty = no note yet.
  Future<Set<TemplateFlavor>> available(String recordingId) async {
    final ext = await _latestExtraction(recordingId);
    final rendered = File(paths.renderedFile(recordingId)).existsSync();
    if (ext == null && !rendered) return const {};
    final profileId = ext?.profileId;
    return {
      TemplateFlavor.obsidian,
      TemplateFlavor.plain,
      if (ext != null &&
          ext.valid &&
          profileId != null &&
          builtinVariant(profileId, TemplateFlavor.logseq) != null)
        TemplateFlavor.logseq,
    };
  }

  /// The note of [recordingId] in [flavor].
  Future<Result<ShareableNote>> render(
    String recordingId,
    TemplateFlavor flavor,
  ) async {
    try {
      final RecordingRow recording;
      switch (await db.recordingsRepository.get(recordingId)) {
        case Ok(:final value):
          recording = value;
        case Err(:final failure):
          return Err(failure);
      }
      final ext = await _latestExtraction(recordingId);
      final rendered = File(paths.renderedFile(recordingId));
      final vaultNote = rendered.existsSync()
          ? await rendered.readAsString()
          : null;
      final variant = ext == null || !ext.valid
          ? null
          : builtinVariant(ext.profileId, flavor);

      String? markdown;
      if (flavor == TemplateFlavor.obsidian && vaultNote != null) {
        markdown = vaultNote;
      } else if (ext != null &&
          (variant != null || flavor == TemplateFlavor.obsidian)) {
        markdown = await _renderWith(recording, ext, variant?.id);
      } else if (flavor == TemplateFlavor.plain) {
        final base =
            vaultNote ??
            (ext == null ? null : await _renderWith(recording, ext, null));
        markdown = base == null ? null : stripFrontMatter(base);
      }
      if (markdown == null) {
        return const Err(StorageFailure('note not available in this format'));
      }
      final title = switch (ext?.json['title']) {
        final String t when t.trim().isNotEmpty => t,
        _ => recording.title.isEmpty ? null : recording.title,
      };
      final file = FilenamePattern.parse(kDefaultFilenamePattern).valueOrNull!
          .renderPath(
            FilenameValues(
              recordingId: recordingId,
              createdAt: recording.createdAt.toLocal(),
              profileId: ext?.profileId ?? recording.profileId ?? 'note',
              title: title,
            ),
          )
          .file
          .name;
      return Ok(ShareableNote(markdown: markdown, fileName: file));
    } on Exception catch (e) {
      return Err(UnexpectedFailure(e.runtimeType.toString()));
    }
  }

  Future<String> _renderWith(
    RecordingRow recording,
    ExtractionRow ext,
    String? templateId,
  ) async {
    final transcript = (await db.transcriptsRepository.latestFor(recording.id))
        .valueOrNull;
    final segments = transcript == null
        ? const <TranscriptSegmentRow>[]
        : (await db.transcriptsRepository.segments(transcript.id))
                  .valueOrNull ??
              const <TranscriptSegmentRow>[];
    final renderer = TemplateNoteRenderer(
      profiles: profiles,
      templates: templates,
      appVersion: appVersion,
      // Built-in variants are picked by id, like a user's template choice.
      templateOverrides: {ext.profileId: ?templateId},
    );
    return renderer(
      NoteInput(recording: recording, extraction: ext, segments: segments),
    );
  }

  /// Writes [note] to a fresh share folder under [tempDir] and returns the
  /// file path (the folder is emptied first: one shared note at a time).
  static Future<String> writeShareFile(
    Directory tempDir,
    ShareableNote note,
  ) async {
    final dir = Directory(p.join(tempDir.path, 'note-share'));
    if (dir.existsSync()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, note.fileName));
    await file.writeAsString(note.markdown, flush: true);
    return file.path;
  }
}
