import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/features/review/domain/review_policy.dart';

/// Review-before-export (APP-05): decides whether `RenderStep` must park
/// the job in `waiting(review)` instead of rendering and exporting.
///
/// Runs in the pipeline isolate and only reads the database: the per-profile
/// setting (`review.mode.<profile>`), else the profile's own
/// `review_before_export` (user/enterprise profiles from `profiles`; the
/// built-in profiles ship with `false`), and the approval
/// (`review.approved.<extraction>` = hash of the approved content).
class ReviewGate {
  const ReviewGate(this._db);

  final VaultVoiceDatabase _db;

  /// Whether [extraction] needs the user's review before it is rendered.
  Future<bool> mustWait(ExtractionRow extraction) async {
    final settings = _db.settingsRepository;
    final mode = (await settings.get(ReviewKeys.mode(extraction.profileId)))
        .valueOrNull;
    final stored = (await _db.profilesRepository.getProfile(
      extraction.profileId,
    )).valueOrNull;
    final required = reviewRequired(
      setting: mode,
      profileDefault: stored?.definition['review_before_export'] == true,
    );
    if (!required) return false;
    final approved = (await settings.get(ReviewKeys.approved(extraction.id)))
        .valueOrNull;
    return approved != extractionHash(extraction.json);
  }
}
