import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/l10n/gen/app_localizations.dart';
import 'package:vaultvoice/features/models/domain/download_state.dart';
import 'package:vaultvoice/features/models/presentation/model_texts.dart';

void main() {
  late AppLocalizations l;
  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  String reason(Failure? f) => ModelTexts.failureReason(l, f);
  ModelDownloadFailure wrap(ModelDownloadBlock b, Failure? cause) =>
      ModelDownloadFailure('m', b, cause: cause);

  test('[MDL-03/AC1] failed downloads say why: offline', () {
    expect(reason(wrap(ModelDownloadBlock.offline, null)), contains('offline'));
    expect(
      reason(
        wrap(
          ModelDownloadBlock.retriesExhausted,
          const NetworkFailure('ClientException'),
        ),
      ),
      contains('offline'),
    );
  });

  test('[MDL-03/AC1] failed downloads say why: server error', () {
    expect(
      reason(
        wrap(
          ModelDownloadBlock.retriesExhausted,
          const NetworkFailure('http 503'),
        ),
      ),
      contains('server'),
    );
  });

  test('[MDL-03/AC1] failed downloads say why: checksum mismatch', () {
    expect(
      reason(const ModelIntegrityFailure('m', sizeMismatch: false)),
      contains('checksum'),
    );
  });

  test('[MDL-03/AC1] failed downloads say why: host not allowed', () {
    final text = reason(
      wrap(
        ModelDownloadBlock.allUrlsRejected,
        const EgressDeniedFailure('block.example'),
      ),
    );
    expect(text, contains('block.example'));
    expect(text, contains('not an allowed'));
  });

  test('[MDL-03/AC1] retrying shows the attempt, failed shows the reason', () {
    const retrying = DownloadProgress(
      modelId: 'm',
      phase: DownloadPhase.retrying,
      receivedBytes: 0,
      totalBytes: 10,
      retry: 3,
    );
    expect(ModelTexts.progress(l, retrying), contains('3 of 8'));
    const failed = DownloadProgress(
      modelId: 'm',
      phase: DownloadPhase.failed,
      receivedBytes: 0,
      totalBytes: 10,
      failure: ModelIntegrityFailure('m', sizeMismatch: true),
    );
    expect(ModelTexts.progress(l, failed), contains('checksum'));
  });
}
