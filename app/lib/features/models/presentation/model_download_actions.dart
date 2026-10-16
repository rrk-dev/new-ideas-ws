import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/features/models/data/download_providers.dart';
import 'package:vaultvoice/features/models/data/model_downloader.dart';
import 'package:vaultvoice/features/models/domain/download_policy.dart';
import 'package:vaultvoice/features/models/domain/download_state.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';
import 'package:vaultvoice/features/models/presentation/model_texts.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_providers.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

/// Human-readable size in decimal units (what OS storage screens show):
/// `42 KB`, `78 MB`, `1.9 GB`.
String formatBytes(AppLocalizations l, int bytes) {
  const mb = 1000 * 1000;
  const gb = 1000 * mb;
  if (bytes >= gb) {
    final value = NumberFormat('0.0', l.localeName).format(bytes / gb);
    return l.bytesGigabytes(value);
  }
  if (bytes < mb) {
    const kb = 1000;
    final value = NumberFormat('0', l.localeName).format((bytes / kb).ceil());
    return l.bytesKilobytes(value);
  }
  final value = NumberFormat('0', l.localeName).format((bytes / mb).ceil());
  return l.bytesMegabytes(value);
}

/// How a download request ended.
enum DownloadStart {
  /// The download runs in the background (watch its progress).
  started,

  /// The user chose to wait (Wi-Fi only, low-power mode).
  declined,

  /// A precondition the user cannot override here (offline, no space).
  blocked,

  /// The downloader could not be created (no storage / platform).
  unavailable,
}

/// Starts downloading [model]; see [startModelDownloads].
Future<DownloadStart> startModelDownload(
  BuildContext context,
  WidgetRef ref,
  CatalogModel model,
) => startModelDownloads(context, ref, [model]);

/// Starts downloading [models] after showing what it involves: the total
/// size up front, mobile-data consent when only a metered network is
/// available (optionally remembered in `models.allow_cellular_downloads`),
/// and a low-power-mode confirmation (MDL-02 preconditions) — asked once for
/// all of them. Failures surface as snack bars; the downloads continue while
/// the user explores the app.
Future<DownloadStart> startModelDownloads(
  BuildContext context,
  WidgetRef ref,
  List<CatalogModel> models,
) async {
  if (models.isEmpty) return DownloadStart.declined;
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.maybeOf(context);
  void say(String text) =>
      messenger?.showSnackBar(SnackBar(content: Text(text)));

  final ModelDownloader downloader;
  final List<DownloadPlan> plans;
  try {
    downloader = await ref.read(modelDownloaderProvider.future);
    plans = [for (final m in models) await downloader.plan(m)];
  } on Object {
    say(l10n.downloadUnavailable);
    return DownloadStart.unavailable;
  }
  final blocks = {for (final p in plans) ...p.blocks};
  final remaining = plans.fold(0, (sum, p) => sum + p.remainingBytes);
  final required = requiredFreeBytes(remaining);
  final free = plans.first.freeBytes;
  if (blocks.contains(ModelDownloadBlock.offline)) {
    say(l10n.downloadOffline);
    return DownloadStart.blocked;
  }
  if (blocks.contains(ModelDownloadBlock.insufficientSpace) ||
      free == null ||
      free < required) {
    say(
      l10n.downloadNoSpace(
        formatBytes(l10n, required),
        formatBytes(l10n, free ?? 0),
      ),
    );
    return DownloadStart.blocked;
  }
  bool? allowCellular;
  if (blocks.contains(ModelDownloadBlock.unmeteredNetworkRequired)) {
    if (!context.mounted) return DownloadStart.declined;
    final choice = await showDialog<_CellularChoice>(
      context: context,
      builder: (_) => _CellularDialog(size: formatBytes(l10n, remaining)),
    );
    if (choice == null || !choice.allow) {
      say(l10n.downloadWaitingForWifi);
      return DownloadStart.declined;
    }
    allowCellular = true;
    if (choice.always) {
      await ref
          .read(settingsStoreProvider)
          .set(kAllowCellularDownloadsKey, true);
    }
  }
  var allowLowPower = false;
  if (blocks.contains(ModelDownloadBlock.lowPowerMode)) {
    if (!context.mounted) return DownloadStart.declined;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.downloadLowPowerTitle),
        content: Text(context.l10n.downloadLowPowerBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.downloadLater),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.downloadAnyway),
          ),
        ],
      ),
    );
    if (ok != true) return DownloadStart.declined;
    allowLowPower = true;
  }
  // Android 13+: the download's foreground-service progress notification is
  // only visible with POST_NOTIFICATIONS — ask once, before the first one.
  if (defaultTargetPlatform == TargetPlatform.android) {
    await _askNotificationsOnce(ref);
  }
  for (final model in models) {
    unawaited(
      downloader
          .download(
            model,
            allowCellular: allowCellular,
            allowLowPower: allowLowPower,
          )
          .then((result) {
            final failure = result.failureOrNull;
            // Paused / cancelled downloads are the user's choice.
            if (failure != null && failure is! CancelledFailure) {
              final reason = ModelTexts.failureReason(l10n, failure);
              say('${model.displayName}: $reason');
            }
          }),
    );
  }
  return DownloadStart.started;
}

Future<void> _askNotificationsOnce(WidgetRef ref) async {
  final store = ref.read(settingsStoreProvider);
  const key = SettingKeys.notificationsPermissionAsked;
  if (await store.watch(key).first == true) return;
  await store.set(key, true);
  await ref.read(localNotificationsProvider).requestPermission();
}

class _CellularChoice {
  const _CellularChoice({required this.allow, required this.always});

  final bool allow;
  final bool always;
}

class _CellularDialog extends StatefulWidget {
  const _CellularDialog({required this.size});

  final String size;

  @override
  State<_CellularDialog> createState() => _CellularDialogState();
}

class _CellularDialogState extends State<_CellularDialog> {
  bool _always = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.downloadCellularTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.downloadCellularBody(widget.size)),
          CheckboxListTile(
            key: const ValueKey('download-cellular-always'),
            contentPadding: EdgeInsets.zero,
            value: _always,
            onChanged: (v) => setState(() => _always = v ?? false),
            title: Text(l10n.downloadCellularAlways),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context)
                  .pop(const _CellularChoice(allow: false, always: false)),
          child: Text(l10n.downloadWaitForWifi),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context)
                  .pop(_CellularChoice(allow: true, always: _always)),
          child: Text(l10n.downloadNow),
        ),
      ],
    );
  }
}
