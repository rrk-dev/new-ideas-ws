import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/diagnostics/diagnostics_providers.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/app_paths.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/core/security/security_providers.dart';
import 'package:vaultvoice/core/security/sqlite3mc_cipher.dart';
import 'package:vaultvoice/features/export/data/export_providers.dart';
import 'package:vaultvoice/features/export/domain/vault_folder.dart';
import 'package:vaultvoice/features/retention/data/recording_purger.dart';
import 'package:vaultvoice/features/retention/data/retention_sweeper.dart';
import 'package:vaultvoice/features/retention/data/secure_data_wiper.dart';
import 'package:vaultvoice/features/retention/domain/retention_policy.dart';
import 'package:vaultvoice/features/settings/domain/setting_definitions.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';
import 'package:vaultvoice/features/settings/domain/settings_ports.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

part 'retention_providers.g.dart';

@Riverpod(keepAlive: true)
Future<RecordingPurger> recordingPurger(Ref ref) async => RecordingPurger(
  ref.watch(vaultVoiceDatabaseProvider),
  await ref.watch(storagePathsProvider.future),
);

@Riverpod(keepAlive: true)
Future<RetentionSweeper> retentionSweeper(Ref ref) async => RetentionSweeper(
  db: ref.watch(vaultVoiceDatabaseProvider),
  paths: await ref.watch(storagePathsProvider.future),
  purger: await ref.watch(recordingPurgerProvider.future),
  // Effective value: an MDM-managed retention wins over the user's.
  policyFor: (key) async {
    // Same precedence as `settingStateProvider`: managed › user › default.
    final def = AppSettings.byKey(key)!;
    final managed = await ref.read(managedSettingsSourceProvider).watch().first;
    final stored = await ref.read(settingsStoreProvider).watch(key).first;
    final value = managed.values.containsKey(key)
        ? managed.values[key]
        : stored;
    return RetentionPolicy.parse(def.decode(value) as String);
  },
  clock: ref.watch(clockProvider),
);

/// The secure "Delete all data" (Settings → Privacy).
@Riverpod(keepAlive: true)
DataWiper secureDataWiper(Ref ref) => LazySecureDataWiper(ref);

/// Resolves the async dependencies of [SecureDataWiper] on first use.
class LazySecureDataWiper implements DataWiper {
  LazySecureDataWiper(this._ref);

  final Ref _ref;

  @override
  Future<Result<void>> deleteAllData() async {
    final ref = _ref;
    final db = ref.read(vaultVoiceDatabaseProvider);
    final paths = await ref.read(storagePathsProvider.future);
    final encrypted = ref.read(databaseCipherProvider) is Sqlite3mcCipher;
    final rotation = encrypted
        ? await ref.read(databaseKeyRotationProvider.future)
        : null;
    final appPaths = _tryRead<AppPaths>(() => ref.read(appPathsProvider));
    final wiper = SecureDataWiper(
      db: db,
      paths: paths,
      releaseGrant: (t) => _release(ref, t),
      rotateKey: rotation == null ? null : () => rotation.rotate(db),
      extraDirectories: [?appPaths?.temp.path],
    );
    final result = await wiper.deleteAllData();
    if (result.isOk) ref.read(networkActivityLogProvider).clear();
    return result;
  }

  static T? _tryRead<T>(T Function() read) {
    try {
      return read();
    } on Object {
      return null;
    }
  }

  static Future<void> _release(Ref ref, VaultTargetRow t) async {
    final kind = switch (t.platform) {
      VaultPlatform.androidSaf => VaultTargetKind.saf,
      VaultPlatform.iosBookmark => VaultTargetKind.bookmark,
      VaultPlatform.appLocal => null,
    };
    if (kind == null) return;
    await ref
        .read(vaultFolderAccessProvider)
        .release(VaultFolder(kind: kind, handle: t.handle));
  }
}

/// How often retention runs while the app is open (plus once at start).
const kRetentionInterval = Duration(hours: 1);

/// Runs the retention sweep at start and every [kRetentionInterval]; also
/// completes a pending database-key rotation. Started from `App`.
@Riverpod(keepAlive: true)
RetentionScheduler retentionScheduler(Ref ref) {
  final scheduler = RetentionScheduler(ref)..start();
  ref.onDispose(scheduler.dispose);
  return scheduler;
}

class RetentionScheduler {
  RetentionScheduler(this._ref);

  final Ref _ref;
  Timer? _timer;
  Future<void>? _running;

  void start() {
    _timer ??= Timer.periodic(kRetentionInterval, (_) => runOnce().ignore());
    scheduleMicrotask(() => runOnce().ignore());
  }

  /// One sweep; concurrent calls share the running one.
  Future<void> runOnce() =>
      _running ??= _run().whenComplete(() => _running = null);

  Future<void> _run() async {
    final log = _ref.read(loggerProvider);
    try {
      if (_ref.read(databaseCipherProvider) is Sqlite3mcCipher) {
        final rotation = await _ref.read(databaseKeyRotationProvider.future);
        // Any query proves the file opened (and was rekeyed to db.v1).
        await _ref
            .read(vaultVoiceDatabaseProvider)
            .customSelect('SELECT 1')
            .get();
        final done = await rotation.finishPendingRotation();
        if (done case Err(:final failure)) log.failure('retention', failure);
      }
      final sweeper = await _ref.read(retentionSweeperProvider.future);
      final report = await sweeper.run(
        audioKey: SettingKeys.audioRetention,
        transcriptKey: SettingKeys.privacyTranscriptRetention,
      );
      switch (report) {
        case Ok(:final value):
          log.info('retention', 'sweep', fields: value.toLogFields());
        case Err(:final failure):
          log.failure('retention', failure);
      }
    } on Object catch (e) {
      if (kDebugMode) debugPrint('retention sweep failed: ${e.runtimeType}');
    }
  }

  void dispose() => _timer?.cancel();
}
