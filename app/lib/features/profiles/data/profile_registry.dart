import 'dart:convert';

import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/repositories/profiles_repository.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/clock.dart';
import 'package:vaultvoice/features/profiles/domain/builtin_profiles.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/domain/profile_grammar.dart';
import 'package:vaultvoice/features/profiles/domain/profile_validator.dart';

/// All profiles the app can use: read-only built-ins from assets plus
/// user/enterprise profiles stored in the `profiles` table (FND-04).
///
/// Rules (profile spec): built-ins are never written to the DB; user ids
/// never collide with built-in or enterprise ids; enterprise (managed)
/// profiles are read-only for the user; "duplicate" creates a user profile
/// `<id>-copy-N`; any change to schema/instructions/examples bumps
/// `version`; grammars are generated on save, and a schema the converter
/// rejects is a validation error.
class ProfileRegistry {
  ProfileRegistry({
    required this.dao,
    required this.builtins,
    required SchemaGrammarConverter grammarConverter,
    required this.clock,
    ProfileGrammarCache? grammarCache,
    this.validator = const ProfileValidator(),
  }) : _converter = grammarConverter,
       _cache = grammarCache ?? ProfileGrammarCache();

  final ProfilesRepository dao;
  final BuiltinProfiles builtins;
  final SchemaGrammarConverter _converter;
  final Clock clock;
  final ProfileGrammarCache _cache;
  final ProfileValidator validator;

  /// Built-ins first (asset order), then stored profiles by id. Stored rows
  /// that no longer validate (e.g. after a spec tightening) are left out;
  /// [get] reports why.
  Stream<List<Profile>> watchAll() => dao.watchProfiles().map(
    (rows) => [
      ...builtins.all,
      for (final row in rows) ?_fromRow(row).valueOrNull,
    ],
  );

  /// The current version of profile [id].
  Future<Result<Profile>> get(String id) async {
    if (builtins[id] case final builtin?) return Ok(builtin);
    final row = await dao.getProfile(id);
    return switch (row) {
      Ok(:final value) => _fromRow(value),
      Err(:final failure) => Err(failure),
    };
  }

  /// Validates and stores a user (or, for PRF-08 imports, enterprise)
  /// profile definition, generating its grammars first.
  ///
  /// Updating an existing profile whose extraction-relevant content changed
  /// without a version bump stores `version = previous + 1`.
  Future<Result<Profile>> save(
    Map<String, Object?> definition, {
    ProfileSource source = ProfileSource.user,
  }) async {
    if (source == ProfileSource.builtin) {
      return const Err(
        ProfileReadOnlyFailure('built-in profiles live in assets'),
      );
    }
    final id = definition['id'];
    final existing = id is String ? await _existingRow(id) : null;
    if (existing != null && existing.source != source) {
      return Err(
        ProfileReadOnlyFailure(
          existing.source == ProfileSource.enterprise
              ? 'managed profile is read-only; duplicate it to edit'
              : 'id is used by a ${existing.source.name} profile',
        ),
      );
    }
    final rowIds = await _storedIds();
    final taken = {...builtins.ids, ...rowIds}..remove(existing?.id);
    final validation = validator.validate(
      definition,
      source: source,
      takenIds: taken,
    );
    var profile = validation.profile;
    if (profile == null) {
      return Err(
        ProfileValidationFailure([
          for (final i in validation.issues) i.toString(),
        ]),
      );
    }

    if (existing != null) {
      final previous = _fromRow(existing).valueOrNull;
      if (source == ProfileSource.enterprise &&
          profile.version < existing.version) {
        return const Err(
          ProfileReadOnlyFailure('older managed profile version refused'),
        );
      }
      final changed =
          previous == null ||
          previous.extractionFingerprint != profile.extractionFingerprint;
      if (profile.version <= existing.version) {
        profile = profile.copyWith(
          version: changed ? existing.version + 1 : existing.version,
        );
      }
    }

    final grammars = await _compile(profile);
    if (grammars case Err(:final failure)) return Err(failure);

    final stored = await dao.upsertProfile(
      ProfilesCompanion.insert(
        id: profile.id,
        version: profile.version,
        source: source,
        definition: profile.toJson(),
        updatedAt: clock.now(),
      ),
    );
    if (stored case Err(:final failure)) return Err(failure);
    _cache
      ..evict(profile.id)
      ..put(profile, grammars.valueOrNull!);
    return Ok(profile);
  }

