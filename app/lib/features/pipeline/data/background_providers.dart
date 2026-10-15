import 'dart:io';
import 'dart:ui';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/features/pipeline/data/background_guard.dart';
import 'package:vaultvoice/features/pipeline/data/job_mapper.dart';
import 'package:vaultvoice/features/pipeline/data/method_channel_background_processing.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_providers.dart';
import 'package:vaultvoice/features/pipeline/domain/background_platform.dart';

part 'background_providers.g.dart';

/// OS background-execution bridge (FND-08); a no-op off iOS/Android.
@Riverpod(keepAlive: true)
BackgroundProcessingPlatform backgroundProcessingPlatform(Ref ref) =>
    Platform.isAndroid || Platform.isIOS
    ? MethodChannelBackgroundProcessing()
    : const NoBackgroundProcessingPlatform();

/// The background guardrails; `ProcessingServicesHost` starts it.
@Riverpod(keepAlive: true)
BackgroundProcessingGuard backgroundProcessingGuard(Ref ref) {
  final l10n = l10nFor(PlatformDispatcher.instance.locale);
  final guard = BackgroundProcessingGuard(
    platform: ref.watch(backgroundProcessingPlatformProvider),
    jobs: ref
        .watch(jobsRepositoryProvider)
        .watchAll()
        .map((rows) => [for (final r in rows) jobFromRow(r)]),
    client: () => ref.read(pipelineClientProvider.future),
    settings: ref.watch(settingsRepositoryProvider),
    texts: (
      title: l10n.notificationProcessingOngoingTitle,
      text: l10n.notificationProcessingOngoingBody,
    ),
  );
  ref.onDispose(guard.dispose);
  return guard;
}
