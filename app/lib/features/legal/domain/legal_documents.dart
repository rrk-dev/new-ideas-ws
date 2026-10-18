/// Bundled legal documents and their acceptance record (LEG-01).
library;

/// Version of the Terms of Use and the Privacy Policy. Both assets carry the
/// same `Version:` line (a test checks it). Change it, and the two lines, when
/// a document changes in a way users must accept again.
const kLegalVersion = '2026-10-18';

/// Release flag. While false the draft banner of each document is shown.
/// A human sets it to true only after a qualified lawyer approved the text
/// (docs/legal/README.md, docs/store/pre-submission-checklist.md).
const kLegalReleaseApproved = false;

const kTermsAsset = 'assets/legal/terms_of_use.md';
const kPrivacyAsset = 'assets/legal/privacy_policy.md';

/// Marker that starts the two-line draft banner at the top of a document.
const kDraftBannerMarker = 'LEGAL-DRAFT-BANNER';

/// `settings` keys of the acceptance record. Not user-editable settings.
abstract final class LegalKeys {
  /// String: the [kLegalVersion] the user accepted.
  static const acceptedVersion = 'legal.accepted_version';

  /// int (UTC epoch ms): when the user accepted.
  static const acceptedAt = 'legal.accepted_at';

  /// bool: the user confirmed being at least 21 years old.
  static const ageConfirmed = 'legal.age_confirmed';
}

final _banner = RegExp(
  '^\\[//\\]: # \\($kDraftBannerMarker[^\\n]*\\n> [^\\n]*\\n+',
  multiLine: true,
);

/// The text to show: the draft banner is removed once [released].
String legalDisplayText(String raw, {bool released = kLegalReleaseApproved}) =>
    released ? raw.replaceFirst(_banner, '') : raw;

/// The `Version:` line of a document, or null if it has none.
String? legalDocumentVersion(String raw) =>
    RegExp(r'^Version: (\S+)\s*$', multiLine: true).firstMatch(raw)?.group(1);
