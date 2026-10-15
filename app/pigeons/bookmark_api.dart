// Pigeon definition for the iOS security-scoped bookmark host API (EXP-04).
// Regenerate after editing (from app/):
//   fvm dart run pigeon --input pigeons/bookmark_api.dart
//   fvm dart format lib/features/export/data/pigeon/bookmark_api.g.dart
//
// Verified against pigeon 29.0.8.
//
// Error contract: same `PlatformException.code`s as the SAF API
// (`VaultErrorCodes` in lib/features/export/data/vault_platform_errors.dart):
//   revoked     - bookmark cannot be resolved / access refused (re-pick)
//   unavailable - folder temporarily unreachable, or an iCloud item is not
//                 downloaded yet (download was started; retry via outbox)
//   exists      - target exists and overwrite == false
//   not_found   - path does not exist (list)
//   invalid     - malformed bookmark or relative path
//   busy        - a picker is already open
//   io          - any other I/O error (message is content-free)

// Pigeon maps positional parameters 1:1 to Kotlin/Swift signatures.
// ignore_for_file: avoid_positional_boolean_parameters

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/features/export/data/pigeon/bookmark_api.g.dart',
    dartOptions: DartOptions(),
    swiftOut: 'ios/Runner/BookmarkApi.g.swift',
    swiftOptions: SwiftOptions(errorClassName: 'BookmarkPigeonError'),
    dartPackageName: 'vaultvoice',
  ),
)
/// Result of resolving a bookmark and probing the folder.
enum BookmarkAccessStatus { ok, revoked, unavailable }

/// A folder picked with `UIDocumentPickerViewController` (folder mode).
class BookmarkFolder {
  BookmarkFolder({required this.bookmark, this.displayName});

  /// Base64 bookmark data; stored as `vault_targets.handle`.
  String bookmark;

  /// Folder name shown in the UI.
  String? displayName;
}

/// Access check result. When the bookmark was stale, iOS re-created it and
/// [refreshedBookmark] must replace the stored handle.
class BookmarkAccess {
  BookmarkAccess({required this.status, this.refreshedBookmark});

  BookmarkAccessStatus status;
  String? refreshedBookmark;
}

/// One child entry of a directory inside the bookmarked folder.
class BookmarkEntry {
  BookmarkEntry({required this.name, required this.isDirectory});

  String name;
  bool isDirectory;
}

@HostApi()
abstract class BookmarkHostApi {
  /// Presents the folder picker and returns a bookmark for the picked
  /// folder, or null when the user cancels.
  @asyncCallback
  BookmarkFolder? pickFolder();

  /// Resolves [bookmark], refreshes it when stale, checks reachability.
  @asyncCallback
  BookmarkAccess checkAccess(String bookmark);

  /// Whether [relativePath] exists (coordinated read; iCloud placeholders
  /// count as existing).
  @asyncCallback
  bool exists(String bookmark, String relativePath);

  /// Coordinated, atomic write of [bytes] to [relativePath], creating
  /// missing sub-folders. Replaces an existing file only when [overwrite].
  /// Returns the file URL string.
  @asyncCallback
  String writeFile(
    String bookmark,
    String relativePath,
    Uint8List bytes,
    bool overwrite,
  );

  /// The bytes of the file at [relativePath], or null when it does not
  /// exist (EXP-05 user-edit detection). Fails with `invalid` for a folder.
  @asyncCallback
  Uint8List? readFile(String bookmark, String relativePath);

  /// Creates [relativePath] and all missing parent folders.
  @asyncCallback
  void mkdirs(String bookmark, String relativePath);

  /// Deletes the file at [relativePath]. Returns false if it did not exist.
  @asyncCallback
  bool delete(String bookmark, String relativePath);

  /// Lists the direct children of [relativePath] ('' = folder root).
  @asyncCallback
  List<BookmarkEntry> list(String bookmark, String relativePath);

  /// Absolute path of the app's `Documents/` folder (shown in Files under
  /// "On My iPhone › VaultVoice"): the default/fallback vault target.
  String appDocumentsPath();
}
