import 'dart:convert';

import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/features/profiles/domain/profile_issue.dart';
import 'package:vaultvoice/features/profiles/domain/profile_validator.dart';
import 'package:yaml/yaml.dart';

/// Reads profile definitions from YAML (assets, `.vvprofile` bundles) or
/// JSON (DB `profiles.definition`) into plain Dart maps, then validates them.
abstract final class ProfileCodec {
  /// Decodes YAML into JSON-compatible maps/lists (key order preserved).
  /// Syntax errors become a single `yaml` issue with line and column.
  static (Map<String, Object?>?, List<ProfileIssue>) decodeYaml(String source) {
    final Object? doc;
    try {
      doc = loadYaml(source);
    } on YamlException catch (e) {
      final span = e.span;
      final where = span == null
          ? ''
          : ' at line ${span.start.line + 1}, column ${span.start.column + 1}';
      return (null, [ProfileIssue('yaml', 'invalid YAML$where')]);
    }
    final sink = IssueSink();
    final plain = _plain(doc, '', sink);
    if (!sink.isEmpty) return (null, sink.issues);
    if (plain is! Map<String, Object?>) {
      return (null, const [ProfileIssue('', 'a profile must be a YAML map')]);
    }
    return (plain, const []);
  }

  /// Decodes a JSON definition.
  static (Map<String, Object?>?, List<ProfileIssue>) decodeJson(String source) {
    final Object? doc;
    try {
      doc = jsonDecode(source);
    } on FormatException {
      return (null, const [ProfileIssue('json', 'invalid JSON')]);
    }
    if (doc is! Map<String, Object?>) {
      return (
        null,
        const [ProfileIssue('', 'a profile must be a JSON object')],
      );
    }
    return (doc, const []);
  }

  /// Decodes and validates a YAML definition in one step.
  static ProfileValidation parseYaml(
    String source, {
    ProfileSource profileSource = ProfileSource.user,
    Set<String> takenIds = const {},
    ProfileValidator validator = const ProfileValidator(),
  }) {
    final (map, issues) = decodeYaml(source);
    if (map == null) return ProfileValidation(null, issues);
    return validator.validate(map, source: profileSource, takenIds: takenIds);
  }

  static Object? _plain(Object? node, String path, IssueSink sink) {
    if (node is YamlMap) {
      final out = <String, Object?>{};
      for (final entry in node.nodes.entries) {
        final key = (entry.key as YamlNode).value;
        if (key is! String) {
          sink.add(path, 'map keys must be text');
          continue;
        }
        out[key] = _plain(entry.value.value, joinPath(path, key), sink);
      }
      return out;
    }
    if (node is YamlList) {
      return [
        for (var i = 0; i < node.length; i++)
          _plain(node[i], '$path[$i]', sink),
      ];
    }
    return node;
  }
}
