import 'dart:io';

import 'package:vaultvoice/core/crash/crash_store.dart';
import 'package:vaultvoice/core/crash/dart_crash_recorder.dart';
import 'package:vaultvoice/core/crash/native_crash_capture.dart';
import 'package:vaultvoice/core/errors/error_boundary.dart';
import 'package:vaultvoice/core/flavor.dart';
import 'package:vaultvoice/core/logging/logger.dart';
import 'package:vaultvoice/core/logging/redaction.dart';
import 'package:vaultvoice/core/platform/clock.dart';

/// Build identity written into crash reports. Release builds pass
/// `--dart-define=VV_BUILD_NAME=<x.y.z> --dart-define=VV_BUILD_NUMBER=<n>`
/// (REL-01); the native report additionally carries every module's build id.
abstract final class CrashBuildInfo {
  static const buildName = String.fromEnvironment(
    'VV_BUILD_NAME',
    defaultValue: '0.0.0',
  );
  static const buildNumber = String.fromEnvironment(
    'VV_BUILD_NUMBER',
    defaultValue: '0',
  );

  static String describe(Flavor flavor) =>
      '$buildName+$buildNumber ${flavor.name}';

  /// OS name + version, e.g. `ios Version 18.1 (Build 22B83)`.
  static String os() =>
      '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
}

/// Local crash capture wiring used by `bootstrap` (REL-02).
///
/// Order matters: harvest the previous run's native report first, then
/// install the handler (which truncates the live file).
class CrashReporting {
  CrashReporting._(this.store, this.dart, {required this.nativeInstalled});

  factory CrashReporting.start({
    required Directory directory,
    required NativeCrashCapture native,
    required String appBuild,
    required Logger logger,
    String? os,
    Clock clock = const SystemClock(),
  }) {
    final store = CrashReportStore(directory, clock: clock);
    var harvested = false;
    var installed = false;
    try {
      store.ensureDirectory();
      harvested = store.harvestNative() != null;
      installed = native.install(
        reportPath: store.currentNativeFile.path,
        appBuild: appBuild,
      );
    } on Object catch (e) {
      logger.warning(
        'crash',
        'crash capture setup failed',
        fields: {'type': LogId(e.runtimeType.toString())},
      );
    }
    logger.info(
      'crash',
      'crash capture ready',
      fields: {
        'native': installed,
        'harvested_native': harvested,
        'pending': store.list().length,
      },
    );
    return CrashReporting._(
      store,
      DartCrashRecorder(
        store: store,
        appBuild: appBuild,
        os: os ?? CrashBuildInfo.os(),
        clock: clock,
      ),
      nativeInstalled: installed,
    );
  }

  final CrashReportStore store;
  final DartCrashRecorder dart;
  final bool nativeInstalled;

  /// [CrashSink] for `installErrorBoundary(onCrash: …)`.
  void recordDart(Object error, StackTrace? stack, ErrorSource source) =>
      dart.record(error, stack, source);
}
