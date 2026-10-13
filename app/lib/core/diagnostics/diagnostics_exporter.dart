import 'dart:io';
import 'dart:ui';

import 'package:vaultvoice/core/app_info.dart';
import 'package:vaultvoice/core/diagnostics/diagnostics_bundle.dart';
import 'package:vaultvoice/core/logging/logger.dart';
import 'package:vaultvoice/core/platform/share_service.dart';

/// User-initiated "Export diagnostics": build → preview → zip → share sheet.
///
/// Nothing is sent by the app; the zip only leaves the device if the user
/// picks a destination in the OS share sheet.
class DiagnosticsExporter {
  DiagnosticsExporter({
    required this.builder,
    required this.shareService,
    required this.exportDirectory,
    required this.logger,
  });

  final DiagnosticsBundleBuilder builder;
  final ShareService shareService;
  final Directory exportDirectory;
  final Logger logger;

  /// Collects everything for the preview; nothing is written or shared yet.
  Future<DiagnosticsBundle> prepare() => builder.build();

  /// Zips [bundle] into app-private temp storage and opens the share sheet.
  Future<ShareOutcome> share(DiagnosticsBundle bundle, {Rect? origin}) async {
    final zip = await bundle.writeZip(exportDirectory);
    final outcome = await shareService.shareFile(
      zip.path,
      mimeType: 'application/zip',
      subject: '$kAppName diagnostics',
      origin: origin,
    );
    logger.info(
      'diagnostics',
      'diagnostics export',
      fields: {
        'outcome': outcome,
        'files': bundle.entries.length,
        'bytes': bundle.totalBytes,
      },
    );
    return outcome;
  }
}
