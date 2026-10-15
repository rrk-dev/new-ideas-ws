import 'dart:ui';

/// What happened to a share request.
enum ShareOutcome { shared, dismissed, unavailable }

/// Hands a local file to the OS share sheet. Only ever called from an
/// explicit user action (e.g. "Export diagnostics"); the app itself never
/// sends the file anywhere.
abstract interface class ShareService {
  /// [origin] anchors the popover on iPad (global coordinates).
  Future<ShareOutcome> shareFile(
    String path, {
    required String mimeType,
    String? subject,
    Rect? origin,
  });

  /// Shares plain [text] (e.g. a rendered note, EXP-08) through the sheet.
  Future<ShareOutcome> shareText(String text, {String? subject, Rect? origin});

  /// Shares [text] and, when [filePath] is set, that file, in one sheet.
  /// Used by beta feedback so the note and the optional diagnostics zip
  /// travel together. Nothing is sent until the user picks a destination.
  Future<ShareOutcome> sharePayload({
    String? text,
    String? subject,
    String? filePath,
    String? mimeType,
    Rect? origin,
  });
}
