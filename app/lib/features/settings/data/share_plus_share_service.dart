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
}
