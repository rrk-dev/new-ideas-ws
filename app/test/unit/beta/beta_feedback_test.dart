import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/diagnostics/diagnostics_bundle.dart';
import 'package:vaultvoice/core/logging/logger.dart';
import 'package:vaultvoice/core/platform/share_service.dart';
import 'package:vaultvoice/features/beta/data/beta_feedback_sender.dart';
import 'package:vaultvoice/features/beta/domain/beta_feedback.dart';

import '../../fakes/fake_share_service.dart';
import '../logging_test.dart' show MemorySink;

void main() {
  test('feedback text is shared and is not written to the log', () async {
    const message = 'The sample extraction missed the example action item.';
    final sink = MemorySink();
    final share = FakeShareService();
    final sender = BetaFeedbackSender(
      share: share,
      logger: Logger(sinks: [sink]),
    );
    final outcome = await sender.send(
      const BetaFeedbackDraft(
        message: message,
        subject: 'Lumen beta feedback',
        satisfactionOutOfFive: 4,
        satisfactionLine: 'Extraction satisfaction: 4/5',
      ),
    );
    expect(outcome, BetaFeedbackOutcome.shared);
    expect(share.payloads, hasLength(1));
    expect(share.payloads.single.subject, 'Lumen beta feedback');
    expect(share.payloads.single.text, contains(message));
    expect(share.payloads.single.text, contains('4/5'));
    expect(share.payloads.single.path, isNull);
    final logged = sink.records.map((r) => r.toJsonLine()).join('\n');
    expect(logged, isNot(contains(message)));
    expect(logged, isNot(contains('<redacted:${message.length}>')));
    expect(logged, contains('feedback shared'));
    expect(logged, contains('"chars":${message.length}'));
  });

  test(
    'optional diagnostics zip is attached only when a bundle is passed',
    () async {
      final share = FakeShareService();
      final sender = BetaFeedbackSender(
        share: share,
        logger: Logger(sinks: [MemorySink()]),
      );
      final bundle = DiagnosticsBundle([
        DiagnosticsEntry(
          'logs/vv.log',
          Uint8List.fromList(utf8.encode('{"msg":"app start"}')),
        ),
      ], createdAt: DateTime.utc(2026, 10, 14));
      await sender.send(
        const BetaFeedbackDraft(
          message: 'Please look at the logs.',
          subject: 'Lumen beta feedback',
          diagnosticsNote: 'A diagnostics zip is attached.',
        ),
        diagnostics: bundle,
        zipPath: (b) async {
          expect(b['logs/vv.log'], isNotNull);
          return '/tmp/vaultvoice-diagnostics-test.zip';
        },
      );
      expect(
        share.payloads.single.path,
        '/tmp/vaultvoice-diagnostics-test.zip',
      );
      expect(share.payloads.single.text, contains('diagnostics zip'));
      expect(share.payloads.single.text, isNot(contains('app start')));
    },
  );

  test('an empty message is not shared', () async {
    final share = FakeShareService();
    final sender = BetaFeedbackSender(
      share: share,
      logger: Logger(sinks: [MemorySink()]),
    );
    expect(
      () => sender.send(
        const BetaFeedbackDraft(message: '   ', subject: 'Lumen beta feedback'),
      ),
      throwsStateError,
    );
    expect(share.payloads, isEmpty);
  });

  test('a dismissed sheet is not treated as sent', () async {
    final share = FakeShareService(outcome: ShareOutcome.dismissed);
    final outcome =
        await BetaFeedbackSender(
          share: share,
          logger: Logger(sinks: [MemorySink()]),
        ).send(
          const BetaFeedbackDraft(
            message: 'Hello',
            subject: 'Lumen beta feedback',
          ),
        );
    expect(outcome, BetaFeedbackOutcome.dismissed);
  });
}
