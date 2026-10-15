import 'dart:ui';

import 'package:vaultvoice/core/diagnostics/diagnostics_bundle.dart';
import 'package:vaultvoice/core/logging/logger.dart';
import 'package:vaultvoice/core/logging/redaction.dart';
import 'package:vaultvoice/core/platform/share_service.dart';
import 'package:vaultvoice/features/beta/domain/beta_feedback.dart';

/// What the share sheet did with a feedback draft.
enum BetaFeedbackOutcome { shared, dismissed, unavailable }

/// Hands a feedback draft to the OS share sheet. When a diagnostics bundle
/// is passed it is zipped first and attached. The draft text is not logged.
class BetaFeedbackSender {
  const BetaFeedbackSender({required this.share, required this.logger});

  final ShareService share;
  final Logger logger;

  Future<BetaFeedbackOutcome> send(
    BetaFeedbackDraft draft, {
    DiagnosticsBundle? diagnostics,
    Future<String> Function(DiagnosticsBundle bundle)? zipPath,
    Rect? origin,
  }) async {
    if (!draft.hasMessage || !draft.satisfactionValid) {
      throw StateError('feedback draft is not sendable');
    }
    String? path;
    if (diagnostics != null) {
      final write = zipPath;
      if (write == null) {
        throw StateError('diagnostics zip writer missing');
      }
      path = await write(diagnostics);
    }
    final outcome = await share.sharePayload(
      text: draft.body,
      subject: draft.subject,
      filePath: path,
      mimeType: path == null ? null : 'application/zip',
      origin: origin,
    );
    // Length only. The message itself is never a log field.
    logger.info(
      'beta',
      'feedback shared',
      fields: {
        'outcome': outcome.name,
        'diagnostics': diagnostics != null,
        'chars': draft.message.trim().length,
      },
    );
    return switch (outcome) {
      ShareOutcome.shared => BetaFeedbackOutcome.shared,
      ShareOutcome.dismissed => BetaFeedbackOutcome.dismissed,
      ShareOutcome.unavailable => BetaFeedbackOutcome.unavailable,
    };
  }
}

/// Log helper for a failed send. Only the error's runtime type is recorded,
/// never the tester's message.
void logBetaFeedbackFailure(Logger logger, Object error) {
  logger.error(
    'beta',
    'feedback share failed',
    fields: {'type': LogId(error.runtimeType.toString())},
  );
}
