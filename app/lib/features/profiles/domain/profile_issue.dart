/// One problem found while validating a profile.
///
/// [path] locates the offending key (`schema.action_items.owner`,
/// `examples[0].output.title`, `template:3:14`); [message] says what is wrong
/// and how to fix it. Messages name keys and limits only — they never echo
/// field *values*, so they are safe to log at INFO (vv-privacy-security).
class ProfileIssue {
  const ProfileIssue(this.path, this.message);

  final String path;
  final String message;

  @override
  String toString() => path.isEmpty ? message : '$path: $message';
}

/// Thrown by `Profile.fromJson` when a definition is not a valid profile.
///
/// Prefer `ProfileValidator.validate`, which returns the issues instead.
class ProfileFormatException implements Exception {
  const ProfileFormatException(this.issues);

  final List<ProfileIssue> issues;

  @override
  String toString() =>
      'ProfileFormatException(${issues.length} issues)\n'
      '${issues.map((i) => '  - $i').join('\n')}';
}

/// Collects issues while walking a definition.
class IssueSink {
  final List<ProfileIssue> issues = [];

  bool get isEmpty => issues.isEmpty;

  void add(String path, String message) =>
      issues.add(ProfileIssue(path, message));
}

/// Joins a parent path and a child key (`schema` + `title` → `schema.title`).
String joinPath(String parent, String child) =>
    parent.isEmpty ? child : '$parent.$child';
