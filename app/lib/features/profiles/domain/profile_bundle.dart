import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/domain/profile_codec.dart';
import 'package:vaultvoice/features/profiles/domain/render_context.dart';
import 'package:vaultvoice/features/templates/domain/template_engine.dart';

/// `.vvprofile` bundle format (PRF-08, vv-extraction-profiles →
/// "Import/export"): a zip with exactly
/// - `profile.yaml`   the canonical definition (JSON text — valid YAML 1.2),
/// - `template.mustache` the bound Markdown template,
/// - `manifest.json`  `{format: 1, id, version, created_by, managed,
///                     files: {name: sha256}}`,
/// - `signature.ed25519` (managed packs only): `{key_id, sig}` (base64
///   Ed25519 over the exact `manifest.json` bytes) by the organization's
///   profile key from the enterprise license (LIC-03).
const int kBundleFormat = 1;

/// File extension and platform type ids (registered in Info.plist /
/// AndroidManifest.xml).
const String kBundleExtension = 'vvprofile';
const String kBundleUti = 'com.vaultvoice.profile';
const String kBundleMime = 'application/vnd.vaultvoice.profile+zip';

/// Size limits: any bundle above them is refused before parsing.
abstract final class BundleLimits {
  static const int maxBundleBytes = 2 * 1024 * 1024;
  static const int maxFileBytes = 1024 * 1024;
  static const int maxEntries = 4;
}

const String _profileFile = 'profile.yaml';
const String _templateFile = 'template.mustache';
const String _manifestFile = 'manifest.json';
const String _signatureFile = 'signature.ed25519';
const Set<String> _allowed = {
  _profileFile,
  _templateFile,
  _manifestFile,
  _signatureFile,
};

/// Why an import was refused (the UI localizes it; never contains content).
enum BundleRejection {
  tooLarge,
  notAZip,
  unsafePath,
  unexpectedFile,
  missingFile,
  unknownFormat,
  badManifest,
  hashMismatch,
  invalidProfile,
  invalidTemplate,
  idMismatch,
  unsignedManaged,
  untrustedKey,
  badSignature,
}

final class BundleException implements Exception {
  const BundleException(this.reason, [this.details = const []]);

  final BundleRejection reason;

  /// Content-free validation issues (paths/rules), e.g. for invalid profiles.
  final List<String> details;

  @override
  String toString() => 'BundleException(${reason.name})';
}

/// An organization public key allowed to sign managed packs. LIC-03 provides
/// the real keys from the installed enterprise license
/// (`org_profile_pubkey`); until then the app trusts none, so managed packs
/// are refused.
final class OrgProfileKey {
  OrgProfileKey(List<int> bytes)
    : bytes = Uint8List.fromList(bytes),
      keyId = orgKeyId(bytes) {
    if (bytes.length != 32) {
      throw ArgumentError.value(bytes.length, 'bytes', 'must be 32');
    }
  }

  final Uint8List bytes;
  final String keyId;
}

/// First 16 hex chars of sha256(public key).
String orgKeyId(List<int> rawPublicKey) =>
    crypto.sha256.convert(rawPublicKey).toString().substring(0, 16);

/// Signs managed packs (the enterprise tooling, `tools/licensing/`; tests).
abstract interface class BundleSigner {
  String get keyId;
  Future<List<int>> sign(List<int> message);
}

/// [BundleSigner] over an Ed25519 key pair.
final class Ed25519BundleSigner implements BundleSigner {
  Ed25519BundleSigner(this._pair, this.keyId);

  static Future<Ed25519BundleSigner> fromPair(SimpleKeyPair pair) async {
    final pub = await pair.extractPublicKey();
    return Ed25519BundleSigner(pair, orgKeyId(pub.bytes));
  }

  final SimpleKeyPair _pair;
  @override
  final String keyId;

