import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:vaultvoice/core/platform/clock.dart';

/// Which handler wrote a crash report.
enum CrashKind {
  /// Native signal handler (`native/bridge/vv_crash.c`): the process died.
  native,

  /// Dart error boundary: an uncaught Dart error (the app kept running).
  dart,
}

/// A crash report stored on the device, waiting for the user to review it.
@immutable
final class CrashReport {
  const CrashReport({
    required this.file,
    required this.kind,
    required this.createdAt,
    required this.seen,
  });

  final File file;
  final CrashKind kind;

  /// UTC time the crash was recorded (from the file name).
  final DateTime createdAt;

  /// Whether the user was already offered this report on a launch.
  final bool seen;

  /// File name (`native-20261013T101500123Z.vvcrash`); no user content.
  String get name => file.uri.pathSegments.last;

  int get bytes => file.existsSync() ? file.lengthSync() : 0;

  String readText() => file.readAsStringSync();

  @override
  bool operator ==(Object other) =>
      other is CrashReport && other.file.path == file.path;

  @override
  int get hashCode => file.path.hashCode;
}

/// App-private crash report files under `<appSupport>/vv/crash/` (REL-02).
///
/// Nothing here touches the network: reports leave the device only through
/// the share sheet after the user reviewed them.
class CrashReportStore {
  CrashReportStore(
    this.directory, {
    this.clock = const SystemClock(),
    this.maxReports = 10,
  });

  static const nativeExtension = '.vvcrash';
  static const dartExtension = '.vvdart';
  static const _seenSuffix = '.seen';
  static const currentNativeName = 'native-current$nativeExtension';

  final Directory directory;
  final Clock clock;

  /// Oldest reports beyond this count are deleted.
  final int maxReports;

  static final _namePattern = RegExp(
    r'^(native|dart)-(\d{8}T\d{9}Z)(?:-\d+)?\.(vvcrash|vvdart)$',
  );

  /// File the native handler keeps open for the current run (empty = no
  /// crash so far).
  File get currentNativeFile => File(_path(currentNativeName));

  void ensureDirectory() => directory.createSync(recursive: true);

  /// Moves a non-empty native report left by the previous run aside so it
  /// can be offered to the user. Must run BEFORE the handler is installed
  /// for this run (installing truncates [currentNativeFile]).
  CrashReport? harvestNative() {
    final current = currentNativeFile;
    if (!current.existsSync() || current.lengthSync() == 0) return null;
    final crashedAt = current.lastModifiedSync().toUtc();
    final target = _uniqueFile('native', nativeExtension, crashedAt);
    final moved = current.renameSync(target.path);
    _prune();
    return _parse(moved);
  }

  /// Writes a Dart error report synchronously (the process may be about to
  /// die). [content] must already be content-free.
  CrashReport writeDart(String content) {
    ensureDirectory();
    final file = _uniqueFile('dart', dartExtension, clock.now().toUtc())
      ..writeAsStringSync(content, flush: true);
    _prune();
    return _parse(file)!;
  }

  /// Stored reports, newest first. Excludes the live native file.
  List<CrashReport> list() {
    if (!directory.existsSync()) return const [];
    final reports = [
      for (final f in directory.listSync().whereType<File>()) ?_parse(f),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return reports;
  }

  /// Reports not yet offered on a launch.
  List<CrashReport> unseen() => [
    for (final r in list())
      if (!r.seen) r,
  ];

  void markSeen(CrashReport report) {
    if (report.file.existsSync()) _seenMarker(report.file).createSync();
  }

  void delete(CrashReport report) {
    for (final f in [report.file, _seenMarker(report.file)]) {
      if (f.existsSync()) f.deleteSync();
    }
  }

  void deleteAll() => list().forEach(delete);

  CrashReport? _parse(File file) {
    final name = file.uri.pathSegments.last;
    final m = _namePattern.firstMatch(name);
    if (m == null) return null;
    final ts = m.group(2)!;
    final createdAt = DateTime.utc(
      int.parse(ts.substring(0, 4)),
      int.parse(ts.substring(4, 6)),
      int.parse(ts.substring(6, 8)),
      int.parse(ts.substring(9, 11)),
      int.parse(ts.substring(11, 13)),
      int.parse(ts.substring(13, 15)),
      int.parse(ts.substring(15, 18)),
    );
    return CrashReport(
      file: file,
      kind: m.group(1) == 'native' ? CrashKind.native : CrashKind.dart,
      createdAt: createdAt,
      seen: _seenMarker(file).existsSync(),
    );
  }

  File _uniqueFile(String prefix, String ext, DateTime utc) {
    final stamp = _stamp(utc);
    var file = File(_path('$prefix-$stamp$ext'));
    for (var i = 1; file.existsSync(); i++) {
      file = File(_path('$prefix-$stamp-$i$ext'));
    }
    return file;
  }

  void _prune() {
    list().skip(maxReports).forEach(delete);
  }

  File _seenMarker(File report) => File('${report.path}$_seenSuffix');

  String _path(String name) =>
      '${directory.path}${Platform.pathSeparator}$name';

  static String _stamp(DateTime utc) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${utc.year.toString().padLeft(4, '0')}${two(utc.month)}'
        '${two(utc.day)}T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}'
        '${utc.millisecond.toString().padLeft(3, '0')}Z';
  }
}
