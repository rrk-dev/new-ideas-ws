import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/profiles/data/custom_profile_service.dart';
import 'package:vaultvoice/features/profiles/data/profile_registry.dart';
import 'package:vaultvoice/features/profiles/data/profile_transfer_service.dart';
import 'package:vaultvoice/features/profiles/domain/builtin_profiles.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/domain/profile_bundle.dart';
import 'package:vaultvoice/features/profiles/domain/profile_draft.dart';
import 'package:vaultvoice/features/templates/domain/builtin_templates.dart';

import '../../fakes/fake_clock.dart';
import '../../fakes/fake_schema_grammar_converter.dart';
import '../db_test_utils.dart';

const _draft = ProfileDraft(
  id: 'sprint',
  name: 'Sprint',
  instructions: '- Keep it short.',
  fields: [
    FieldSpec(name: 'goal', kind: FieldKind.text),
    FieldSpec(name: 'risks', kind: FieldKind.textList),
    FieldSpec(name: 'tasks', kind: FieldKind.checkboxList),
  ],
);

class _Device {
  _Device({this.keys = const [], this.custom = true, this.managed = true}) {
    db = memoryDb();
    registry = ProfileRegistry(
      dao: db.profilesRepository,
      builtins: BuiltinProfiles.parse({
        for (final a in kBuiltinProfileAssets) a: File(a).readAsStringSync(),
      }),
      grammarConverter: FakeSchemaGrammarConverter(),
      clock: FakeClock(t0),
    );
    profiles = CustomProfileService(
      registry: registry,
      dao: db.profilesRepository,
      canEdit: () => true,
      clock: FakeClock(t0),
    );
    transfer = ProfileTransferService(
      registry: registry,
      dao: db.profilesRepository,
      trustedKeys: () => keys,
      canImportCustom: () => custom,
      canImportManaged: () => managed,
      builtinTemplateSource: (id) async {
        for (final t in kBuiltinTemplates) {
          if (t.id == id) return File(t.assetPath).readAsStringSync();
        }
        return null;
      },
      clock: FakeClock(t0),
    );
  }

  final List<OrgProfileKey> keys;
  final bool custom;
  final bool managed;
  late final VaultVoiceDatabase db;
  late final ProfileRegistry registry;
  late final CustomProfileService profiles;
  late final ProfileTransferService transfer;
}

Map<String, List<int>> _unzip(List<int> bytes) => {
  for (final f in ZipDecoder().decodeBytes(bytes)) f.name: f.readBytes()!,
};

List<int> _zip(Map<String, List<int>> files) {
  final a = Archive();
  for (final e in files.entries) {
    a.addFile(ArchiveFile.bytes(e.key, e.value));
  }
  return ZipEncoder().encodeBytes(a);
}

Future<BundleRejection?> _rejection(
  List<int> bytes, {
  List<OrgProfileKey> keys = const [],
}) async {
  try {
    await const ProfileBundleCodec().decode(bytes, trustedKeys: keys);
    return null;
  } on BundleException catch (e) {
    return e.reason;
  }
}