  @override
  Future<List<int>> sign(List<int> message) async =>
      (await DartEd25519().sign(message, keyPair: _pair)).bytes;
}

/// A decoded, verified bundle.
final class ProfileBundle {
  const ProfileBundle({
    required this.profile,
    required this.template,
    required this.managed,
    required this.createdBy,
  });

  /// Validated profile; `source` is `enterprise` for managed packs, else
  /// `user`.
  final Profile profile;
  final String template;
  final bool managed;
  final String createdBy;
}

/// Encodes and decodes `.vvprofile` bundles.
final class ProfileBundleCodec {
  const ProfileBundleCodec({this.engine = const MarkdownTemplateEngine()});

  final MarkdownTemplateEngine engine;
  static final _ed25519 = DartEd25519();

  /// Bundle bytes for [profile] + [template]. With [signer] the pack is
  /// `managed` and signed. Output is deterministic (fixed entry order and
  /// timestamps), so the same input gives the same bytes.
  Future<Uint8List> encode(
    Profile profile,
    String template, {
    required String createdBy,
    BundleSigner? signer,
  }) async {
    final profileBytes = utf8.encode(
      '${const JsonEncoder.withIndent('  ').convert(profile.toJson())}\n',
    );
    final templateBytes = utf8.encode(template);
    final manifest = {
      'format': kBundleFormat,
      'id': profile.id,
      'version': profile.version,
      'created_by': createdBy,
      'managed': signer != null,
      'files': {
        _profileFile: _sha(profileBytes),
        _templateFile: _sha(templateBytes),
      },
    };
    final manifestBytes = utf8.encode(
      '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
    );
    final archive = Archive()
      ..addFile(_entry(_manifestFile, manifestBytes))
      ..addFile(_entry(_profileFile, profileBytes))
      ..addFile(_entry(_templateFile, templateBytes));
    if (signer != null) {
      final sig = await signer.sign(manifestBytes);
      archive.addFile(
        _entry(
          _signatureFile,
          utf8.encode(
            jsonEncode({'key_id': signer.keyId, 'sig': base64Encode(sig)}),
          ),
        ),
      );
    }
    return ZipEncoder().encodeBytes(archive);
  }

  static ArchiveFile _entry(String name, List<int> bytes) =>
      ArchiveFile.bytes(name, bytes)..lastModTime = 0;

