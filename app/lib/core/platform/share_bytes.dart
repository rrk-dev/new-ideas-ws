import 'dart:io';
import 'dart:typed_data';

import 'package:vaultvoice/core/platform/app_paths.dart';
import 'package:vaultvoice/core/platform/share_service.dart';

/// Writes [bytes] to a scratch file under [AppPaths.temp] and hands it to
/// the share sheet. Only called from an explicit user action; nothing is
/// logged or sent anywhere by the app.
Future<ShareOutcome> shareBytesAsFile(
  ShareService share,
  AppPaths paths, {
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  await paths.temp.create(recursive: true);
  final file = File('${paths.temp.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return await share.shareFile(file.path, mimeType: mimeType);
}
