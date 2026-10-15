/// `settings` keys of the automatic profile classification (PRF-06).
abstract final class ClassificationKeys {
  /// JSON map `{profile, confidence, method, asked}` of the last
  /// classification of a recording: what the app picked (or suggested when
  /// the user was asked) and why. Contains no transcript text.
  static String result(String recordingId) => 'classification.$recordingId';
}
