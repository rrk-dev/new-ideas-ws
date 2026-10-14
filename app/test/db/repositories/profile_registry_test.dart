import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/profiles/data/profile_providers.dart';
import 'package:vaultvoice/features/profiles/data/profile_registry.dart';
import 'package:vaultvoice/features/profiles/domain/builtin_profiles.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';

import '../../fakes/fake_clock.dart';
import '../../fakes/fake_schema_grammar_converter.dart';
import '../../helpers/test_container.dart';
import '../../unit/profiles/profile_fixtures.dart';
import '../db_test_utils.dart';

void main() {
  late VaultVoiceDatabase db;
  late FakeSchemaGrammarConverter converter;
  late ProfileRegistry registry;

  setUp(() {
    db = memoryDb();
    converter = FakeSchemaGrammarConverter();
    registry = ProfileRegistry(
      dao: db.profilesRepository,
      builtins: BuiltinProfiles.parse({
        for (final a in kBuiltinProfileAssets) a: File(a).readAsStringSync(),
      }),
      grammarConverter: converter,
      clock: FakeClock(t0),
    );
  });

  Map<String, Object?> userDef({String id = 'team-sync'}) =>
      builtinMap('meeting')..['id'] = id;

  test('built-ins come from assets and are never written to the DB', () async {
    final all = await StreamProbe(registry.watchAll()).settled;
    expect(all.map((p) => p.id), ['meeting', 'warranty', 'engineering']);
    expect(await db.profilesRepository.watchProfiles().first, isEmpty);
    final meeting = expectOk(await registry.get('meeting'));
    expect(meeting.source, ProfileSource.builtin);
  });

  test(
    'user profiles persist in the profiles table as canonical JSON',
    () async {
      final saved = expectOk(await registry.save(userDef()));
      expect(saved.source, ProfileSource.user);
      final row = expectOk(await db.profilesRepository.getProfile('team-sync'));
      expect(row.version, 1);
      expect(row.source, ProfileSource.user);
      expect(row.updatedAt, t0);
      expect(row.definition.containsKey('source'), isFalse);
      expect(jsonEncode(row.definition), jsonEncode(saved.toJson()));
      final loaded = expectOk(await registry.get('team-sync'));
      expect(
        loaded.toJson(includeSource: true),
        saved.toJson(includeSource: true),
      );
      final all = await StreamProbe(registry.watchAll()).settled;
      expect(all.map((p) => p.id).last, 'team-sync');
    },
  );

  test('saving generates grammars for schema and map_schema', () async {
    final def = userDef()
      ..['map_schema'] = {
        'type': 'object',
        'properties': {
          'decisions': {
            'type': 'array',
            'maxItems': 5,
            'items': {'type': 'string', 'maxLength': 50},
          },
        },
      };
    final saved = expectOk(await registry.save(def));
    expect(converter.requests, hasLength(2));
    final grammars = expectOk(await registry.grammarsFor(saved));
    expect(grammars.schema, startsWith('root ::='));
    expect(grammars.mapSchema, isNotNull);
    expect(converter.requests, hasLength(2), reason: 'cached on save');
    final builtin = expectOk(await registry.get('warranty'));
    expectOk(await registry.grammarsFor(builtin));
    expectOk(await registry.grammarsFor(builtin));
    expect(converter.requests, hasLength(3));
  });

  test('[PRF-01/AC2] a schema the grammar converter rejects is a validation '
      'error and nothing is stored', () async {
    converter.failWith(const NativeFailure(-3, 'grammar'));
    final result = await registry.save(userDef());
    final failure = result.failureOrNull! as ProfileValidationFailure;
    expect(failure.issues.single, startsWith('schema: the grammar converter'));
    expectErr(await db.profilesRepository.getProfile('team-sync'), 'not found');
  });

  test(
    '[PRF-01/AC2] invalid definitions are refused with every issue',
    () async {
      final def = userDef()..['instructions'] = 'x' * 2001;
      sub(props(def), 'title').remove('maxLength');
      final result = await registry.save(def);
      final failure = result.failureOrNull! as ProfileValidationFailure;
      expect(failure.message, 'profile invalid: 2 issue(s)');
      expect(
        failure.issues,
        contains(startsWith('schema.title: missing maxLength')),
      );
      expect(converter.requests, isEmpty);
    },
  );

  test(
    'ids are unique across built-in, user and enterprise profiles',
    () async {
      final clash = await registry.save(builtinMap('meeting'));
      expect(
        (clash.failureOrNull! as ProfileValidationFailure).issues.single,
        startsWith('id: is already used'),
      );
      expectOk(
        await registry.save(
          userDef(id: 'acme'),
          source: ProfileSource.enterprise,
        ),
      );
      final overwrite = await registry.save(userDef(id: 'acme'));
      expect(overwrite.failureOrNull, isA<ProfileReadOnlyFailure>());
      expect(
        (await registry.save(
          userDef(),
          source: ProfileSource.builtin,
        )).failureOrNull,
        isA<ProfileReadOnlyFailure>(),
      );
    },
  );

  test(
    'editing extraction content bumps the version; cosmetic edits do not',
    () async {
      expectOk(await registry.save(userDef()));
      final renamed = expectOk(
        await registry.save(userDef()..['name'] = 'Weekly sync'),
      );
      expect(renamed.version, 1);
      final edited = expectOk(
        await registry.save(userDef()..['instructions'] = 'Only decisions.'),
      );
      expect(edited.version, 2);
      final explicit = expectOk(
        await registry.save(
          userDef()
            ..['instructions'] = 'Only decisions.'
            ..['version'] = 7,
        ),
      );
      expect(explicit.version, 7);
      final row = expectOk(await db.profilesRepository.getProfile('team-sync'));
      expect(row.version, 7);
    },
  );

  test('duplicate creates <id>-copy-N user profiles that built-in updates '
      'never touch', () async {
    final copy = expectOk(await registry.duplicate('meeting'));
    expect(copy.id, 'meeting-copy-1');
    expect(copy.version, 1);
    expect(copy.source, ProfileSource.user);
    expect(copy.name, 'Meeting Action Items (copy)');
    expect(
      copy.extractionFingerprint,
      expectOk(await registry.get('meeting')).extractionFingerprint,
    );
    final second = expectOk(await registry.duplicate('meeting'));
    expect(second.id, 'meeting-copy-2');
    final ofCopy = expectOk(await registry.duplicate('meeting-copy-1'));
    expect(ofCopy.id, 'meeting-copy-3');
    expect(ofCopy.name, 'Meeting Action Items (copy)');
    expectErr(await registry.duplicate('missing'), 'not found');
  });

  test('copy ids stay within the 40-char limit', () {
    final long = 'a' * 40;
    expect(nextCopyId(long, {}), '${'a' * 33}-copy-1');
    expect(nextCopyId('x-copy-4', {'x-copy-1'}), 'x-copy-2');
  });

  test(
    'built-in and managed profiles cannot be deleted; user ones can',
    () async {
      expect(
        (await registry.delete('meeting')).failureOrNull,
        isA<ProfileReadOnlyFailure>(),
      );
      expectOk(
        await registry.save(
          userDef(id: 'acme'),
          source: ProfileSource.enterprise,
        ),
      );
      expect(
        (await registry.delete('acme')).failureOrNull,
        isA<ProfileReadOnlyFailure>(),
      );
      expectOk(await registry.save(userDef()));
      expect((await registry.delete('team-sync')).isOk, isTrue);
      expectErr(await registry.get('team-sync'), 'not found');
    },
  );

  test('managed updates must not downgrade', () async {
    expectOk(
      await registry.save(
        userDef(id: 'acme')..['version'] = 3,
        source: ProfileSource.enterprise,
      ),
    );
    final older = await registry.save(
      userDef(id: 'acme')..['version'] = 2,
      source: ProfileSource.enterprise,
    );
    expect(older.failureOrNull, isA<ProfileReadOnlyFailure>());
  });

  test('a stored row that no longer validates is hidden from the list and '
      'reported by get', () async {
    expectOk(await registry.save(userDef()));
    final row = expectOk(await db.profilesRepository.getProfile('team-sync'));
    expectOk(
      await db.profilesRepository.upsertProfile(
        row
            .toCompanion(false)
            .copyWith(definition: Value({...row.definition, 'tier': 'gold'})),
      ),
    );
    final all = await StreamProbe(registry.watchAll()).settled;
    expect(all.map((p) => p.id), isNot(contains('team-sync')));
    final result = await registry.get('team-sync');
    expect(result, isA<Err<Profile>>());
    expect(
      (result.failureOrNull! as ProfileValidationFailure).issues.single,
      startsWith('tier:'),
    );
  });

  test('providers wire assets, DB, converter and clock', () async {
    final container = createContainer(
      overrides: [
        ...fakeEngineOverrides(clock: FakeClock(t0)),
        vaultVoiceDatabaseProvider.overrideWithValue(db),
        schemaGrammarConverterProvider.overrideWithValue(converter),
        profileAssetLoaderProvider.overrideWithValue(
          (key) async => File(key).readAsStringSync(),
        ),
      ],
    );
    final fromContainer = await container.read(profileRegistryProvider.future);
    expect(fromContainer.builtins.ids, contains('engineering'));
    final saved = expectOk(await fromContainer.save(userDef()));
    expect(saved.id, 'team-sync');
  });
}