  /// Decodes and verifies [bytes]. Throws [BundleException].
  ///
  /// Order: size cap → zip structure (only the four known names at the
  /// root: no directories, `..`, absolute or backslash paths) → per-file
  /// size → manifest → hashes → signature (managed) → profile validation →
  /// template validation against the profile.
  Future<ProfileBundle> decode(
    List<int> bytes, {
    List<OrgProfileKey> trustedKeys = const [],
  }) async {
    if (bytes.length > BundleLimits.maxBundleBytes) {
      throw const BundleException(BundleRejection.tooLarge);
    }
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    } on Object {
      throw const BundleException(BundleRejection.notAZip);
    }
    if (archive.isEmpty) {
      throw const BundleException(BundleRejection.notAZip);
    }
    if (archive.length > BundleLimits.maxEntries) {
      throw const BundleException(BundleRejection.unexpectedFile);
    }
    final files = <String, List<int>>{};
    for (final f in archive) {
      final name = f.name;
      if (name.contains('/') ||
          name.contains(r'\') ||
          name.contains('..') ||
          name.startsWith('~') ||
          name.contains(':') ||
          !f.isFile) {
        throw const BundleException(BundleRejection.unsafePath);
      }
      if (!_allowed.contains(name) || files.containsKey(name)) {
        throw const BundleException(BundleRejection.unexpectedFile);
      }
      if (f.size > BundleLimits.maxFileBytes) {
        throw const BundleException(BundleRejection.tooLarge);
      }
      final content = f.readBytes();
      if (content == null || content.length > BundleLimits.maxFileBytes) {
        throw const BundleException(BundleRejection.tooLarge);
      }
      files[name] = content;
    }
    for (final required in [_manifestFile, _profileFile, _templateFile]) {
      if (!files.containsKey(required)) {
        throw const BundleException(BundleRejection.missingFile);
      }
    }
    final manifestBytes = files[_manifestFile]!;
    final Map<String, Object?> manifest;
    try {
      manifest = jsonDecode(utf8.decode(manifestBytes)) as Map<String, Object?>;
    } on Object {
      throw const BundleException(BundleRejection.badManifest);
    }
    if (manifest['format'] != kBundleFormat) {
      throw const BundleException(BundleRejection.unknownFormat);
    }
    final hashes = manifest['files'];
    final id = manifest['id'];
    final version = manifest['version'];
    final managed = manifest['managed'];
    if (hashes is! Map<String, Object?> ||
        id is! String ||
        version is! int ||
        (managed != null && managed is! bool)) {
      throw const BundleException(BundleRejection.badManifest);
    }
    for (final name in [_profileFile, _templateFile]) {
      if (hashes[name] != _sha(files[name]!)) {
        throw const BundleException(BundleRejection.hashMismatch);
      }
    }
    final isManaged = managed == true || files.containsKey(_signatureFile);
    if (isManaged) {
      await _verifySignature(manifestBytes, files[_signatureFile], trustedKeys);
    }
    final String profileText;
    final String template;
    try {
      profileText = utf8.decode(files[_profileFile]!);
      template = utf8.decode(files[_templateFile]!);
    } on FormatException {
      throw const BundleException(BundleRejection.invalidProfile);
    }
    final result = ProfileCodec.parseYaml(
      profileText,
      profileSource: isManaged ? ProfileSource.enterprise : ProfileSource.user,
    );
    final profile = result.profile;
    if (profile == null) {
      throw BundleException(BundleRejection.invalidProfile, [
        for (final i in result.issues) '$i',
      ]);
    }
    if (profile.id != id || profile.version != version) {
      throw const BundleException(BundleRejection.idMismatch);
    }
    final templateIssues = engine.validate(
      template,
      rootShapeFor(profile),
      name: profile.templateId,
    );
    if (templateIssues.isNotEmpty) {
      throw BundleException(BundleRejection.invalidTemplate, [
        for (final i in templateIssues) '$i',
      ]);
    }
    final rawCreatedBy = manifest['created_by'];
    if (rawCreatedBy != null && rawCreatedBy is! String) {
      throw const BundleException(BundleRejection.badManifest);
    }
    final createdBy = (rawCreatedBy as String?) ?? '';
    return ProfileBundle(
      profile: profile,
      template: template,
      managed: isManaged,
      createdBy: createdBy,
    );
  }

  Future<void> _verifySignature(
    List<int> manifestBytes,
    List<int>? signatureFile,
    List<OrgProfileKey> trustedKeys,
  ) async {
    if (signatureFile == null) {
      throw const BundleException(BundleRejection.unsignedManaged);
    }
    final String keyId;
    final List<int> sig;
    try {
      final env =
          jsonDecode(utf8.decode(signatureFile)) as Map<String, Object?>;
      keyId = env['key_id']! as String;
      sig = base64Decode(env['sig']! as String);
    } on Object {
      throw const BundleException(BundleRejection.badSignature);
    }
    final key = trustedKeys.where((k) => k.keyId == keyId).firstOrNull;
    if (key == null) {
      throw const BundleException(BundleRejection.untrustedKey);
    }
    final ok = await _ed25519.verify(
      manifestBytes,
      signature: Signature(
        sig,
        publicKey: SimplePublicKey(key.bytes, type: KeyPairType.ed25519),
      ),
    );
    if (!ok) throw const BundleException(BundleRejection.badSignature);
  }

  static String _sha(List<int> bytes) =>
      crypto.sha256.convert(bytes).toString();
}
