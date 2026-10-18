import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/domain/profile_codec.dart';
import 'package:vaultvoice/features/profiles/domain/profile_issue.dart';

/// Asset paths of the built-in profiles (`app/assets/profiles/*.yaml`).
/// A test asserts this list equals the folder contents.
const List<String> kBuiltinProfileAssets = [
  'assets/profiles/meeting.yaml',
  'assets/profiles/warranty.yaml',
  'assets/profiles/engineering.yaml',
  'assets/profiles/lecture.yaml',
  'assets/profiles/sales_call.yaml',
  'assets/profiles/interview.yaml',
];

/// Thrown when a shipped built-in profile is invalid — a build bug, caught
/// by the asset tests before release.
class BuiltinProfileException implements Exception {
  const BuiltinProfileException(this.issues);

  final List<ProfileIssue> issues;

  @override
  String toString() =>
      'BuiltinProfileException\n${issues.map((i) => '  - $i').join('\n')}';
}

/// The read-only built-in profiles, parsed from assets on every launch and
/// keyed by `(id, version)` — never stored as editable rows (profile spec →
/// "Built-in profile updates").
class BuiltinProfiles {
  BuiltinProfiles._(this._byId);

  /// Parses each asset ([sources]: asset path → YAML text).
  ///
  /// Throws [BuiltinProfileException] if any asset is invalid or two assets
  /// share an id.
  factory BuiltinProfiles.parse(Map<String, String> sources) {
    final byId = <String, Profile>{};
    final issues = <ProfileIssue>[];
    for (final entry in sources.entries) {
      final result = ProfileCodec.parseYaml(
        entry.value,
        profileSource: ProfileSource.builtin,
      );
      if (result.profile case final profile?) {
        if (byId.containsKey(profile.id)) {
          issues.add(
            ProfileIssue(entry.key, 'duplicate built-in id "${profile.id}"'),
          );
        }
        byId[profile.id] = profile;
      } else {
        issues.addAll(
          result.issues.map(
            (i) => ProfileIssue(joinPath(entry.key, i.path), i.message),
          ),
        );
      }
    }
    if (issues.isNotEmpty) throw BuiltinProfileException(issues);
    return BuiltinProfiles._(Map.unmodifiable(byId));
  }

  final Map<String, Profile> _byId;

  /// Built-ins in asset order.
  List<Profile> get all => List.unmodifiable(_byId.values);

  Set<String> get ids => _byId.keys.toSet();

  Profile? operator [](String id) => _byId[id];

  /// The profile exactly matching [ref], or null when that version is no
  /// longer shipped (re-extract then uses the current version).
  Profile? lookup(ProfileRef ref) {
    final p = _byId[ref.id];
    return p != null && p.version == ref.version ? p : null;
  }
}
