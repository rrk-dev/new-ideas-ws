import 'dart:io';
import 'dart:ui';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/app_info.dart';
import 'package:vaultvoice/core/crash/crash_store.dart';
import 'package:vaultvoice/core/crash/native_crash_capture.dart';
import 'package:vaultvoice/core/diagnostics/diagnostics_providers.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/core/platform/share_service.dart';

part 'crash_providers.g.dart';

/// Crash report files; `bootstrap` overrides it with the store that
/// harvested this launch's reports.
@Riverpod(keepAlive: true)
CrashReportStore crashReportStore(Ref ref) => CrashReportStore(
  ref.watch(appPathsProvider).crashReports,
  clock: ref.watch(clockProvider),
);

/// Native handler access (dev-only forced crash). `bootstrap` overrides it
/// with the FFI implementation.
@Riverpod(keepAlive: true)
NativeCrashCapture nativeCrashCapture(Ref ref) => const NoNativeCrashCapture();

/// Stored crash reports (newest first) and the user's actions on them:
/// review → share via the OS sheet, or discard. No upload endpoint exists.
@Riverpod(keepAlive: true)
class CrashReports extends _$CrashReports {
  @override
  List<CrashReport> build() {
    try {
      return ref.watch(crashReportStoreProvider).list();
    } on Object {
      return const []; // no app storage (tests, early startup failure)
    }
  }

  CrashReportStore get _store => ref.read(crashReportStoreProvider);

  void refresh() => state = _store.list();

  /// Reports not yet offered at launch, marked as offered so the prompt
  /// appears once per report (they stay listed until shared or discarded).
  /// Empty when crash storage is unavailable.
  List<CrashReport> takeUnseen() {
    try {
      final unseen = _store.unseen()..forEach(_store.markSeen);
      refresh();
      return unseen;
    } on Object {
      return const [];
    }
  }

  /// Copies [report] to a `.txt` in app-private temp storage and opens the
  /// share sheet (email, Files, AirDrop …). A shared report is deleted.
  Future<ShareOutcome> share(CrashReport report, {Rect? origin}) async {
    final dir = ref.read(appPathsProvider).crashShare;
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    final copy = report.file.copySync(
      '${dir.path}${Platform.pathSeparator}'
      '${kAppName.toLowerCase()}-${report.name}.txt',
    );
    final outcome = await ref
        .read(shareServiceProvider)
        .shareFile(
          copy.path,
          mimeType: 'text/plain',
          subject: '$kAppName crash report',
          origin: origin,
        );
    ref
        .read(loggerProvider)
        .info(
          'crash',
          'crash report share',
          fields: {'outcome': outcome, 'kind': report.kind},
        );
    if (outcome == ShareOutcome.shared) _store.delete(report);
    refresh();
    return outcome;
  }

  void discard(CrashReport report) {
    _store.delete(report);
    refresh();
  }

  void discardAll() {
    _store.deleteAll();
    refresh();
  }
}
