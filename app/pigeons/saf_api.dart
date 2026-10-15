// Pigeon definition for the Android Storage Access Framework host API
// (EXP-03). Regenerate after editing (from app/):
//   fvm dart run pigeon --input pigeons/saf_api.dart
//   fvm dart format lib/features/export/data/pigeon/saf_api.g.dart
//
// Verified against pigeon 29.0.8.
//
// Error contract: every host method may fail with a `PlatformException` whose
// `code` is one of the `SafErrorCodes` constants on the Dart side
// (`lib/features/export/data/saf_vault_writer.dart`):
//   revoked     - no persisted write grant for the tree (re-pick needed)
//   unavailable - provider/volume gone (SD card removed, provider crashed)
//   exists      - target exists and overwrite == false
//   not_found   - path does not exist (delete/list)
//   invalid     - the relative path or tree URI is malformed
//   busy        - a picker is already open
//   io          - any other I/O error (message is content-free)
// Messages never contain file names or paths (vv-privacy-security).

// Pigeon maps positional parameters 1:1 to Kotlin/Swift signatures.
// ignore_for_file: avoid_positional_boolean_parameters

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/features/export/data/pigeon/saf_api.g.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        'android/app/src/main/kotlin/com/vaultvoice/vaultvoice/saf/SafApi.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'com.vaultvoice.vaultvoice.saf',
      errorClassName: 'SafFlutterError',
    ),
    dartPackageName: 'vaultvoice',
  ),
)
/// Result of the access check for a persisted tree URI.
enum SafAccessStatus { ok, revoked, unavailable }

/// A folder the user picked with `ACTION_OPEN_DOCUMENT_TREE`.
class SafTree {
  SafTree({required this.treeUri, this.displayName});

  /// `content://` tree URI; stored as `vault_targets.handle`.
  String treeUri;

  /// Folder name shown in the UI (may be null for some providers).
  String? displayName;
}

/// One child entry of a directory inside the tree.
class SafEntry {
  SafEntry({required this.name, required this.isDirectory});

  String name;
  bool isDirectory;
}

@HostApi()
abstract class SafHostApi {
  /// Opens the system folder picker and persists read/write permission for
  /// the picked tree. [initialTreeUri] pre-selects the previous folder when
  /// re-granting. Returns null when the user cancels.
  @asyncCallback
  SafTree? pickTree(String? initialTreeUri);

  /// Checks the persisted grant and that the tree root is reachable.
  @asyncCallback
  SafAccessStatus checkAccess(String treeUri);

  /// Tree URIs with a persisted read+write grant (survives reboot).
  List<String> persistedTrees();

  /// Releases the persisted grant (folder no longer used as a target).
  void releaseTree(String treeUri);

  /// Whether [relativePath] (`a/b/note.md`) exists inside the tree.
  @asyncCallback
  bool exists(String treeUri, String relativePath);

  /// Writes [bytes] to [relativePath], creating missing sub-folders.
  /// Existing files are replaced (truncate, never stale bytes) only when
  /// [overwrite] is true. Returns the document URI of the written file.
  @asyncCallback
  String writeFile(
    String treeUri,
    String relativePath,
    Uint8List bytes,
    bool overwrite,
  );

  /// The bytes of the file at [relativePath], or null when it does not
  /// exist (EXP-05 user-edit detection). Fails with `invalid` for a folder.
  @asyncCallback
  Uint8List? readFile(String treeUri, String relativePath);

  /// Creates [relativePath] and all missing parent folders.
  @asyncCallback
  void mkdirs(String treeUri, String relativePath);

  /// Deletes the file at [relativePath]. Returns false if it did not exist.
  @asyncCallback
  bool delete(String treeUri, String relativePath);

  /// Lists the direct children of [relativePath] ('' = tree root).
  @asyncCallback
  List<SafEntry> list(String treeUri, String relativePath);

  /// Absolute path of the app-private fallback vault folder.
  String appLocalVaultPath();
}
