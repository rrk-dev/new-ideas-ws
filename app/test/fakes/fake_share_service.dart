import 'dart:ui';

import 'package:vaultvoice/core/platform/share_service.dart';

/// Records share requests instead of opening the OS sheet.
class FakeShareService implements ShareService {
  FakeShareService({this.outcome = ShareOutcome.shared});

  ShareOutcome outcome;
  final shared = <({String path, String mimeType, String? subject})>[];

  @override
  Future<ShareOutcome> shareFile(
    String path, {
    required String mimeType,
    String? subject,
    Rect? origin,
  }) async {
    shared.add((path: path, mimeType: mimeType, subject: subject));
    return outcome;
  }

  final texts = <({String text, String? subject})>[];

  @override
  Future<ShareOutcome> shareText(
    String text, {
    String? subject,
    Rect? origin,
  }) async {
    texts.add((text: text, subject: subject));
    return outcome;
  }
}
