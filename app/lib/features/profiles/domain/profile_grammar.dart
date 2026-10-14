import 'dart:convert';

import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';

/// Converts a profile output schema (canonical JSON) to a GBNF grammar.
///
/// The real implementation (LLM-05) calls `vv_json_schema_to_gbnf` in the
/// native bridge (llama.cpp's json-schema-to-grammar compiled as `vv_jsg`).
/// A conversion failure is a profile validation error.
abstract interface class SchemaGrammarConverter {
  Future<Result<String>> toGbnf(String schemaJson);
}

/// Grammars of one profile version (`schema` and optional `map_schema`).
class ProfileGrammars {
  const ProfileGrammars({required this.schema, this.mapSchema});

  final String schema;
  final String? mapSchema;
}

/// Grammars generated on save/import (never on every run), keyed by
/// `(id, version)` plus a fingerprint of the schemas so an edited schema
/// never reuses a stale grammar.
///
/// In-memory for now; LLM-05 persists it next to the profile (follow-up).
class ProfileGrammarCache {
  final Map<String, ProfileGrammars> _entries = {};

  static String _key(Profile p) =>
      '${p.id}@${p.version}#'
      '${jsonEncode([p.schema.toJson(), p.mapSchema?.toJson()]).hashCode}';

  ProfileGrammars? get(Profile profile) => _entries[_key(profile)];

  void put(Profile profile, ProfileGrammars grammars) =>
      _entries[_key(profile)] = grammars;

  /// Drops every cached version of [id].
  void evict(String id) =>
      _entries.removeWhere((key, _) => key.startsWith('$id@'));
}
