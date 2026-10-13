import 'package:flutter/services.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vaultvoice/features/export/data/pigeon/bookmark_api.g.dart';

/// In-memory stand-in for the Swift `BookmarkHostApiImpl` (EXP-04).
///
/// Bookmarks are opaque strings that resolve to a folder id via
/// [bookmarks] (the way iOS resolves bookmark data to a URL). Mirrors the
/// host's behaviour: stale bookmarks are refreshed in `checkAccess`, iCloud
/// items in [notDownloaded] are never overwritten (download started +
/// `unavailable`), errors use the shared codes.
class FakeBookmarkHostApi extends Fake implements BookmarkHostApi {
  /// bookmark -> folder id. Missing = unresolvable (folder deleted/app
  /// reinstalled) → revoked.
  final Map<String, String> bookmarks = {};

  /// Bookmarks iOS reports as stale.
  final Set<String> stale = {};

  /// Folder ids that are unreachable (provider offline).
  final Set<String> unreachable = {};

  /// folder id -> relative path -> UTF-8 bytes.
  final Map<String, Map<String, Uint8List>> files = {};

  /// folder id -> folders.
  final Map<String, Set<String>> dirs = {};

  /// `folderId/relativePath` of iCloud items that are only placeholders.
  final Set<String> notDownloaded = {};

  /// `folderId/relativePath` for which a download was started.
  final List<String> downloadsStarted = [];

  /// What the next [pickFolder] returns (null = cancelled).
  BookmarkFolder? nextPick;

  int calls = 0;

  /// Number of [pickFolder] calls (pickers shown).
  int picks = 0;

  /// Registers a picked folder reachable through [bookmark].
  void addFolder(String bookmark, String folderId) {
    bookmarks[bookmark] = folderId;
    files.putIfAbsent(folderId, () => {});
    dirs.putIfAbsent(folderId, () => {});
  }

  String _folder(String bookmark) {
    final id = bookmarks[bookmark];
    if (id == null) {
      throw PlatformException(code: 'revoked', message: 'unresolvable');
    }
    if (unreachable.contains(id)) {
      throw PlatformException(code: 'unavailable', message: 'offline');
    }
    return id;
  }

  @override
  Future<BookmarkFolder?> pickFolder() async {
    calls++;
    picks++;
    return nextPick;
  }

  @override
  Future<BookmarkAccess> checkAccess(String bookmark) async {
    calls++;
    final id = bookmarks[bookmark];
    if (id == null) {
      return BookmarkAccess(status: BookmarkAccessStatus.revoked);
    }
    String? refreshed;
    if (stale.contains(bookmark)) {
      refreshed = '$bookmark+fresh';
      bookmarks[refreshed] = id;
    }
    return BookmarkAccess(
      status: unreachable.contains(id)
          ? BookmarkAccessStatus.unavailable
          : BookmarkAccessStatus.ok,
      refreshedBookmark: refreshed,
    );
  }

  @override
  Future<bool> exists(String bookmark, String relativePath) async {
    calls++;
    final id = _folder(bookmark);
    return files[id]!.containsKey(relativePath) ||
        dirs[id]!.contains(relativePath) ||
        notDownloaded.contains('$id/$relativePath');
  }

  @override
  Future<String> writeFile(
    String bookmark,
    String relativePath,
    Uint8List bytes,
    bool overwrite,
  ) async {
    calls++;
    final id = _folder(bookmark);
    final key = '$id/$relativePath';
    final present =
        files[id]!.containsKey(relativePath) || notDownloaded.contains(key);
    if (present && !overwrite) {
      throw PlatformException(code: 'exists', message: 'exists');
    }
    if (notDownloaded.contains(key)) {
      downloadsStarted.add(key);
      throw PlatformException(code: 'unavailable', message: 'placeholder');
    }
    final segs = relativePath.split('/');
    for (var i = 1; i < segs.length; i++) {
      dirs[id]!.add(segs.sublist(0, i).join('/'));
    }
    files[id]![relativePath] = Uint8List.fromList(bytes);
    return 'file:///private/var/mobile/$id/$relativePath';
  }

  @override
  Future<void> mkdirs(String bookmark, String relativePath) async {
    calls++;
    final id = _folder(bookmark);
    final segs = relativePath.split('/');
    for (var i = 1; i <= segs.length; i++) {
      dirs[id]!.add(segs.sublist(0, i).join('/'));
    }
  }

  @override
  Future<bool> delete(String bookmark, String relativePath) async {
    calls++;
    final id = _folder(bookmark);
    return files[id]!.remove(relativePath) != null;
  }

  @override
  Future<List<BookmarkEntry>> list(String bookmark, String relativePath) async {
    calls++;
    final id = _folder(bookmark);
    if (relativePath.isNotEmpty && !dirs[id]!.contains(relativePath)) {
      throw PlatformException(code: 'not_found', message: 'missing');
    }
    final prefix = relativePath.isEmpty ? '' : '$relativePath/';
    final out = <String, bool>{};
    for (final p in [...files[id]!.keys, ...dirs[id]!]) {
      if (!p.startsWith(prefix) || p == relativePath) continue;
      final rest = p.substring(prefix.length).split('/');
      out[rest.first] =
          (out[rest.first] ?? false) ||
          rest.length > 1 ||
          dirs[id]!.contains(p);
    }
    return [
      for (final e in out.entries)
        BookmarkEntry(name: e.key, isDirectory: e.value),
    ];
  }

  @override
  Future<String> appDocumentsPath() async {
    calls++;
    return '/var/mobile/Containers/Data/Application/X/Documents';
  }
}