  /// Copies profile [id] (any source) into a new editable user profile
  /// `<id>-copy-N` at version 1, so built-in updates never overwrite it.
  Future<Result<Profile>> duplicate(String id) async {
    final original = await get(id);
    if (original case Err(:final failure)) return Err(failure);
    final source = original.valueOrNull!;
    final taken = {...builtins.ids, ...await _storedIds()};
    final copyId = nextCopyId(source.id, taken);
    final copyName = _copyName(source.name);
    return await save(
      source.copyWith(id: copyId, version: 1, name: copyName).toJson(),
    );
  }

  /// Deletes user profile [id]; built-in and managed profiles cannot be
  /// deleted here.
  Future<Result<void>> delete(String id) async {
    if (builtins[id] != null) {
      return const Err(ProfileReadOnlyFailure('built-in profile'));
    }
    final row = await _existingRow(id);
    if (row != null && row.source == ProfileSource.enterprise) {
      return const Err(ProfileReadOnlyFailure('managed profile'));
    }
    final result = await dao.deleteProfile(id);
    if (result.isOk) _cache.evict(id);
    return result;
  }

  /// GBNF grammars for [profile] (cached per id + version + schema).
  Future<Result<ProfileGrammars>> grammarsFor(Profile profile) async {
    if (_cache.get(profile) case final cached?) return Ok(cached);
    final result = await _compile(profile);
    if (result case Ok(:final value)) _cache.put(profile, value);
    return result;
  }

  Future<Result<ProfileGrammars>> _compile(Profile profile) async {
    final main = await _converter.toGbnf(jsonEncode(profile.schema.toJson()));
    if (main case Err()) {
      return Err(ProfileValidationFailure(const [_grammarRejected]));
    }
    String? map;
    if (profile.mapSchema case final mapSchema?) {
      final result = await _converter.toGbnf(jsonEncode(mapSchema.toJson()));
      if (result case Err()) {
        return Err(
          ProfileValidationFailure(const [
            'map_schema: the grammar converter rejected this schema',
          ]),
        );
      }
      map = result.valueOrNull;
    }
    return Ok(ProfileGrammars(schema: main.valueOrNull!, mapSchema: map));
  }

  Result<Profile> _fromRow(ProfileRow row) {
    final result = validator.validate(row.definition, source: row.source);
    if (result.profile case final p?) return Ok(p);
    return Err(
      ProfileValidationFailure([for (final i in result.issues) i.toString()]),
    );
  }

  Future<ProfileRow?> _existingRow(String id) async =>
      (await dao.getProfile(id)).valueOrNull;

  Future<Set<String>> _storedIds() async {
    final rows = await dao.watchProfiles().first;
    return {for (final r in rows) r.id};
  }

  static String _copyName(String name) {
    const suffix = ' (copy)';
    if (name.endsWith(suffix)) return name;
    const max = ProfileLimits.maxName - suffix.length;
    return '${name.length > max ? name.substring(0, max) : name}$suffix';
  }
}

const String _grammarRejected =
    'schema: the grammar converter rejected this schema; simplify it '
    '(fewer nesting levels, smaller limits)';

final RegExp _copySuffix = RegExp(r'-copy-\d+$');

/// The first free `<base>-copy-N` (N ≥ 1) not in [taken], where base is
/// [id] without an existing `-copy-N` suffix, shortened so the result stays
/// within the 40-char id limit.
String nextCopyId(String id, Set<String> taken) {
  final base = id.replaceFirst(_copySuffix, '');
  for (var n = 1; ; n++) {
    final suffix = '-copy-$n';
    final room = 40 - suffix.length;
    final trimmed = base.length > room ? base.substring(0, room) : base;
    final candidate = '$trimmed$suffix';
    if (!taken.contains(candidate)) return candidate;
  }
}
