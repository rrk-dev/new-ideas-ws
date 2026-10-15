import 'dart:convert';
import 'dart:io';

import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/domain/profile_codec.dart';

/// Reads a built-in profile asset from disk (tests run with cwd = `app/`).
String builtinYaml(String id) =>
    File('assets/profiles/$id.yaml').readAsStringSync();

/// Built-in profile [id], parsed and validated.
Profile builtinProfile(String id) => ProfileCodec.parseYaml(
  builtinYaml(id),
  profileSource: ProfileSource.builtin,
).profile!;

/// A fresh, mutable decoded copy of built-in profile [id].
Map<String, Object?> builtinMap(String id) {
  final (map, issues) = ProfileCodec.decodeYaml(builtinYaml(id));
  if (map == null) throw StateError('fixture $id invalid: $issues');
  // Deep copy so tests can mutate freely.
  return jsonDecode(jsonEncode(map)) as Map<String, Object?>;
}

/// Shorthand for nested lookups in decoded definitions.
Map<String, Object?> sub(Map<String, Object?> m, String key) =>
    m[key]! as Map<String, Object?>;

/// The meeting schema's `properties` map.
Map<String, Object?> props(Map<String, Object?> def) =>
    sub(sub(def, 'schema'), 'properties');

/// The repo's default meeting template (vv-markdown-vault-export asset).
String meetingTemplate() => File(
  '../.agents/skills/vv-markdown-vault-export/assets/meeting-default.mustache',
).readAsStringSync();
