import 'dart:ui';

import 'package:share_plus/share_plus.dart';
import 'package:vaultvoice/core/platform/share_service.dart';

/// [ShareService] backed by `share_plus` (Android `ACTION_SEND` chooser via
/// its own FileProvider, iOS `UIActivityViewController`). Verified against
/// share_plus 13.3.1 / share_plus_platform_interface 7.2.0
/// (`SharePlus.instance.share(ShareParams)`).
class SharePlusShareService implements ShareService {
  const SharePlusShareService();

  @override
  Future<ShareOutcome> shareFile(
    String path, {
    required String mimeType,
    String? subject,
    Rect? origin,
  }) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: mimeType)],
        subject: subject,
        sharePositionOrigin: origin,
        // Web-only fallbacks; disabled so nothing is ever sent implicitly.
        mailToFallbackEnabled: false,
        downloadFallbackEnabled: false,
      ),
    );
    return switch (result.status) {
      ShareResultStatus.success => ShareOutcome.shared,
      ShareResultStatus.dismissed => ShareOutcome.dismissed,
      ShareResultStatus.unavailable => ShareOutcome.unavailable,
    };
  }

  @override
  Future<ShareOutcome> shareText(
    String text, {
    String? subject,
    Rect? origin,
  }) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: subject,
        sharePositionOrigin: origin,
        mailToFallbackEnabled: false,
        downloadFallbackEnabled: false,
      ),
    );
    return _outcome(result.status);
  }

  @override
  Future<ShareOutcome> sharePayload({
    String? text,
    String? subject,
    String? filePath,
    String? mimeType,
    Rect? origin,
  }) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: subject,
        files: filePath == null
            ? null
            : [
                XFile(
                  filePath,
                  mimeType: mimeType ?? 'application/octet-stream',
                ),
              ],
        sharePositionOrigin: origin,
        // Web-only fallbacks; disabled so nothing is ever sent implicitly.
        // Verified against share_plus 13.3.1: text and files may be combined;
        // Mail uses [subject] as the message subject (EXTRA_SUBJECT).
        mailToFallbackEnabled: false,
        downloadFallbackEnabled: false,
      ),
    );
    return _outcome(result.status);
  }

  static ShareOutcome _outcome(ShareResultStatus s) => switch (s) {
    ShareResultStatus.success => ShareOutcome.shared,
    ShareResultStatus.dismissed => ShareOutcome.dismissed,
    ShareResultStatus.unavailable => ShareOutcome.unavailable,
  };
}
