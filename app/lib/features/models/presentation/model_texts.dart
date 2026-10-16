import 'package:flutter/material.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/features/models/domain/download_policy.dart';
import 'package:vaultvoice/features/models/domain/download_state.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';

/// Localized labels for catalog vocabularies and download progress.
abstract final class ModelTexts {
  static String tier(AppLocalizations l, DeviceTier t) => switch (t) {
    DeviceTier.low => l.deviceTierLow,
    DeviceTier.mid => l.deviceTierMid,
    DeviceTier.high => l.deviceTierHigh,
  };

  static String type(AppLocalizations l, ModelType t) => switch (t) {
    ModelType.stt => l.modelTypeStt,
    ModelType.llm => l.modelTypeLlm,
    ModelType.vad => l.modelTypeVad,
    ModelType.diarizationSeg || ModelType.diarizationEmb => l.modelTypeSpeakers,
    ModelType.coremlEncoder => l.modelTypeAccelerator,
  };

  static IconData icon(ModelType t) => switch (t) {
    ModelType.stt ||
    ModelType.coremlEncoder => Icons.record_voice_over_outlined,
    ModelType.llm => Icons.auto_awesome_outlined,
    ModelType.vad => Icons.graphic_eq,
    ModelType.diarizationSeg ||
    ModelType.diarizationEmb => Icons.people_outline,
  };

  /// Status line for a download in progress, or null when nothing runs.
  static String? progress(AppLocalizations l, DownloadProgress? p) =>
      switch (p?.phase) {
        null || DownloadPhase.installed || DownloadPhase.cancelled => null,
        DownloadPhase.checking => l.downloadPhaseChecking,
        DownloadPhase.downloading => l.downloadPhaseDownloading(
          (p!.fraction * 100).round(),
        ),
        DownloadPhase.retrying =>
          p!.retry > 0
              ? l.downloadPhaseRetryingN(p.retry, kMaxDownloadRetries)
              : l.downloadPhaseRetrying,
        DownloadPhase.paused => l.downloadPhasePaused,
        DownloadPhase.verifying => l.downloadPhaseVerifying,
        DownloadPhase.installing => l.downloadPhaseInstalling,
        DownloadPhase.failed => failureReason(l, p!.failure),
      };

  /// Actionable text for a failed download: offline, server error, checksum
  /// mismatch or a host the egress allowlist refused.
  static String failureReason(AppLocalizations l, Failure? failure) {
    final f = failure is ModelDownloadFailure
        ? (failure.cause ?? failure)
        : failure;
    if (failure is ModelDownloadFailure &&
        failure.block == ModelDownloadBlock.offline) {
      return l.downloadFailOffline;
    }
    if (failure is ModelDownloadFailure &&
        failure.block == ModelDownloadBlock.insufficientSpace) {
      return l.downloadFailSpace;
    }
    return switch (f) {
      ModelIntegrityFailure() => l.downloadFailChecksum,
      EgressDeniedFailure() => l.downloadFailBlocked,
      NetworkFailure(message: kBlockedByNetwork) => l.downloadFailBlocked,
      NetworkFailure(:final message) =>
        RegExp(r'^http \d{3}$').hasMatch(message)
            ? l.downloadFailServer
            : l.downloadFailOffline,
      _ => l.downloadPhaseFailed,
    };
  }
}
