import 'package:flutter/material.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
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
        DownloadPhase.retrying => l.downloadPhaseRetrying,
        DownloadPhase.paused => l.downloadPhasePaused,
        DownloadPhase.verifying => l.downloadPhaseVerifying,
        DownloadPhase.installing => l.downloadPhaseInstalling,
        DownloadPhase.failed => l.downloadPhaseFailed,
      };
}
