import 'package:flutter/services.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vaultvoice/features/export/data/pigeon/saf_api.g.dart';

/// In-memory stand-in for the Kotlin `SafHostApiImpl` (EXP-03).
///
/// Models what the device does: persisted grants live in [persisted] (they
/// outlive any Dart object, like the OS grant table), files live per tree in
/// [files], overwrite truncates, and errors are `PlatformException`s with
/// the same codes as the Kotlin side.
class FakeSafHostApi extends Fake implements SafHostApi {
  /// Tree URIs with a persisted read/write grant.
  final Set<String> persisted = {};

  /// treeUri -> relative path -> bytes.
  final Map<String, Map<String, Uint8List>> files = {};

  /// treeUri -> folders created (relative paths).
  final Map<String, Set<String>> dirs = {};

  /// Trees whose volume is gone (SD card removed).
  final Set<String> unmounted = {};

  /// What the next [pickTree] returns (null = user cancelled).
  SafTree? nextPick;

  /// Arguments of every [pickTree] call.
  final List<String?> pickCalls = [];

  /// Trees released via [releaseTree].
  final List<String> released = [];

  /// Last arguments passed to [writeFile].
  ({String tree, String path, Uint8List bytes, bool overwrite})? lastWrite;

  /// Number of host calls (to prove validation happens before the channel).
  int calls = 0;

  /// Grants permission to [treeUri] as if the user had picked it.
  void grant(String treeUri) {
    persisted.add(treeUri);
    files.putIfAbsent(treeUri, () => {});
    dirs.putIfAbsent(treeUri, () => {});
  }

  void _requireWritable(String tree) {
    if (!persisted.contains(tree)) {
      throw PlatformException(code: 'revoked', message: 'no grant');
    }
    if (unmounted.contains(tree)) {
      throw PlatformException(code: 'unavailable', message: 'gone');
    }
  }

  @override
  Future<SafTree?> pickTree(String? initialTreeUri) async {
    calls++;
    pickCalls.add(initialTreeUri);
    final pick = nextPick;
    if (pick != null) grant(pick.treeUri);
    return pick;
  }

  @override
  Future<SafAccessStatus> checkAccess(String treeUri) async {
    calls++;
    if (!persisted.contains(treeUri)) return SafAccessStatus.revoked;
    if (unmounted.contains(treeUri)) return SafAccessStatus.unavailable;
    return SafAccessStatus.ok;
  }

  @override
  Future<List<String>> persistedTrees() async {
    calls++;
    return persisted.toList();
  }

  @override
  Future<void> releaseTree(String treeUri) async {
    calls++;
    released.add(treeUri);
    persisted.remove(treeUri);
  }

  @override
  Future<bool> exists(String treeUri, String relativePath) async {
    calls++;
    _requireWritable(treeUri);
    return files[treeUri]!.containsKey(relativePath) ||
        dirs[treeUri]!.contains(relativePath);
  }

  @override
  Future<String> writeFile(
    String treeUri,
    String relativePath,
    Uint8List bytes,
    bool overwrite,
  ) async {
    calls++;
    lastWrite = (
      tree: treeUri,
      path: relativePath,
      bytes: bytes,
      overwrite: overwrite,
    );
    _requireWritable(treeUri);
    final tree = files[treeUri]!;
    if (dirs[treeUri]!.contains(relativePath)) {
      throw PlatformException(code: 'invalid', message: 'is a folder');
    }
    if (tree.containsKey(relativePath) && !overwrite) {
      throw PlatformException(code: 'exists', message: 'exists');
    }
    final segs = relativePath.split('/');
    for (var i = 1; i < segs.length; i++) {
      dirs[treeUri]!.add(segs.sublist(0, i).join('/'));
    }
    // Truncating write ("wt"): the old content is replaced entirely.
    tree[relativePath] = Uint8List.fromList(bytes);
    return '$treeUri/document/$relativePath';
  }

  @override
  Future<void> mkdirs(String treeUri, String relativePath) async {
    calls++;
    _requireWritable(treeUri);
    final segs = relativePath.split('/');
    for (var i = 1; i <= segs.length; i++) {
      dirs[treeUri]!.add(segs.sublist(0, i).join('/'));
    }
  }

  @override
  Future<bool> delete(String treeUri, String relativePath) async {
    calls++;
    _requireWritable(treeUri);
    return files[treeUri]!.remove(relativePath) != null;
  }

  @override
  Future<List<SafEntry>> list(String treeUri, String relativePath) async {
    calls++;
    _requireWritable(treeUri);
    final prefix = relativePath.isEmpty ? '' : '$relativePath/';
    if (relativePath.isNotEmpty && !dirs[treeUri]!.contains(relativePath)) {
      throw PlatformException(code: 'not_found', message: 'missing');
    }
    final out = <String, bool>{};
    for (final p in [...files[treeUri]!.keys, ...dirs[treeUri]!]) {
      if (!p.startsWith(prefix) || p == relativePath) continue;
      final rest = p.substring(prefix.length).split('/');
      out[rest.first] =
          (out[rest.first] ?? false) ||
          rest.length > 1 ||
          dirs[treeUri]!.contains(p);
    }
    return [
      for (final e in out.entries) SafEntry(name: e.key, isDirectory: e.value),
    ];
  }

  @override
  Future<String> appLocalVaultPath() async {
    calls++;
    return '/data/user/0/app/files/vault';
  }
}