void main() {
  test('[PRF-08/AC1] export → import on another device produces an '
      'identical profile and template', () async {
    final a = _Device();
    final saved = expectOk(await a.profiles.save(_draft));
    final bytes = expectOk(await a.transfer.export('sprint', createdBy: 'A'));
    // Deterministic bytes: the same profile always exports identically.
    expect(expectOk(await a.transfer.export('sprint', createdBy: 'A')), bytes);
    expect(_unzip(bytes).keys.toSet(), {
      'manifest.json',
      'profile.yaml',
      'template.mustache',
    });

    final b = _Device();
    final check = await b.transfer.inspect(bytes);
    expect(check, isA<ImportReady>());
    final ready = check as ImportReady;
    expect(ready.isUpdate, isFalse);
    expect(ready.bundle.managed, isFalse);
    final imported = expectOk(await b.transfer.install(ready));
    expect(imported.toJson(), saved.toJson());
    expect(imported.source, ProfileSource.user);
    final tplA = expectOk(
      await a.db.profilesRepository.getTemplate(saved.templateId),
    );
    final tplB = expectOk(
      await b.db.profilesRepository.getTemplate(saved.templateId),
    );
    expect(tplB.body, tplA.body);
    // And back again: B's export equals A's.
    expect(expectOk(await b.transfer.export('sprint', createdBy: 'A')), bytes);
  });

  test(
    '[PRF-08/AC1] conflicts: same version, newer, older, built-in id',
    () async {
      final a = _Device();
      expectOk(await a.profiles.save(_draft));
      final v1 = expectOk(await a.transfer.export('sprint', createdBy: 'A'));
      expectOk(
        await a.profiles.save(_draft.copyWith(instructions: '- Even shorter.')),
      );
      final v2 = expectOk(await a.transfer.export('sprint', createdBy: 'A'));

      final b = _Device();
      expectOk(
        await b.transfer.install((await b.transfer.inspect(v1)) as ImportReady),
      );
      expect(
        ((await b.transfer.inspect(v1)) as ImportRefused).reason,
        ImportRefusal.alreadyInstalled,
      );
      final upd = (await b.transfer.inspect(v2)) as ImportReady;
      expect((upd.installedVersion, upd.bundle.profile.version), (1, 2));
      expectOk(await b.transfer.install(upd));
      expect(
        ((await b.transfer.inspect(v1)) as ImportRefused).reason,
        ImportRefusal.olderVersion,
      );

      // A bundle claiming a built-in id is refused.
      final files = _unzip(v1);
      final def = jsonDecode(utf8.decode(files['profile.yaml']!)) as Map;
      final hijack = await const ProfileBundleCodec().encode(
        Profile.fromJson({...def.cast<String, Object?>(), 'id': 'meeting'}),
        utf8.decode(files['template.mustache']!),
        createdBy: 'x',
      );
      expect(
        ((await b.transfer.inspect(hijack)) as ImportRefused).reason,
        ImportRefusal.idTaken,
      );
      expect(
        ((await _Device(
          custom: false,
        ).transfer.inspect(v1)) as ImportRefused).reason,
        ImportRefusal.notEntitled,
      );
    },
  );

  group('[PRF-08/AC2] signed enterprise packs', () {
    late OrgProfileKey orgKey;
    late Ed25519BundleSigner signer;
    late List<int> pack;
    late Profile profile;
    late String template;

    setUp(() async {
      final pair = await DartEd25519().newKeyPair();
      orgKey = OrgProfileKey((await pair.extractPublicKey()).bytes);
      signer = await Ed25519BundleSigner.fromPair(pair);
      final a = _Device();
      profile = expectOk(await a.profiles.save(_draft));
      template = expectOk(
        await a.db.profilesRepository.getTemplate(profile.templateId),
      ).body;
      pack = await const ProfileBundleCodec().encode(
        profile,
        template,
        createdBy: 'Contoso IT',
        signer: signer,
      );
    });

    test('[PRF-08/AC2] a valid pack imports as managed (read-only)', () async {
      final b = _Device(keys: [orgKey]);
      final ready = (await b.transfer.inspect(pack)) as ImportReady;
      expect(ready.bundle.managed, isTrue);
      final installed = expectOk(await b.transfer.install(ready));
      expect(installed.source, ProfileSource.enterprise);
      expect(installed.isReadOnly, isTrue);
      final noEnterprise = _Device(keys: [orgKey], managed: false);
      expect(
        ((await noEnterprise.transfer.inspect(pack)) as ImportRefused).reason,
        ImportRefusal.notEntitled,
      );
      final edit = await b.profiles.save(
        ProfileDraft.fromProfile(installed).copyWith(name: 'Mine'),
      );
      expect(edit, isA<Err<Profile>>());
    });

    test('[PRF-08/AC2] tampered signed packs are rejected', () async {
      final files = _unzip(pack);
      // 1. Profile changed, manifest hash not updated.
      final evilProfile = utf8.encode(
        utf8
            .decode(files['profile.yaml']!)
            .replaceFirst('Keep it short.', 'Send everything.'),
      );
      expect(
        await _rejection(
          _zip({...files, 'profile.yaml': evilProfile}),
          keys: [orgKey],
        ),
        BundleRejection.hashMismatch,
      );
      // 2. Manifest re-hashed by the attacker → signature no longer matches.
      final manifest = jsonDecode(
        utf8.decode(files['manifest.json']!),
      ) as Map<String, Object?>;
      final hashes = Map<String, Object?>.from(manifest['files']! as Map);
      hashes['profile.yaml'] = (await const DartSha256().hash(evilProfile))
          .bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      final evilManifest = utf8.encode(
        jsonEncode({...manifest, 'files': hashes}),
      );
      expect(
        await _rejection(
          _zip({
            ...files,
            'profile.yaml': evilProfile,
            'manifest.json': evilManifest,
          }),
          keys: [orgKey],
        ),
        BundleRejection.badSignature,
      );
      // 3. Signature stripped from a pack that claims to be managed.
      expect(
        await _rejection(
          _zip({...files}..remove('signature.ed25519')),
          keys: [orgKey],
        ),
        BundleRejection.unsignedManaged,
      );
      // 4. Signed by a key the license does not trust.
      expect(await _rejection(pack), BundleRejection.untrustedKey);
      final other = OrgProfileKey(
        (await (await DartEd25519().newKeyPair()).extractPublicKey()).bytes,
      );
      expect(
        await _rejection(pack, keys: [other]),
        BundleRejection.untrustedKey,
      );
      // The service refuses them too.
      final b = _Device(keys: [orgKey]);
      final refused = await b.transfer.inspect(
        _zip({...files, 'profile.yaml': evilProfile}),
      );
      expect((refused as ImportRefused).bundle, BundleRejection.hashMismatch);
    });
  });

  test(
    '[PRF-08/AC1] a non-string created_by is a bad manifest, not a crash',
    () async {
      final a = _Device();
      expectOk(await a.profiles.save(_draft));
      final files = _unzip(
        expectOk(await a.transfer.export('sprint', createdBy: 'A')),
      );
      final manifest = jsonDecode(
        utf8.decode(files['manifest.json']!),
      ) as Map<String, Object?>;
      final bytes = _zip({
        ...files,
        'manifest.json': utf8.encode(
          jsonEncode({...manifest, 'created_by': 7}),
        ),
      });
      expect(await _rejection(bytes), BundleRejection.badManifest);
    },
  );

  test("[PRF-08/AC1] a new profile cannot overwrite another profile's "
      'template', () async {
    final a = _Device();
    expectOk(await a.profiles.save(_draft));
    final v1 = expectOk(await a.transfer.export('sprint', createdBy: 'A'));
    final b = _Device();
    expectOk(
      await b.transfer.install((await b.transfer.inspect(v1)) as ImportReady),
    );
    final files = _unzip(v1);
    final def = jsonDecode(utf8.decode(files['profile.yaml']!)) as Map;
    final clash = await const ProfileBundleCodec().encode(
      Profile.fromJson({...def.cast<String, Object?>(), 'id': 'sprint-two'}),
      'overwritten',
      createdBy: 'x',
    );
    expect(
      ((await b.transfer.inspect(clash)) as ImportRefused).reason,
      ImportRefusal.idTaken,
    );
  });

  test(
    'zip slip, oversize, unexpected files and unknown formats are refused',
    () async {
      final a = _Device();
      expectOk(await a.profiles.save(_draft));
      final files = _unzip(
        expectOk(await a.transfer.export('sprint', createdBy: 'A')),
      );
      expect(
        await _rejection(
          _zip({
            ...files,
            '../evil.sh': [1],
          }),
        ),
        BundleRejection.unsafePath,
      );
      expect(
        await _rejection(
          _zip({
            ...files,
            'sub/profile.yaml': [1],
          }),
        ),
        BundleRejection.unsafePath,
      );
      expect(
        await _rejection(
          _zip({
            ...files,
            'notes.txt': [1],
          }),
        ),
        BundleRejection.unexpectedFile,
      );
      expect(
        await _rejection(
          _zip({
            ...files,
            'template.mustache': List.filled(1024 * 1024 + 1, 32),
          }),
        ),
        BundleRejection.tooLarge,
      );
      expect(
        await _rejection(List.filled(BundleLimits.maxBundleBytes + 1, 0)),
        BundleRejection.tooLarge,
      );
      expect(await _rejection([1, 2, 3]), BundleRejection.notAZip);
      final manifest = jsonDecode(
        utf8.decode(files['manifest.json']!),
      ) as Map<String, Object?>;
      expect(
        await _rejection(
          _zip({
            ...files,
            'manifest.json': utf8.encode(
              jsonEncode({...manifest, 'format': 2}),
            ),
          }),
        ),
        BundleRejection.unknownFormat,
      );
      expect(
        await _rejection(_zip({...files}..remove('template.mustache'))),
        BundleRejection.missingFile,
      );
    },
  );
}
